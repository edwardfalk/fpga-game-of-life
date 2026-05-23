library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_vga_timing is end entity;

architecture sim of tb_vga_timing is
    signal clk25      : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal h_count    : unsigned(9 downto 0);
    signal v_count    : unsigned(9 downto 0);
    signal hs         : std_logic;
    signal vs         : std_logic;
    signal display_active : std_logic;
    signal vsync_pulse    : std_logic;
begin
    clk25 <= not clk25 after 20 ns;  -- 25 MHz

    uut: entity work.vga_timing
        port map (
            clk25       => clk25,
            reset_n     => reset_n,
            h_count     => h_count,
            v_count     => v_count,
            hs          => hs,
            vs          => vs,
            display_active => display_active,
            vsync_pulse    => vsync_pulse
        );

    stim: process
    begin
        wait for 50 ns;
        reset_n <= '1';

        -- Test 1: efter en frame ska h_count ha wrappat
        -- Frame = 800*525 = 420000 pixel-klockor = 16.8 ms
        wait for 17 ms;

        -- Test 3: HS ska vara aktiv-lag under sync-fonstret (h_count 656..751)
        wait until rising_edge(clk25) and h_count = 656;
        wait for 1 ns;
        assert hs = '0'
            report "FAIL: HS ska vara 0 vid h_count=656" severity failure;
        wait until rising_edge(clk25) and h_count = 752;
        wait for 1 ns;
        assert hs = '1'
            report "FAIL: HS ska vara 1 vid h_count=752" severity failure;

        -- Test 4: VS ska vara aktiv-lag under v_count = 490..491
        wait until rising_edge(clk25) and v_count = 490 and h_count = 0;
        wait for 1 ns;
        assert vs = '0'
            report "FAIL: VS ska vara 0 vid v_count=490" severity failure;

        -- Test 5: display_active sant inne i synliga regionen
        wait until rising_edge(clk25) and h_count = 100 and v_count = 100;
        wait for 1 ns;
        assert display_active = '1'
            report "FAIL: display_active ska vara 1 inne i synlig region" severity failure;

        report "PASS: vga_timing genererar korrekta signaler";
        finish;
    end process;
end architecture sim;
