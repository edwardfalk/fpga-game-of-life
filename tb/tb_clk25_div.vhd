library ieee;
use ieee.std_logic_1164.all;
use std.env.finish;

entity tb_clk25_div is end entity;

architecture sim of tb_clk25_div is
    signal clk50    : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal clk25    : std_logic;
    signal edge_cnt : integer := 0;
begin
    clk50 <= not clk50 after 10 ns;  -- 50 MHz

    uut: entity work.clk25_div
        port map (
            clk50_in  => clk50,
            reset_n   => reset_n,
            clk25_out => clk25
        );

    -- Rakna stigande flanker pa clk25 over en kand tid
    edge_counter: process(clk25)
    begin
        if rising_edge(clk25) then
            edge_cnt <= edge_cnt + 1;
        end if;
    end process;

    stim: process
    begin
        wait for 50 ns;
        reset_n <= '1';

        -- Vanta 10 us = 250 cykler av 25 MHz (forvantat)
        wait for 10 us;

        assert edge_cnt >= 249 and edge_cnt <= 251
            report "FAIL: forvantat ~250 stigande flanker pa clk25 over 10us, fick "
                & integer'image(edge_cnt)
            severity failure;

        report "PASS: clk25_div delar med 2";
        finish;
    end process;
end architecture sim;
