library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ROM med 8 forinitialiserade Game of Life-monster.
-- Varje monster: 64 bit x 16 rader = 1024 bits.
-- Total: 8 * 1024 = 8192 bits = 1 M10K
entity pattern_rom is
    port (
        clk         : in  std_logic;
        pattern_sel : in  unsigned(2 downto 0);  -- 0..7
        x           : in  unsigned(5 downto 0);  -- 0..63
        y           : in  unsigned(3 downto 0);  -- 0..15
        bit_out     : out std_logic
    );
end entity pattern_rom;

architecture rtl of pattern_rom is
    -- Varje rad ar en 64-bit string. MSB ar bit x=0, LSB ar bit x=63.
    -- For att slaa upp bit x, anvand: row(63 - x).
    type pattern_row_arr is array (0 to 7, 0 to 15) of std_logic_vector(63 downto 0);
    constant PATTERNS : pattern_row_arr := (
        -- Pattern 0: Glider
        --   x: 0123
        -- y=0: .#..
        -- y=1: ..#.
        -- y=2: ###.
        0 => (
            0  => x"4000000000000000",  -- bit 62 -> x=1 alive
            1  => x"2000000000000000",  -- bit 61 -> x=2 alive
            2  => x"E000000000000000",  -- bits 63,62,61 -> x=0,1,2 alive
            others => (others => '0')
        ),
        -- Pattern 1: Blinker (3 i rad horisontellt)
        1 => (
            0  => x"E000000000000000",
            others => (others => '0')
        ),
        -- Pattern 2: R-pentomino
        --   .##
        --   ##.
        --   .#.
        2 => (
            0  => x"6000000000000000",
            1  => x"C000000000000000",
            2  => x"4000000000000000",
            others => (others => '0')
        ),
        -- Pattern 3: Gosper glider gun (36x9), canonical from Life-Wiki
        -- Row layout (x=0..35):
        --   y=0: ........................#...........
        --   y=1: ......................#.#...........
        --   y=2: ............##......##............##
        --   y=3: ...........#...#....##............##
        --   y=4: ##........#.....#...##..............
        --   y=5: ##........#...#.##....#.#...........
        --   y=6: ..........#.....#.......#...........
        --   y=7: ...........#...#....................
        --   y=8: ............##......................
        -- 64-bit row: x=0 maps to MSB (bit 63), x=N maps to bit (63-N).
        3 => (
            0 => x"0000008000000000",  -- (24)
            1 => x"0000028000000000",  -- (22, 24)
            2 => x"000C0C0030000000",  -- (12,13, 20,21, 34,35)
            3 => x"00110C0030000000",  -- (11, 15, 20,21, 34,35)
            4 => x"C0208C0000000000",  -- (0,1, 10, 16, 20,21)
            5 => x"C022C28000000000",  -- (0,1, 10, 14, 16,17, 22, 24)
            6 => x"0020808000000000",  -- (10, 16, 24)
            7 => x"0011000000000000",  -- (11, 15)
            8 => x"000C000000000000",  -- (12, 13)
            others => (others => '0')
        ),
        -- Pattern 4: LWSS (5x4)
        --   .####
        --   #...#
        --   ....#
        --   #..#.
        4 => (
            0 => x"7800000000000000",
            1 => x"8800000000000000",
            2 => x"0800000000000000",
            3 => x"9000000000000000",
            others => (others => '0')
        ),
        -- Pattern 5: Acorn (7x3)
        --   .#.....
        --   ...#...
        --   ##..###
        5 => (
            0 => x"4000000000000000",
            1 => x"1000000000000000",
            2 => x"CE00000000000000",
            others => (others => '0')
        ),
        -- Pattern 6: Toad (oscillator, period 2)
        --   .###
        --   ###.
        6 => (
            0 => x"7000000000000000",
            1 => x"E000000000000000",
            others => (others => '0')
        ),
        -- Pattern 7: Diehard (8x3)
        --   ......#.
        --   ##......
        --   .#...###
        7 => (
            0 => x"0200000000000000",
            1 => x"C000000000000000",
            2 => x"4700000000000000",
            others => (others => '0')
        )
    );

    signal bit_reg : std_logic := '0';
begin
    read_proc: process(clk)
        variable row : std_logic_vector(63 downto 0);
    begin
        if rising_edge(clk) then
            row := PATTERNS(to_integer(pattern_sel), to_integer(y));
            bit_reg <= row(63 - to_integer(x));
        end if;
    end process;

    bit_out <= bit_reg;
end architecture rtl;
