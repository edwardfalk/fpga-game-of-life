library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Single 4800x1 dual-port BRAM bank (inferable as M10K on Cyclone V)
-- Write port: synchronous on clock edge
-- Read port:  synchronous with 1-cycle latency
entity bram_4800x1 is
    port (
        clk     : in  std_logic;
        wr_addr : in  unsigned(12 downto 0);
        wr_data : in  std_logic;
        wr_en   : in  std_logic;
        rd_addr : in  unsigned(12 downto 0);
        rd_data : out std_logic
    );
end entity bram_4800x1;

architecture rtl of bram_4800x1 is
    type ram_t is array (0 to 4799) of std_logic;
    signal ram         : ram_t := (others => '0');
    signal rd_data_reg : std_logic := '0';
begin
    write_proc: process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                ram(to_integer(wr_addr)) <= wr_data;
            end if;
        end if;
    end process;

    read_proc: process(clk)
    begin
        if rising_edge(clk) then
            rd_data_reg <= ram(to_integer(rd_addr));
        end if;
    end process;

    rd_data <= rd_data_reg;
end architecture rtl;


-- Dual-buffer (ping-pong) BRAM wrapper for 80x60 Game of Life grid.
-- Instantiates two bram_4800x1 banks; bank selection is done externally
-- via combinational wr_en routing and a registered rd_buffer mux so that
-- the mux latches align with the 1-cycle BRAM read latency.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity grid_bram is
    port (
        clk       : in  std_logic;
        wr_addr   : in  unsigned(12 downto 0);  -- 0..4799
        wr_data   : in  std_logic;
        wr_en     : in  std_logic;
        wr_buffer : in  std_logic;              -- 0 = bank0, 1 = bank1
        rd_addr   : in  unsigned(12 downto 0);
        rd_data   : out std_logic;
        rd_buffer : in  std_logic               -- 0 = bank0, 1 = bank1
    );
end entity grid_bram;

architecture rtl of grid_bram is
    signal wr_en_0, wr_en_1     : std_logic;
    signal rd_data_0, rd_data_1 : std_logic;
    signal rd_buffer_reg        : std_logic := '0';
begin
    -- Route write enable to the selected bank only
    wr_en_0 <= wr_en when wr_buffer = '0' else '0';
    wr_en_1 <= wr_en when wr_buffer = '1' else '0';

    bank0: entity work.bram_4800x1
        port map (
            clk     => clk,
            wr_addr => wr_addr,
            wr_data => wr_data,
            wr_en   => wr_en_0,
            rd_addr => rd_addr,
            rd_data => rd_data_0
        );

    bank1: entity work.bram_4800x1
        port map (
            clk     => clk,
            wr_addr => wr_addr,
            wr_data => wr_data,
            wr_en   => wr_en_1,
            rd_addr => rd_addr,
            rd_data => rd_data_1
        );

    -- Delay rd_buffer by 1 cycle to match the BRAM read latency
    delay_proc: process(clk)
    begin
        if rising_edge(clk) then
            rd_buffer_reg <= rd_buffer;
        end if;
    end process;

    -- Select output from the bank that was read
    rd_data <= rd_data_0 when rd_buffer_reg = '0' else rd_data_1;
end architecture rtl;
