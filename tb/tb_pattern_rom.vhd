library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_pattern_rom is end entity;

architecture sim of tb_pattern_rom is
    signal clk         : std_logic := '0';
    signal pattern_sel : unsigned(2 downto 0) := (others => '0');
    signal x           : unsigned(5 downto 0) := (others => '0');
    signal y           : unsigned(3 downto 0) := (others => '0');
    signal bit_out     : std_logic;
begin
    clk <= not clk after 20 ns;

    uut: entity work.pattern_rom
        port map (
            clk         => clk,
            pattern_sel => pattern_sel,
            x           => x,
            y           => y,
            bit_out     => bit_out
        );

    stim: process
    begin
        wait for 50 ns;

        -- Glider (pattern 0): ska ha celler vid:
        --   (1,0), (2,1), (0,2), (1,2), (2,2)
        pattern_sel <= "000";
        x <= to_unsigned(1, 6); y <= to_unsigned(0, 4);
        wait for 50 ns;
        assert bit_out = '1'
            report "FAIL: glider ska ha cell vid (1,0)" severity failure;

        x <= to_unsigned(0, 6); y <= to_unsigned(0, 4);
        wait for 50 ns;
        assert bit_out = '0'
            report "FAIL: glider ska inte ha cell vid (0,0)" severity failure;

        -- Blinker (pattern 1): 3 celler i rad
        pattern_sel <= "001";
        x <= to_unsigned(0, 6); y <= to_unsigned(0, 4);
        wait for 50 ns;
        assert bit_out = '1'
            report "FAIL: blinker ska ha cell vid (0,0)" severity failure;
        x <= to_unsigned(1, 6); y <= to_unsigned(0, 4);
        wait for 50 ns;
        assert bit_out = '1'
            report "FAIL: blinker ska ha cell vid (1,0)" severity failure;
        x <= to_unsigned(2, 6); y <= to_unsigned(0, 4);
        wait for 50 ns;
        assert bit_out = '1'
            report "FAIL: blinker ska ha cell vid (2,0)" severity failure;
        x <= to_unsigned(0, 6); y <= to_unsigned(1, 4);
        wait for 50 ns;
        assert bit_out = '0'
            report "FAIL: blinker ska inte ha cell vid (0,1)" severity failure;

        report "PASS: pattern_rom levererar korrekta bits";
        finish;
    end process;
end architecture sim;
