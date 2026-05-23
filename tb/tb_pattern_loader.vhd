library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_pattern_loader is end entity;

architecture sim of tb_pattern_loader is
    signal clk         : std_logic := '0';
    signal reset_n     : std_logic := '0';
    signal start       : std_logic := '0';
    signal pattern_sel : unsigned(2 downto 0) := "001";  -- blinker
    signal dst_buffer  : std_logic := '0';
    signal busy        : std_logic;
    signal done        : std_logic;
    signal wr_addr     : unsigned(12 downto 0);
    signal wr_data     : std_logic;
    signal wr_en       : std_logic;
    signal wr_buffer_o : std_logic;
begin
    clk <= not clk after 20 ns;

    uut: entity work.pattern_loader
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => start,
            pattern_sel => pattern_sel,
            dst_buffer  => dst_buffer,
            wr_addr     => wr_addr,
            wr_data     => wr_data,
            wr_en       => wr_en,
            wr_buffer_o => wr_buffer_o,
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

        -- Wait for done (within ~200 ms simtime)
        for i in 1 to 5000000 loop
            wait until rising_edge(clk);
            if done = '1' then
                report "PASS: pattern_loader klar";
                finish;
            end if;
        end loop;
        report "FAIL: pattern_loader timeout" severity failure;
        finish;
    end process;
end architecture sim;
