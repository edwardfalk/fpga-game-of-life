library ieee;
use ieee.std_logic_1164.all;

entity clk25_div is
    port (
        clk50_in  : in  std_logic;
        reset_n   : in  std_logic;
        clk25_out : out std_logic
    );
end entity clk25_div;

architecture rtl of clk25_div is
    signal toggle : std_logic := '0';
begin
    process(clk50_in, reset_n)
    begin
        if reset_n = '0' then
            toggle <= '0';
        elsif rising_edge(clk50_in) then
            toggle <= not toggle;
        end if;
    end process;
    clk25_out <= toggle;
end architecture rtl;
