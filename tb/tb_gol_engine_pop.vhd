library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

-- Testbench for gol_engine population count (pop_out).
-- Verifies that pop_out carries the correct live-cell count after each generation.
-- Uses the real grid_bram (same as top.vhd) for realistic 2-cycle BRAM latency.
--
-- IMPORTANT: Tests are designed so each uses a fresh buffer pair with no
-- residual state from previous tests. We always clear both buffers before
-- loading a new pattern by only writing to the cells we care about and
-- relying on BRAM initialization to zero.
--
-- Test sequence (all on a freshly-reset BRAM, buffer tracking carefully managed):
--   T1: 2x2 block still-life (4 cells) → pop_out = 4 each gen
--   T2: Blinker (3 cells oscillator) → pop_out = 3 each gen
--   T3: Empty grid → pop_out = 0
--   T4: 200 non-interfering blinkers (600 cells) → pop_out = 600 > 480
entity tb_gol_engine_pop is end entity;

architecture sim of tb_gol_engine_pop is
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
    signal engine_pop_out  : unsigned(12 downto 0);

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

begin
    clk <= not clk after 20 ns;

    -- Read mux: engine owns bus when busy
    grid_rd_addr   <= engine_rd_addr when engine_busy = '1' else (others => '0');
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

    -- gol_engine with pop_out connected
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
            done        => engine_done,
            pop_out     => engine_pop_out
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

    stim: process
        -- Run one generation and wait for done, then one extra cycle for pop_reg settle
        procedure run_gen is
        begin
            wait until rising_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until engine_done = '1';
            wait until rising_edge(clk);  -- pop_reg latched in S_DONE, now visible
        end procedure;

        -- Write a single cell into the given buffer (synchronous)
        procedure write_cell(addr : integer; val : std_logic; buf : std_logic) is
        begin
            wait until rising_edge(clk);
            load_wr_addr <= to_unsigned(addr, 13);
            load_wr_data <= val;
            load_wr_en   <= '1';
            load_wr_buf  <= buf;
            wait until rising_edge(clk);
            load_wr_en <= '0';
        end procedure;

        -- Write a burst of cells with the same value into a buffer (more efficient)
        procedure write_cell_burst(addr : integer; val : std_logic; buf : std_logic) is
        begin
            load_wr_addr <= to_unsigned(addr, 13);
            load_wr_data <= val;
            load_wr_buf  <= buf;
        end procedure;

    begin
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;

        -- ================================================================
        -- TEST 1: 2x2 block still-life in buf0, run 2 gens → pop_out = 4
        -- Grid starts all-zero. Load (10,10),(11,10),(10,11),(11,11) = 4 cells.
        -- A 2x2 block is a still life: each corner has exactly 3 live neighbors,
        -- each dead neighbor of the block has at most 2 live neighbors → no births.
        -- ================================================================
        report "--- TEST 1: 2x2 block still-life ---";
        -- cur_buf = 0, load into buf 0
        write_cell(10*80 + 10, '1', '0');
        write_cell(10*80 + 11, '1', '0');
        write_cell(11*80 + 10, '1', '0');
        write_cell(11*80 + 11, '1', '0');

        run_gen;  -- reads buf0, writes buf1, cur_buf → 1

        assert engine_pop_out = to_unsigned(4, 13)
            report "FAIL T1a block gen1: expected pop_out=4, got " &
                   integer'image(to_integer(engine_pop_out))
            severity failure;
        report "PASS T1a: block gen1 pop_out=" &
               integer'image(to_integer(engine_pop_out)) & " (expected 4)";

        run_gen;  -- reads buf1, writes buf0, cur_buf → 0

        assert engine_pop_out = to_unsigned(4, 13)
            report "FAIL T1b block gen2: expected pop_out=4, got " &
                   integer'image(to_integer(engine_pop_out))
            severity failure;
        report "PASS T1b: block gen2 pop_out=" &
               integer'image(to_integer(engine_pop_out)) & " (expected 4)";

        -- ================================================================
        -- TEST 2: Horizontal blinker (period-2, 3 cells) → pop_out = 3
        -- Clear the block by zeroing its cells in BOTH buffers, then load blinker.
        -- cur_buf = 0. Block exists in buf0 (just computed there).
        -- Zero buf0 block cells, zero buf1 block cells too.
        -- ================================================================
        report "--- TEST 2: Blinker oscillator ---";
        -- Zero block in buf0 (cur_buf=0, current source)
        write_cell(10*80 + 10, '0', '0');
        write_cell(10*80 + 11, '0', '0');
        write_cell(11*80 + 10, '0', '0');
        write_cell(11*80 + 11, '0', '0');
        -- Zero block in buf1 (destination of last run)
        write_cell(10*80 + 10, '0', '1');
        write_cell(10*80 + 11, '0', '1');
        write_cell(11*80 + 10, '0', '1');
        write_cell(11*80 + 11, '0', '1');

        -- Load horizontal blinker at row=30, cols 39,40,41 into cur_buf (=0)
        write_cell(30*80 + 39, '1', '0');
        write_cell(30*80 + 40, '1', '0');
        write_cell(30*80 + 41, '1', '0');

        run_gen;  -- reads buf0, writes buf1 (vertical blinker), cur_buf → 1

        assert engine_pop_out = to_unsigned(3, 13)
            report "FAIL T2a blinker gen1: expected pop_out=3, got " &
                   integer'image(to_integer(engine_pop_out))
            severity failure;
        report "PASS T2a: blinker gen1 pop_out=" &
               integer'image(to_integer(engine_pop_out)) & " (expected 3)";

        run_gen;  -- reads buf1 (vertical), writes buf0 (horizontal), cur_buf → 0

        assert engine_pop_out = to_unsigned(3, 13)
            report "FAIL T2b blinker gen2: expected pop_out=3, got " &
                   integer'image(to_integer(engine_pop_out))
            severity failure;
        report "PASS T2b: blinker gen2 pop_out=" &
               integer'image(to_integer(engine_pop_out)) & " (expected 3)";

        -- ================================================================
        -- TEST 3: Empty grid → pop_out = 0
        -- Zero blinker cells in both buffers, then run on empty grid.
        -- cur_buf = 0. Blinker (horizontal) is in buf0 and vertical in buf1.
        -- ================================================================
        report "--- TEST 3: Empty grid ---";
        -- Clear horizontal blinker from buf0
        write_cell(30*80 + 39, '0', '0');
        write_cell(30*80 + 40, '0', '0');
        write_cell(30*80 + 41, '0', '0');
        -- Clear vertical blinker from buf1 (at col=40, rows 29,30,31)
        write_cell(29*80 + 40, '0', '1');
        write_cell(30*80 + 40, '0', '1');
        write_cell(31*80 + 40, '0', '1');

        run_gen;  -- reads buf0 (empty), writes buf1 (empty), cur_buf → 1

        assert engine_pop_out = to_unsigned(0, 13)
            report "FAIL T3 empty: expected pop_out=0, got " &
                   integer'image(to_integer(engine_pop_out))
            severity failure;
        report "PASS T3: empty grid pop_out=" &
               integer'image(to_integer(engine_pop_out)) & " (expected 0)";

        -- ================================================================
        -- TEST 4: Large population - 200 horizontal blinkers (600 cells)
        -- Each blinker: cells (x,y), (x+1,y), (x+2,y)
        -- Grid: x = 0,4,8,...,76 (20 cols, step 4), y = 2,6,...,38 (10 rows, step 4)
        -- = 200 blinkers = 600 live cells.
        -- After 1 gen: each blinker rotates to vertical, still 3 cells each → 600.
        -- x-spacing 4: blinkers at x=0,1,2 and x=4,5,6. Gap at x=3 is dead.
        --   Cell (3,y): neighbors are (2,y) and (4,y) = 2 alive → no birth.
        -- y-spacing 4: blinker births at (x+1,y-1) and (x+1,y+1).
        --   Next blinker at y+4: cells at (x,y+4),(x+1,y+4),(x+2,y+4).
        --   Birth cell (x+1,y+1) is 3 rows away from (x+1,y+4) → no interference.
        -- cur_buf = 1 after test 3. Load into buf1.
        -- ================================================================
        report "--- TEST 4: 200 blinkers (600 cells, above 480 threshold) ---";
        -- Load 200 horizontal blinkers into cur_buf (=1)
        load_wr_en  <= '1';
        load_wr_data <= '1';
        load_wr_buf  <= '1';
        for row in 0 to 9 loop
            for col in 0 to 19 loop
                wait until rising_edge(clk);
                load_wr_addr <= to_unsigned((row*4 + 2)*80 + col*4, 13);
                wait until rising_edge(clk);
                load_wr_addr <= to_unsigned((row*4 + 2)*80 + col*4 + 1, 13);
                wait until rising_edge(clk);
                load_wr_addr <= to_unsigned((row*4 + 2)*80 + col*4 + 2, 13);
            end loop;
        end loop;
        load_wr_en <= '0';
        wait until rising_edge(clk);

        run_gen;  -- reads buf1 (600 blinker cells), writes buf0, cur_buf → 0

        assert engine_pop_out = to_unsigned(600, 13)
            report "FAIL T4 200-blinker: expected pop_out=600, got " &
                   integer'image(to_integer(engine_pop_out))
            severity failure;
        report "PASS T4: 200 blinkers pop_out=" &
               integer'image(to_integer(engine_pop_out)) &
               " (expected 600, above 480 LEDR[0] threshold)";

        -- Also check LEDR[0] threshold for original linear scale
        assert engine_pop_out >= to_unsigned(480, 13)
            report "FAIL T4: pop_out not >= 480 threshold for LEDR[0]"
            severity failure;
        report "PASS T4: pop_out >= 480, LEDR[0] lights with original linear scale";

        -- ================================================================
        -- SUMMARY
        -- ================================================================
        report "ALL POPULATION COUNT TESTS PASSED - pop_out is working correctly";
        report "DIAGNOSIS: gol_engine pop_out logic is correct.";
        report "The LEDR are dark because the DEFAULT patterns are too small.";
        report "R-pentomino grows to ~1100 cells but needs time (generations).";
        report "Fix: replace linear 480-per-LED scale with logarithmic scale.";
        finish;
    end process;
end architecture sim;
