library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 4-bits BCD/hex till 7-segment-display. Aktiv-lag (0 = pa, 1 = slackt).
-- Segment-mappning: gfedcba (bit 6 = g, bit 0 = a)
entity hex_decoder is
    port (
        nibble : in  unsigned(3 downto 0);
        seg    : out std_logic_vector(6 downto 0)
    );
end entity hex_decoder;

architecture rtl of hex_decoder is
begin
    with to_integer(nibble) select
        seg <=
            "1000000" when 0,
            "1111001" when 1,
            "0100100" when 2,
            "0110000" when 3,
            "0011001" when 4,
            "0010010" when 5,
            "0000010" when 6,
            "1111000" when 7,
            "0000000" when 8,
            "0010000" when 9,
            "0001000" when 10,  -- A
            "0000011" when 11,  -- b
            "1000110" when 12,  -- C
            "0100001" when 13,  -- d
            "0000110" when 14,  -- E
            "0001110" when others; -- F
end architecture rtl;
