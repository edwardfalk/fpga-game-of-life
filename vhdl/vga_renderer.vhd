library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- VGA-renderer som mappar pixel-koordinat till cell-koordinat och driver
-- VGA-farg baserat pa cell_alive.
-- Cell-grid ar 80x60, varje cell ar 8x8 pixlar.
-- cell_x = h_count[9:3], cell_y = v_count[8:3], addr = cell_y * 80 + cell_x
entity vga_renderer is
    port (
        clk25       : in  std_logic;
        reset_n     : in  std_logic;
        cell_alive  : in  std_logic;                       -- fran grid_bram
        cell_addr   : out unsigned(12 downto 0);           -- till grid_bram
        vga_r       : out std_logic_vector(3 downto 0);
        vga_g       : out std_logic_vector(3 downto 0);
        vga_b       : out std_logic_vector(3 downto 0);
        vga_hs      : out std_logic;
        vga_vs      : out std_logic;
        vsync_pulse : out std_logic
    );
end entity vga_renderer;

architecture rtl of vga_renderer is
    signal h_count        : unsigned(9 downto 0);
    signal v_count        : unsigned(9 downto 0);
    signal display_active : std_logic;
    signal cell_x         : unsigned(6 downto 0);
    signal cell_y         : unsigned(5 downto 0);
    signal addr_int       : unsigned(12 downto 0);
    signal display_d1     : std_logic;
begin
    timing: entity work.vga_timing
        port map (
            clk25          => clk25,
            reset_n        => reset_n,
            h_count        => h_count,
            v_count        => v_count,
            hs             => vga_hs,
            vs             => vga_vs,
            display_active => display_active,
            vsync_pulse    => vsync_pulse
        );

    -- Mappning pixel -> cell
    cell_x <= h_count(9 downto 3);   -- 0..79
    cell_y <= v_count(8 downto 3);   -- 0..59
    addr_int <= resize(unsigned(cell_y) * to_unsigned(80, 7), 13)
                + resize(unsigned(cell_x), 13);
    cell_addr <= addr_int;

    -- Forsenad display_active for att kompensera 1 cykels BRAM-laslatens
    delay: process(clk25)
    begin
        if rising_edge(clk25) then
            display_d1 <= display_active;
        end if;
    end process;

    -- Farg: gron pa svart for levande celler
    color: process(clk25)
    begin
        if rising_edge(clk25) then
            if display_d1 = '1' then
                if cell_alive = '1' then
                    vga_r <= "0010";
                    vga_g <= "1111";   -- ljus gron
                    vga_b <= "0010";
                else
                    vga_r <= "0000";
                    vga_g <= "0001";   -- mycket svagt gron bakgrund
                    vga_b <= "0000";
                end if;
            else
                vga_r <= "0000";
                vga_g <= "0000";
                vga_b <= "0000";
            end if;
        end if;
    end process;
end architecture rtl;
