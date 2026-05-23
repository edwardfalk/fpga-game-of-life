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
    signal clk25          : std_logic;
    signal h_count        : unsigned(9 downto 0);
    signal v_count        : unsigned(9 downto 0);
    signal display_active : std_logic;
    signal reset_n        : std_logic;
begin
    -- KEY[3] = reset (aktiv-lag knapp = aktiv-lag reset)
    reset_n <= key(3);

    clk_div: entity work.clk25_div
        port map (
            clk50_in  => clk50,
            reset_n   => reset_n,
            clk25_out => clk25
        );

    vga: entity work.vga_timing
        port map (
            clk25          => clk25,
            reset_n        => reset_n,
            h_count        => h_count,
            v_count        => v_count,
            hs             => vga_hs,
            vs             => vga_vs,
            display_active => display_active,
            vsync_pulse    => open
        );

    -- Testmonster: rod gradient horisontellt, gron gradient vertikalt, blatt fast
    -- (bara nar display_active = 1, annars svart)
    color_gen: process(clk25)
    begin
        if rising_edge(clk25) then
            if display_active = '1' then
                vga_r <= std_logic_vector(h_count(9 downto 6));
                vga_g <= std_logic_vector(v_count(8 downto 5));
                vga_b <= "0011";
            else
                vga_r <= (others => '0');
                vga_g <= (others => '0');
                vga_b <= (others => '0');
            end if;
        end if;
    end process color_gen;

    -- Behall LEDR som SW-spegel for nu (debug)
    ledr <= sw;
end architecture rtl;
