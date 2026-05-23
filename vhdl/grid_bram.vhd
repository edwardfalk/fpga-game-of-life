library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Dual-port BRAM for 80x60-cell Game of Life-grid
-- Ping-pong: 2 buffrar a 4800 cells. wr_buffer / rd_buffer valjer vilken bank.
-- Skrivport: synkron, en bit at gangen pa wr_addr i wr_buffer
-- Lasport: synkron med 1 cykels latency pa rd_addr i rd_buffer
entity grid_bram is
    port (
        clk       : in  std_logic;
        wr_addr   : in  unsigned(12 downto 0);  -- 0..4799
        wr_data   : in  std_logic;
        wr_en     : in  std_logic;
        wr_buffer : in  std_logic;              -- 0 eller 1
        rd_addr   : in  unsigned(12 downto 0);
        rd_data   : out std_logic;
        rd_buffer : in  std_logic
    );
end entity grid_bram;

architecture rtl of grid_bram is
    type grid_t is array (0 to 4799) of std_logic;
    signal mem0 : grid_t := (others => '0');
    signal mem1 : grid_t := (others => '0');
    signal rd_data_int : std_logic := '0';
begin
    write_proc: process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                if wr_buffer = '0' then
                    mem0(to_integer(wr_addr)) <= wr_data;
                else
                    mem1(to_integer(wr_addr)) <= wr_data;
                end if;
            end if;
        end if;
    end process;

    read_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rd_buffer = '0' then
                rd_data_int <= mem0(to_integer(rd_addr));
            else
                rd_data_int <= mem1(to_integer(rd_addr));
            end if;
        end if;
    end process;

    rd_data <= rd_data_int;
end architecture rtl;
