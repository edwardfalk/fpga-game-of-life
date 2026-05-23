library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
    generic (
        CLK_FREQ_HZ : integer := 25_000_000;
        DEBOUNCE_MS : integer := 20
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        raw_in      : in  std_logic;
        db_out      : out std_logic;
        press_pulse : out std_logic  -- 1 cykel vid fallande flank (knapp-nedtryck)
    );
end entity debounce;

architecture rtl of debounce is
    constant DB_MAX : integer := (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    signal sync : std_logic_vector(1 downto 0) := "11";
    signal stable : std_logic := '1';
    signal stable_prev : std_logic := '1';
    signal db_cnt : integer range 0 to DB_MAX := 0;
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sync <= "11";
            stable <= '1';
            stable_prev <= '1';
            db_cnt <= 0;
            press_pulse <= '0';
        elsif rising_edge(clk) then
            sync(0) <= raw_in;
            sync(1) <= sync(0);
            press_pulse <= '0';

            if sync(1) = stable then
                db_cnt <= 0;
            elsif db_cnt = DB_MAX then
                stable <= sync(1);
                db_cnt <= 0;
            else
                db_cnt <= db_cnt + 1;
            end if;

            stable_prev <= stable;
            if stable_prev = '1' and stable = '0' then
                press_pulse <= '1';
            end if;
        end if;
    end process;

    db_out <= stable;
end architecture rtl;
