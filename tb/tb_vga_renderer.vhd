library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_vga_renderer is end entity;

architecture sim of tb_vga_renderer is
    signal clk25      : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal cell_alive : std_logic := '0';
    signal cell_addr  : unsigned(12 downto 0);
    signal vga_r      : std_logic_vector(3 downto 0);
    signal vga_g      : std_logic_vector(3 downto 0);
    signal vga_b      : std_logic_vector(3 downto 0);
    signal vga_hs     : std_logic;
    signal vga_vs     : std_logic;
    signal vsync_pulse: std_logic;
begin
    clk25 <= not clk25 after 20 ns;

    uut: entity work.vga_renderer
        port map (
            clk25       => clk25,
            reset_n     => reset_n,
            cell_alive  => cell_alive,
            cell_addr   => cell_addr,
            vga_r       => vga_r,
            vga_g       => vga_g,
            vga_b       => vga_b,
            vga_hs      => vga_hs,
            vga_vs      => vga_vs,
            vsync_pulse => vsync_pulse
        );

    stim: process
    begin
        wait for 50 ns;
        reset_n <= '1';

        cell_alive <= '0';
        -- Vanta upp till en frame (17 ms) pa att vsync_pulse triggas
        for i in 1 to 1000000 loop
            wait until rising_edge(clk25);
            if vsync_pulse = '1' then
                report "PASS: vga_renderer producerar vsync_pulse";
                finish;
            end if;
            if i = 999999 then
                report "FAIL: ingen vsync_pulse efter 40ms" severity failure;
            end if;
        end loop;
        wait;
    end process;
end architecture sim;
