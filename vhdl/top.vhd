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
begin
    -- Stubbar - fylls i kommande tasks
    ledr   <= sw;
    vga_r  <= (others => '0');
    vga_g  <= (others => '0');
    vga_b  <= (others => '0');
    vga_hs <= '1';
    vga_vs <= '1';
end architecture rtl;
