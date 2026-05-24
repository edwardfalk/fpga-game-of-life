library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Game of Life-engine.
-- Pa start='1': scanna alla 4800 celler. For varje cell:
--   1. Las 9 lasningar (8 grannar + self) seriellt, en per cykel
--   2. BRAM-latens ar 2 cykler: rd_addr satt vid cykel N -> rd_data giltig vid cykel N+2
--      (bero pa VHDL-signal-semantik: rd_addr syns av BRAM vid N+1, data ut efter N+1-kant)
--   3. Ackumulera n = antal levande grannar
--   4. Self_alive sparas separat
--   5. Berakna ny status enligt Conway's regel
--   6. Skriv resultat till dst_buffer
-- Pulsa done='1' nar klar.
entity gol_engine is
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        start      : in  std_logic;
        toroidal   : in  std_logic;
        src_buffer : in  std_logic;
        dst_buffer : in  std_logic;

        rd_addr     : out unsigned(12 downto 0);
        rd_data     : in  std_logic;
        wr_addr     : out unsigned(12 downto 0);
        wr_data     : out std_logic;
        wr_en       : out std_logic;
        wr_buffer_o : out std_logic;
        busy        : out std_logic;
        done        : out std_logic
    );
end entity gol_engine;

architecture rtl of gol_engine is
    type state_t is (S_IDLE, S_FETCH, S_DRAIN, S_DRAIN2, S_WRITE, S_DONE);
    signal state : state_t := S_IDLE;

    signal cur_x : unsigned(6 downto 0) := (others => '0');  -- 0..79
    signal cur_y : unsigned(5 downto 0) := (others => '0');  -- 0..59

    -- Fetch-index: 0..8 (0..7 = 8 grannar, 8 = self)
    signal fetch_idx  : integer range 0 to 9 := 0;
    -- Recv-index: okat vid varje S_FETCH/S_DRAIN cykel.
    -- BRAM-latens ar 2 cykler: data for fetch F antas vid recv_idx = F+2.
    -- Vi samplar: if recv_idx >= 2 then slot = recv_idx - 2.
    signal recv_idx   : integer range 0 to 10 := 0;

    signal nbr_count  : unsigned(3 downto 0) := (others => '0');
    signal self_alive : std_logic := '0';

    -- Neighbor offsets
    type offset_t is record
        dx : integer range -1 to 1;
        dy : integer range -1 to 1;
    end record;
    type offsets_arr is array (0 to 8) of offset_t;
    constant OFFSETS : offsets_arr := (
        0 => (-1, -1), 1 => (0, -1), 2 => (1, -1),
        3 => (-1, 0),                4 => (1, 0),
        5 => (-1, 1),  6 => (0, 1),  7 => (1, 1),
        8 => (0, 0)
    );

    -- Return type for calc_addr
    type addr_result_t is record
        addr  : unsigned(12 downto 0);
        valid : std_logic;
    end record;

    function calc_addr_r(x_in : integer; y_in : integer; tor : std_logic) return addr_result_t is
        variable wx, wy : integer;
        variable res : addr_result_t;
    begin
        if tor = '1' then
            wx := x_in;
            if wx < 0 then wx := wx + 80; end if;
            if wx >= 80 then wx := wx - 80; end if;
            wy := y_in;
            if wy < 0 then wy := wy + 60; end if;
            if wy >= 60 then wy := wy - 60; end if;
            res.valid := '1';
        else
            if x_in < 0 or x_in >= 80 or y_in < 0 or y_in >= 60 then
                res.valid := '0';
                wx := 0; wy := 0;
            else
                res.valid := '1';
                wx := x_in;
                wy := y_in;
            end if;
        end if;
        res.addr := to_unsigned(wy * 80 + wx, 13);
        return res;
    end function;

    signal cur_valid : std_logic_vector(0 to 9) := (others => '0');
    signal new_alive_comb : std_logic;
begin
    -- Conway's regel kombinatoriskt
    new_alive_comb <= '1' when (self_alive = '1' and (nbr_count = 2 or nbr_count = 3))
                          else '1' when (self_alive = '0' and nbr_count = 3)
                          else '0';

    fsm: process(clk, reset_n)
        variable nbr_x, nbr_y : integer;
        variable next_x, next_y : integer;
        variable ar : addr_result_t;
    begin
        if reset_n = '0' then
            state      <= S_IDLE;
            cur_x      <= (others => '0');
            cur_y      <= (others => '0');
            fetch_idx  <= 0;
            recv_idx   <= 0;
            nbr_count  <= (others => '0');
            self_alive <= '0';
            wr_en      <= '0';
            done       <= '0';
            cur_valid  <= (others => '0');
        elsif rising_edge(clk) then
            wr_en <= '0';
            done  <= '0';

            case state is
                when S_IDLE =>
                    if start = '1' then
                        cur_x      <= (others => '0');
                        cur_y      <= (others => '0');
                        fetch_idx  <= 0;
                        recv_idx   <= 0;
                        nbr_count  <= (others => '0');
                        self_alive <= '0';
                        cur_valid  <= (others => '0');
                        state      <= S_FETCH;
                    end if;

                when S_FETCH =>
                    -- Skicka las-adress for fetch_idx
                    nbr_x := to_integer(cur_x) + OFFSETS(fetch_idx).dx;
                    nbr_y := to_integer(cur_y) + OFFSETS(fetch_idx).dy;
                    ar := calc_addr_r(nbr_x, nbr_y, toroidal);
                    rd_addr <= ar.addr;
                    cur_valid(fetch_idx) <= ar.valid;

                    -- Sampla data: BRAM-latens ar 2 cykler fran att vi saetter rd_addr
                    -- till att data ar stabilt. Slot = recv_idx - 2.
                    if recv_idx >= 2 then
                        if cur_valid(recv_idx - 2) = '1' then
                            if recv_idx - 2 < 8 then
                                nbr_count <= nbr_count + ("000" & rd_data);
                            else
                                self_alive <= rd_data;
                            end if;
                        end if;
                    end if;

                    if fetch_idx = 8 then
                        -- Alla 9 adresser utskickade (index 0..8).
                        -- Vi behover 2 drain-cykler for att tappa sista 2 svaren.
                        fetch_idx <= 0;
                        state     <= S_DRAIN;
                        recv_idx  <= recv_idx + 1;
                    else
                        fetch_idx <= fetch_idx + 1;
                        recv_idx  <= recv_idx + 1;
                    end if;

                when S_DRAIN =>
                    -- recv_idx = 9 har. Med 2-cykels latens: slot = recv_idx - 2 = 7 (granne 7).
                    if cur_valid(recv_idx - 2) = '1' then
                        if recv_idx - 2 < 8 then
                            nbr_count <= nbr_count + ("000" & rd_data);
                        else
                            self_alive <= rd_data;
                        end if;
                    end if;
                    recv_idx <= recv_idx + 1;
                    state    <= S_DRAIN2;

                when S_DRAIN2 =>
                    -- recv_idx = 10 har. Slot = recv_idx - 2 = 8 (self).
                    if cur_valid(recv_idx - 2) = '1' then
                        if recv_idx - 2 < 8 then
                            nbr_count <= nbr_count + ("000" & rd_data);
                        else
                            self_alive <= rd_data;
                        end if;
                    end if;
                    state <= S_WRITE;

                when S_WRITE =>
                    wr_addr     <= to_unsigned(to_integer(cur_y) * 80 + to_integer(cur_x), 13);
                    wr_data     <= new_alive_comb;
                    wr_en       <= '1';
                    wr_buffer_o <= dst_buffer;

                    -- Nasta cell
                    nbr_count  <= (others => '0');
                    self_alive <= '0';
                    cur_valid  <= (others => '0');
                    recv_idx   <= 0;
                    fetch_idx  <= 0;

                    if cur_x = to_unsigned(79, 7) then
                        cur_x <= (others => '0');
                        if cur_y = to_unsigned(59, 6) then
                            state <= S_DONE;
                        else
                            cur_y <= cur_y + 1;
                            state <= S_FETCH;
                        end if;
                    else
                        cur_x <= cur_x + 1;
                        state <= S_FETCH;
                    end if;

                when S_DONE =>
                    done  <= '1';
                    state <= S_IDLE;
            end case;
        end if;
    end process;

    busy <= '0' when state = S_IDLE else '1';
end architecture rtl;
