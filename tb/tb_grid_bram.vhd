library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_grid_bram is end entity;

architecture sim of tb_grid_bram is
    signal clk      : std_logic := '0';
    signal wr_addr  : unsigned(12 downto 0) := (others => '0');
    signal wr_data  : std_logic := '0';
    signal wr_en    : std_logic := '0';
    signal wr_buf   : std_logic := '0';
    signal rd_addr  : unsigned(12 downto 0) := (others => '0');
    signal rd_data  : std_logic;
    signal rd_buf   : std_logic := '0';
begin
    clk <= not clk after 20 ns;

    uut: entity work.grid_bram
        port map (
            clk       => clk,
            wr_addr   => wr_addr,
            wr_data   => wr_data,
            wr_en     => wr_en,
            wr_buffer => wr_buf,
            rd_addr   => rd_addr,
            rd_data   => rd_data,
            rd_buffer => rd_buf
        );

    stim: process
    begin
        wait for 50 ns;

        -- Skriv en levande cell pa adress 1234 i buffer 0
        wait until rising_edge(clk);
        wr_addr <= to_unsigned(1234, 13);
        wr_data <= '1';
        wr_en   <= '1';
        wr_buf  <= '0';
        wait until rising_edge(clk);
        wr_en   <= '0';

        -- Las samma adress fran buffer 0
        wait until rising_edge(clk);
        rd_addr <= to_unsigned(1234, 13);
        rd_buf  <= '0';
        wait until rising_edge(clk);  -- read latency 1 cycle
        wait until rising_edge(clk);
        assert rd_data = '1'
            report "FAIL: forvantat 1 vid laddning fran buffer 0 adress 1234"
            severity failure;

        -- Buffer 1 ska inte ha samma data (oinitialiserat eller 0)
        rd_buf <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert rd_data = '0'
            report "FAIL: buffer 1 ska vara 0 vid adress 1234"
            severity failure;

        report "PASS: grid_bram ping-pong fungerar";
        finish;
    end process;
end architecture sim;
