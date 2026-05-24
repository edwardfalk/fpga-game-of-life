library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        clk50  : in  std_logic;
        key    : in  std_logic_vector(3 downto 0);
        sw     : in  std_logic_vector(9 downto 0);
        ledr   : out std_logic_vector(9 downto 0);
        vga_r  : out std_logic_vector(3 downto 0);
        vga_g  : out std_logic_vector(3 downto 0);
        vga_b  : out std_logic_vector(3 downto 0);
        vga_hs : out std_logic;
        vga_vs : out std_logic
    );
end entity top;

architecture rtl of top is
    signal clk25       : std_logic;
    signal vsync_pulse : std_logic;

    signal cur_buf : std_logic := '0';

    -- Debounced KEY signals
    signal key1_db, key2_db, key3_db : std_logic;
    signal key1_pulse, key2_pulse, key3_pulse : std_logic;

    -- Control FSM
    signal paused_sig : std_logic;
    signal loader_start, engine_start : std_logic;

    -- Pattern loader
    signal loader_busy   : std_logic;
    signal loader_done   : std_logic;
    signal loader_wr_addr: unsigned(12 downto 0);
    signal loader_wr_data: std_logic;
    signal loader_wr_en  : std_logic;
    signal loader_wr_buf : std_logic;

    -- GoL engine
    signal engine_busy   : std_logic;
    signal engine_done   : std_logic;
    signal engine_rd_addr: unsigned(12 downto 0);
    signal engine_rd_data: std_logic;
    signal engine_wr_addr: unsigned(12 downto 0);
    signal engine_wr_data: std_logic;
    signal engine_wr_en  : std_logic;
    signal engine_wr_buf : std_logic;

    -- VGA
    signal vga_cell_addr  : unsigned(12 downto 0);
    signal vga_cell_alive : std_logic;

    -- Grid muxes
    signal grid_wr_addr : unsigned(12 downto 0);
    signal grid_wr_data : std_logic;
    signal grid_wr_en   : std_logic;
    signal grid_wr_buf  : std_logic;
    signal grid_rd_addr : unsigned(12 downto 0);
    signal grid_rd_data : std_logic;
begin
    clk_div: entity work.clk25_div
        port map (
            clk50_in  => clk50,
            reset_n   => '1',
            clk25_out => clk25
        );

    -- Debouncers
    db_key1: entity work.debounce
        port map (clk => clk25, reset_n => '1', raw_in => key(1),
                  db_out => key1_db, press_pulse => key1_pulse);

    db_key2: entity work.debounce
        port map (clk => clk25, reset_n => '1', raw_in => key(2),
                  db_out => key2_db, press_pulse => key2_pulse);

    db_key3: entity work.debounce
        port map (clk => clk25, reset_n => '1', raw_in => key(3),
                  db_out => key3_db, press_pulse => key3_pulse);

    -- Control FSM
    ctrl: entity work.control_fsm
        port map (
            clk            => clk25,
            reset_n        => '1',
            vsync_pulse    => vsync_pulse,
            pause_pulse    => key2_pulse,
            step_pulse     => key1_pulse,
            load_pulse     => key3_pulse,
            engine_done    => engine_done,
            speed_sel      => unsigned(sw(5 downto 3)),
            paused         => paused_sig,
            trigger_engine => engine_start,
            trigger_load   => loader_start
        );

    loader: entity work.pattern_loader
        port map (
            clk         => clk25,
            reset_n     => '1',
            start       => loader_start,
            pattern_sel => unsigned(sw(2 downto 0)),
            dst_buffer  => cur_buf,
            wr_addr     => loader_wr_addr,
            wr_data     => loader_wr_data,
            wr_en       => loader_wr_en,
            wr_buffer_o => loader_wr_buf,
            busy        => loader_busy,
            done        => loader_done
        );

    engine: entity work.gol_engine
        port map (
            clk         => clk25,
            reset_n     => '1',
            start       => engine_start,
            toroidal    => not sw(9),
            src_buffer  => cur_buf,
            dst_buffer  => not cur_buf,
            rd_addr     => engine_rd_addr,
            rd_data     => engine_rd_data,
            wr_addr     => engine_wr_addr,
            wr_data     => engine_wr_data,
            wr_en       => engine_wr_en,
            wr_buffer_o => engine_wr_buf,
            busy        => engine_busy,
            done        => engine_done
        );

    -- Toggle cur_buf vid engine_done
    buf_toggle: process(clk25)
    begin
        if rising_edge(clk25) then
            if engine_done = '1' then
                cur_buf <= not cur_buf;
            end if;
        end if;
    end process;

    -- Mux skriv-port
    grid_wr_addr <= loader_wr_addr when loader_busy = '1' else engine_wr_addr;
    grid_wr_data <= loader_wr_data when loader_busy = '1' else engine_wr_data;
    grid_wr_en   <= loader_wr_en   when loader_busy = '1' else engine_wr_en;
    grid_wr_buf  <= loader_wr_buf  when loader_busy = '1' else engine_wr_buf;

    -- Mux las-port
    grid_rd_addr   <= engine_rd_addr when engine_busy = '1' else vga_cell_addr;
    vga_cell_alive <= grid_rd_data;
    engine_rd_data <= grid_rd_data;

    grid: entity work.grid_bram
        port map (
            clk       => clk25,
            wr_addr   => grid_wr_addr,
            wr_data   => grid_wr_data,
            wr_en     => grid_wr_en,
            wr_buffer => grid_wr_buf,
            rd_addr   => grid_rd_addr,
            rd_data   => grid_rd_data,
            rd_buffer => cur_buf
        );

    vga: entity work.vga_renderer
        port map (
            clk25       => clk25,
            reset_n     => '1',
            cell_alive  => vga_cell_alive,
            cell_addr   => vga_cell_addr,
            vga_r       => vga_r,
            vga_g       => vga_g,
            vga_b       => vga_b,
            vga_hs      => vga_hs,
            vga_vs      => vga_vs,
            vsync_pulse => vsync_pulse
        );

    ledr <= "0000000" & paused_sig & engine_busy & loader_busy;
end architecture rtl;
