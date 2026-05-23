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
    signal clk25       : std_logic;
    signal reset_n     : std_logic;
    signal cell_addr   : unsigned(12 downto 0);
    signal cell_alive  : std_logic;
    signal vsync_pulse : std_logic;

    -- Init-signaler for att ladda monstret en gang
    signal init_done : std_logic := '0';
    signal init_addr : unsigned(12 downto 0) := (others => '0');
    signal init_data : std_logic := '0';
    signal init_en   : std_logic := '0';

    -- Hardkodat monster: ett kors i mitten (cell 40,30 och dess 4 grannar)
    -- Center addr = 30*80 + 40 = 2440
    -- Up: 29*80+40=2360, Down: 31*80+40=2520, Left: 30*80+39=2439, Right: 30*80+41=2441
    type addr_arr is array (0 to 4) of integer;
    constant CROSS_ADDRS : addr_arr := (2440, 2360, 2520, 2439, 2441);
begin
    reset_n <= key(3);

    clk_div: entity work.clk25_div
        port map (
            clk50_in  => clk50,
            reset_n   => reset_n,
            clk25_out => clk25
        );

    -- Init-process: vid uppstart, skriv CROSS_ADDRS till buffer 0
    init: process(clk25, reset_n)
        variable idx : integer range 0 to 5 := 0;
    begin
        if reset_n = '0' then
            idx := 0;
            init_en   <= '0';
            init_done <= '0';
        elsif rising_edge(clk25) then
            if init_done = '0' then
                if idx < 5 then
                    init_addr <= to_unsigned(CROSS_ADDRS(idx), 13);
                    init_data <= '1';
                    init_en   <= '1';
                    idx := idx + 1;
                else
                    init_en   <= '0';
                    init_done <= '1';
                end if;
            else
                init_en <= '0';
            end if;
        end if;
    end process;

    grid: entity work.grid_bram
        port map (
            clk       => clk25,
            wr_addr   => init_addr,
            wr_data   => init_data,
            wr_en     => init_en,
            wr_buffer => '0',
            rd_addr   => cell_addr,
            rd_data   => cell_alive,
            rd_buffer => '0'
        );

    vga: entity work.vga_renderer
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

    ledr <= "000000000" & init_done;  -- LEDR[0] tands nar init klart
end architecture rtl;
