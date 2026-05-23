library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_gol_engine is end entity;

architecture sim of tb_gol_engine is
    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal start    : std_logic := '0';
    signal toroidal : std_logic := '1';
    signal src_buf  : std_logic := '0';

    signal rd_addr  : unsigned(12 downto 0);
    signal rd_data  : std_logic := '0';
    signal wr_addr  : unsigned(12 downto 0);
    signal wr_data  : std_logic;
    signal wr_en    : std_logic;
    signal wr_buf   : std_logic;
    signal done     : std_logic;
    signal busy     : std_logic;

    type mem_t is array (0 to 4799) of std_logic;

    -- Blinker-funktion: returnerar mem0 med 3 horisontella celler satta
    -- vid (39,30),(40,30),(41,30) sa att vertikal rotation hamnar vid (40,29),(40,30),(40,31)
    function init_blinker return mem_t is
        variable m : mem_t := (others => '0');
    begin
        m(30*80 + 39) := '1';
        m(30*80 + 40) := '1';
        m(30*80 + 41) := '1';
        return m;
    end function;

    signal mem0 : mem_t := init_blinker;
    signal mem1 : mem_t := (others => '0');
begin
    clk <= not clk after 20 ns;

    -- BRAM-modellen med 1 cykels lasenhet
    rd_proc: process(clk)
    begin
        if rising_edge(clk) then
            if src_buf = '0' then
                rd_data <= mem0(to_integer(rd_addr));
            else
                rd_data <= mem1(to_integer(rd_addr));
            end if;
        end if;
    end process;

    wr_proc: process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                if wr_buf = '0' then
                    mem0(to_integer(wr_addr)) <= wr_data;
                else
                    mem1(to_integer(wr_addr)) <= wr_data;
                end if;
            end if;
        end if;
    end process;

    uut: entity work.gol_engine
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => start,
            toroidal    => toroidal,
            src_buffer  => src_buf,
            dst_buffer  => '1',
            rd_addr     => rd_addr,
            rd_data     => rd_data,
            wr_addr     => wr_addr,
            wr_data     => wr_data,
            wr_en       => wr_en,
            wr_buffer_o => wr_buf,
            busy        => busy,
            done        => done
        );

    stim: process
    begin
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;

        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- Vanta pa done (max ~50 ms simtid)
        for i in 1 to 5000000 loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
            if i = 4999999 then
                report "FAIL: gol_engine timeout" severity failure;
            end if;
        end loop;

        -- Efter en generation ska blinker vara orienterad om: vertikal
        -- (40,29), (40,30), (40,31) ska vara levande
        -- (41,30), (42,30) ska vara doda
        wait for 100 ns;
        assert mem1(29*80 + 40) = '1' report "FAIL: cell (40,29) ska vara levande" severity failure;
        assert mem1(30*80 + 40) = '1' report "FAIL: cell (40,30) ska vara levande" severity failure;
        assert mem1(31*80 + 40) = '1' report "FAIL: cell (40,31) ska vara levande" severity failure;
        assert mem1(30*80 + 41) = '0' report "FAIL: cell (41,30) ska vara dod" severity failure;
        assert mem1(30*80 + 42) = '0' report "FAIL: cell (42,30) ska vara dod" severity failure;

        report "PASS: gol_engine roterar blinker korrekt";
        finish;
    end process;
end architecture sim;
