library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- VGA-timing for 640x480 @ 60Hz med pixel-klocka 25 MHz
-- Horizontal: 640 visible + 16 front + 96 sync + 48 back = 800
-- Vertical:   480 visible + 10 front + 2 sync + 33 back = 525
-- HS, VS aktiva-laga under sync-pulsen
entity vga_timing is
    port (
        clk25          : in  std_logic;
        reset_n        : in  std_logic;
        h_count        : out unsigned(9 downto 0);
        v_count        : out unsigned(9 downto 0);
        hs             : out std_logic;
        vs             : out std_logic;
        display_active : out std_logic;
        vsync_pulse    : out std_logic   -- 1-cykels puls vid borjan av VSYNC
    );
end entity vga_timing;

architecture rtl of vga_timing is
    constant H_VISIBLE : integer := 640;
    constant H_FP      : integer := 16;
    constant H_SYNC    : integer := 96;
    constant H_BP      : integer := 48;
    constant H_TOTAL   : integer := 800;
    constant H_SYNC_START : integer := H_VISIBLE + H_FP;       -- 656
    constant H_SYNC_END   : integer := H_VISIBLE + H_FP + H_SYNC; -- 752

    constant V_VISIBLE : integer := 480;
    constant V_FP      : integer := 10;
    constant V_SYNC    : integer := 2;
    constant V_BP      : integer := 33;
    constant V_TOTAL   : integer := 525;
    constant V_SYNC_START : integer := V_VISIBLE + V_FP;       -- 490
    constant V_SYNC_END   : integer := V_VISIBLE + V_FP + V_SYNC; -- 492

    signal hc : unsigned(9 downto 0) := (others => '0');
    signal vc : unsigned(9 downto 0) := (others => '0');
begin
    counter: process(clk25, reset_n)
    begin
        if reset_n = '0' then
            hc <= (others => '0');
            vc <= (others => '0');
        elsif rising_edge(clk25) then
            if hc = H_TOTAL - 1 then
                hc <= (others => '0');
                if vc = V_TOTAL - 1 then
                    vc <= (others => '0');
                else
                    vc <= vc + 1;
                end if;
            else
                hc <= hc + 1;
            end if;
        end if;
    end process counter;

    -- Output signaler (kombinatoriska fran raknarna)
    h_count <= hc;
    v_count <= vc;
    hs <= '0' when (hc >= H_SYNC_START and hc < H_SYNC_END) else '1';
    vs <= '0' when (vc >= V_SYNC_START and vc < V_SYNC_END) else '1';
    display_active <= '1' when (hc < H_VISIBLE and vc < V_VISIBLE) else '0';

    -- vsync_pulse: 1 cykel nar vi startar blanking (vid hc=0, vc=V_VISIBLE)
    vsync_gen: process(clk25, reset_n)
    begin
        if reset_n = '0' then
            vsync_pulse <= '0';
        elsif rising_edge(clk25) then
            if hc = 0 and vc = V_VISIBLE then
                vsync_pulse <= '1';
            else
                vsync_pulse <= '0';
            end if;
        end if;
    end process vsync_gen;
end architecture rtl;
