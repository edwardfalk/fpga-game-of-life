library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

-- Testbench for gol_engine using the real grid_bram (same as top.vhd).
-- Tests both blinker rotation and glider translation to catch latency bugs
-- that accidentally pass with a simple 1-register BRAM model.
entity tb_gol_engine_glider is end entity;

architecture sim of tb_gol_engine_glider is
    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal start     : std_logic := '0';
    signal toroidal  : std_logic := '1';

    signal engine_rd_addr  : unsigned(12 downto 0);
    signal engine_rd_data  : std_logic;
    signal engine_wr_addr  : unsigned(12 downto 0);
    signal engine_wr_data  : std_logic;
    signal engine_wr_en    : std_logic;
    signal engine_wr_buf   : std_logic;
    signal engine_done     : std_logic;
    signal engine_busy     : std_logic;

    signal cur_buf : std_logic := '0';

    signal grid_rd_addr : unsigned(12 downto 0);
    signal grid_rd_data : std_logic;

    -- Loader (write) port to pre-load patterns
    signal load_wr_addr : unsigned(12 downto 0) := (others => '0');
    signal load_wr_data : std_logic := '0';
    signal load_wr_en   : std_logic := '0';
    signal load_wr_buf  : std_logic := '0';

    -- Muxed write port (loader has priority)
    signal grid_wr_addr : unsigned(12 downto 0);
    signal grid_wr_data : std_logic;
    signal grid_wr_en   : std_logic;
    signal grid_wr_buf  : std_logic;

    -- Shadow RAM to read back results without extra BRAM port
    type mem_t is array (0 to 4799) of std_logic;
    signal shadow0 : mem_t := (others => '0');
    signal shadow1 : mem_t := (others => '0');


begin
    clk <= not clk after 20 ns;

    -- Read mux: engine owns bus when busy
    grid_rd_addr <= engine_rd_addr when engine_busy = '1' else (others => '0');
    engine_rd_data <= grid_rd_data;

    -- Write mux: loader has priority (during loading, engine is idle)
    grid_wr_addr <= load_wr_addr when load_wr_en = '1' else engine_wr_addr;
    grid_wr_data <= load_wr_data when load_wr_en = '1' else engine_wr_data;
    grid_wr_en   <= load_wr_en   when load_wr_en = '1' else engine_wr_en;
    grid_wr_buf  <= load_wr_buf  when load_wr_en = '1' else engine_wr_buf;

    -- Real grid_bram (same as in top.vhd)
    bram: entity work.grid_bram
        port map (
            clk       => clk,
            wr_addr   => grid_wr_addr,
            wr_data   => grid_wr_data,
            wr_en     => grid_wr_en,
            wr_buffer => grid_wr_buf,
            rd_addr   => grid_rd_addr,
            rd_data   => grid_rd_data,
            rd_buffer => cur_buf
        );

    -- gol_engine
    uut: entity work.gol_engine
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => start,
            toroidal    => toroidal,
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

    -- Toggle cur_buf on done (same as top.vhd)
    buf_toggle: process(clk)
    begin
        if rising_edge(clk) then
            if engine_done = '1' then
                cur_buf <= not cur_buf;
            end if;
        end if;
    end process;

    -- Shadow RAM tracks all writes for readback
    shadow: process(clk)
    begin
        if rising_edge(clk) then
            if grid_wr_en = '1' then
                if grid_wr_buf = '0' then
                    shadow0(to_integer(grid_wr_addr)) <= grid_wr_data;
                else
                    shadow1(to_integer(grid_wr_addr)) <= grid_wr_data;
                end if;
            end if;
        end if;
    end process;

    stim: process
        -- Run one generation and wait for done
        procedure run_gen is
        begin
            wait until rising_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until engine_done = '1';
        end procedure;

        -- Read result cell from shadow (destination buffer of last run)
        impure function result_cell(addr : integer) return std_logic is
        begin
            -- After run_gen, cur_buf has been toggled to point at the new generation.
            -- The result was written to NOT cur_buf BEFORE the toggle.
            -- After toggle, cur_buf = destination buffer = result location.
            if cur_buf = '1' then
                return shadow1(addr);
            else
                return shadow0(addr);
            end if;
        end function;

    begin
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;

        -- ----------------------------------------------------------------
        -- TEST 1: Blinker (horizontal) rotates to vertical after 1 gen
        -- ----------------------------------------------------------------
        -- Clear both buffers (shadow is already 0; write 0s to BRAM buf 0)
        -- Actually shadow and BRAM start all-zero from GHDL initialization.

        -- Load blinker into buffer 0: (39,30),(40,30),(41,30)
        load_wr_buf <= '0';
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(30*80 + 39, 13); load_wr_data <= '1'; load_wr_en <= '1';
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(30*80 + 40, 13);
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(30*80 + 41, 13);
        wait until rising_edge(clk);
        load_wr_en <= '0';
        wait for 100 ns;

        -- Run generation 1: reads buf 0, writes buf 1
        run_gen;
        wait for 100 ns;

        -- After gen 1: vertical blinker at (40,29),(40,30),(40,31) in buf 1
        assert result_cell(29*80 + 40) = '1'
            report "FAIL blinker: cell (40,29) should be alive" severity failure;
        assert result_cell(30*80 + 40) = '1'
            report "FAIL blinker: cell (40,30) should be alive" severity failure;
        assert result_cell(31*80 + 40) = '1'
            report "FAIL blinker: cell (40,31) should be alive" severity failure;
        assert result_cell(30*80 + 41) = '0'
            report "FAIL blinker: cell (41,30) should be dead" severity failure;
        assert result_cell(30*80 + 42) = '0'
            report "FAIL blinker: cell (42,30) should be dead" severity failure;
        report "PASS: gol_engine (real BRAM) roterar blinker korrekt";

        -- ----------------------------------------------------------------
        -- TEST 2: Glider translates correctly over 4 generations
        -- Glider layout at origin (10,10):
        --   col:  9 10 11
        -- row 10:  .  #  .
        -- row 11:  .  .  #
        -- row 12:  #  #  #
        -- After 4 gens, glider at (11,11),(12,12),(10,13),(11,13),(12,13)
        -- ----------------------------------------------------------------

        -- Reset buffers: write 0 over old blinker result and source
        -- (Easier: reload by explicitly zeroing old cells)
        -- Clear blinker cells in both buffers
        load_wr_buf <= '0';
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(30*80 + 39, 13); load_wr_data <= '0'; load_wr_en <= '1';
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(30*80 + 40, 13);
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(30*80 + 41, 13);
        wait until rising_edge(clk);
        load_wr_en <= '0';

        load_wr_buf <= '1';
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(29*80 + 40, 13); load_wr_data <= '0'; load_wr_en <= '1';
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(30*80 + 40, 13);
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(31*80 + 40, 13);
        wait until rising_edge(clk);
        load_wr_en <= '0';

        -- Reset cur_buf to 0 (it toggled to 1 after gen1). We need to load into buf 0 again.
        -- cur_buf is currently 1 (after gen1 toggle). Engine will read from buf 1 (empty).
        -- We want engine to read our new glider from buf 0.
        -- Force cur_buf back to 0 by writing to shadow and loading into correct buf.
        -- Actually, just load glider into CURRENT cur_buf (which is 1 now).
        -- After loading: start engine. It reads from cur_buf=1, writes to 0. Toggle → cur_buf=0.

        load_wr_buf <= cur_buf;  -- load into current source buffer (buf 1)
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(10*80 + 10, 13); load_wr_data <= '1'; load_wr_en <= '1';
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(11*80 + 11, 13);
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(12*80 + 9, 13);
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(12*80 + 10, 13);
        wait until rising_edge(clk);
        load_wr_addr <= to_unsigned(12*80 + 11, 13);
        wait until rising_edge(clk);
        load_wr_en <= '0';
        wait for 100 ns;

        -- Run 4 generations
        run_gen;  -- gen 1
        run_gen;  -- gen 2
        run_gen;  -- gen 3
        run_gen;  -- gen 4

        wait for 200 ns;

        -- After 4 gens: glider at (11,11),(12,12),(10,13),(11,13),(12,13)
        -- cur_buf has toggled 4 times from 1 → 0 (even toggles)? Let's not
        -- rely on arithmetic: use result_cell() which reads from cur_buf.
        assert result_cell(11*80 + 11) = '1'
            report "FAIL glider: cell (11,11) should be alive" severity failure;
        assert result_cell(12*80 + 12) = '1'
            report "FAIL glider: cell (12,12) should be alive" severity failure;
        assert result_cell(13*80 + 10) = '1'
            report "FAIL glider: cell (10,13) should be alive" severity failure;
        assert result_cell(13*80 + 11) = '1'
            report "FAIL glider: cell (11,13) should be alive" severity failure;
        assert result_cell(13*80 + 12) = '1'
            report "FAIL glider: cell (12,13) should be alive" severity failure;

        -- Verify glider cells from initial position are now dead
        assert result_cell(10*80 + 10) = '0'
            report "FAIL glider: cell (10,10) should be dead" severity failure;
        assert result_cell(12*80 + 9)  = '0'
            report "FAIL glider: cell (9,12) should be dead" severity failure;

        report "PASS: gol_engine (real BRAM) translates glider correctly over 4 generations";
        finish;
    end process;
end architecture sim;
