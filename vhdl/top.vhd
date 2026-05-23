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

    signal vga_cell_addr  : unsigned(12 downto 0);
    signal vga_cell_alive : std_logic;
    signal vsync_pulse    : std_logic;

    signal loader_start : std_logic := '0';
    signal loader_busy  : std_logic;
    signal loader_done  : std_logic;
    signal loader_wr_addr : unsigned(12 downto 0);
    signal loader_wr_data : std_logic;
    signal loader_wr_en   : std_logic;
    signal loader_wr_buf  : std_logic;

    -- KEY[3]-trigger: detektera nedtryckning (active-low key, sa fallande flank)
    signal key3_prev : std_logic := '1';
begin
    clk_div: entity work.clk25_div
        port map (
            clk50_in  => clk50,
            reset_n   => '1',
            clk25_out => clk25
        );

    -- Load-trigger: nedtryckning av KEY[3]
    trigger: process(clk25)
    begin
        if rising_edge(clk25) then
            loader_start <= '0';
            if key3_prev = '1' and key(3) = '0' then
                loader_start <= '1';
            end if;
            key3_prev <= key(3);
        end if;
    end process;

    loader: entity work.pattern_loader
        port map (
            clk         => clk25,
            reset_n     => '1',
            start       => loader_start,
            pattern_sel => unsigned(sw(2 downto 0)),
            dst_buffer  => '0',
            wr_addr     => loader_wr_addr,
            wr_data     => loader_wr_data,
            wr_en       => loader_wr_en,
            wr_buffer_o => loader_wr_buf,
            busy        => loader_busy,
            done        => loader_done
        );

    grid: entity work.grid_bram
        port map (
            clk       => clk25,
            wr_addr   => loader_wr_addr,
            wr_data   => loader_wr_data,
            wr_en     => loader_wr_en,
            wr_buffer => loader_wr_buf,
            rd_addr   => vga_cell_addr,
            rd_data   => vga_cell_alive,
            rd_buffer => '0'
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

    ledr <= "00000000" & loader_busy & loader_done;
end architecture rtl;
