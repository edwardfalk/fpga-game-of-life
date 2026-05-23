library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Pattern loader FSM:
-- Vid start='1':
--   1. Phase CLEAR: skriv '0' till alla 4800 celler i dst_buffer
--   2. Phase LOAD: las 16*64 bitar fran pattern_rom, skriv levande till BRAM
--      med offset (dst_x = 8 + bitmap_x, dst_y = 22 + bitmap_y)
--   3. Pulsa done='1' i en cykel
--
-- OBS: pattern_rom ar registrerat (1 cykel latens).
-- I S_LOAD_PATTERN: adress presenteras en cykel, data lases nasta cykel.
-- Implementering: load_x/load_y pekar pa naesta cell att lasa.
-- Vi presenterar koordinaterna till ROM och vanter en cykel, sedan
-- anvander vi rom_bit for den koordinaten.
entity pattern_loader is
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        start       : in  std_logic;
        pattern_sel : in  unsigned(2 downto 0);
        dst_buffer  : in  std_logic;

        -- BRAM-skrivport
        wr_addr     : out unsigned(12 downto 0);
        wr_data     : out std_logic;
        wr_en       : out std_logic;
        wr_buffer_o : out std_logic;

        busy        : out std_logic;
        done        : out std_logic
    );
end entity pattern_loader;

architecture rtl of pattern_loader is
    type state_t is (S_IDLE, S_CLEAR, S_LOAD_FETCH, S_LOAD_WRITE, S_DONE);
    signal state : state_t := S_IDLE;

    signal clear_addr  : unsigned(12 downto 0) := (others => '0');
    -- load_x/load_y: adress som presenterades till ROM forra cykeln
    signal load_x      : unsigned(5 downto 0)  := (others => '0');
    signal load_y      : unsigned(3 downto 0)  := (others => '0');

    -- Nasta koordinat att presentera till ROM
    signal next_x      : unsigned(5 downto 0)  := (others => '0');
    signal next_y      : unsigned(3 downto 0)  := (others => '0');

    signal last_cell   : std_logic := '0';  -- flagga: detta ar sista cellen

    -- Pattern ROM-interface internt
    signal rom_bit : std_logic;

    -- Intern wr_addr register (kombinatoriskt)
    signal wr_addr_i   : unsigned(12 downto 0);
begin
    rom: entity work.pattern_rom
        port map (
            clk         => clk,
            pattern_sel => pattern_sel,
            x           => next_x,
            y           => next_y,
            bit_out     => rom_bit
        );

    -- Berakna wr_addr kombinatoriskt fran load_x/load_y
    -- Adress = (22 + load_y) * 80 + (8 + load_x)
    wr_addr_i <= resize(
                     (to_unsigned(22, 7) + resize(load_y, 7)) * to_unsigned(80, 7),
                     13
                 ) + resize(to_unsigned(8, 7) + resize(load_x, 7), 13);

    fsm: process(clk, reset_n)
        variable nx : unsigned(5 downto 0);
        variable ny : unsigned(3 downto 0);
    begin
        if reset_n = '0' then
            state      <= S_IDLE;
            clear_addr <= (others => '0');
            load_x     <= (others => '0');
            load_y     <= (others => '0');
            next_x     <= (others => '0');
            next_y     <= (others => '0');
            last_cell  <= '0';
            wr_en      <= '0';
            wr_data    <= '0';
            wr_addr    <= (others => '0');
            wr_buffer_o <= '0';
            done       <= '0';
        elsif rising_edge(clk) then
            wr_en <= '0';
            done  <= '0';

            case state is
                when S_IDLE =>
                    if start = '1' then
                        state      <= S_CLEAR;
                        clear_addr <= (others => '0');
                    end if;

                when S_CLEAR =>
                    -- Skriv 0 till alla 4800 adresser
                    wr_addr     <= clear_addr;
                    wr_data     <= '0';
                    wr_en       <= '1';
                    wr_buffer_o <= dst_buffer;
                    if clear_addr = to_unsigned(4799, 13) then
                        -- Starta LOAD: presentera forsta koordinaten (0,0) till ROM
                        state      <= S_LOAD_FETCH;
                        load_x     <= (others => '0');
                        load_y     <= (others => '0');
                        next_x     <= (others => '0');
                        next_y     <= (others => '0');
                        last_cell  <= '0';
                    else
                        clear_addr <= clear_addr + 1;
                    end if;

                when S_LOAD_FETCH =>
                    -- ROM-adress (next_x, next_y) ar presenterad.
                    -- Vanta en cykel sa att rom_bit ar giltigt nasta cykel.
                    -- Spara koordinaten som "aktiv" och berakna nasta.
                    load_x <= next_x;
                    load_y <= next_y;

                    -- Berakna nasta koordinat
                    if next_x = to_unsigned(63, 6) then
                        nx := (others => '0');
                        if next_y = to_unsigned(15, 4) then
                            -- Detta ar sista cellen
                            last_cell <= '1';
                            ny := next_y;  -- haall kvar (spelar ingen roll)
                        else
                            ny := next_y + 1;
                            last_cell <= '0';
                        end if;
                    else
                        nx := next_x + 1;
                        ny := next_y;
                        last_cell <= '0';
                    end if;
                    next_x <= nx;
                    next_y <= ny;

                    state <= S_LOAD_WRITE;

                when S_LOAD_WRITE =>
                    -- rom_bit ar nu giltigt for (load_x, load_y)
                    if rom_bit = '1' then
                        wr_addr     <= wr_addr_i;
                        wr_data     <= '1';
                        wr_en       <= '1';
                        wr_buffer_o <= dst_buffer;
                    end if;

                    if last_cell = '1' then
                        state <= S_DONE;
                    else
                        state <= S_LOAD_FETCH;
                    end if;

                when S_DONE =>
                    done  <= '1';
                    state <= S_IDLE;
            end case;
        end if;
    end process;

    busy <= '0' when state = S_IDLE else '1';
end architecture rtl;
