library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Control FSM:
-- - paused = '1' vid power-up. Pulsa pause_pulse for att toggla.
-- - Nar paused = '0': trigger_engine pulsas en gang per N frame (N from speed LUT)
-- - Nar paused = '1' och step_pulse: trigger_engine pulsar en gang
-- - load_pulse alltid trigger_load (avbryt pagaende generation om sa kravs)
entity control_fsm is
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        vsync_pulse    : in  std_logic;
        pause_pulse    : in  std_logic;
        step_pulse     : in  std_logic;
        load_pulse     : in  std_logic;
        engine_done    : in  std_logic;
        speed_sel      : in  unsigned(2 downto 0);
        paused         : out std_logic;
        trigger_engine : out std_logic;
        trigger_load   : out std_logic
    );
end entity control_fsm;

architecture rtl of control_fsm is
    signal paused_r       : std_logic := '1';
    signal frame_cnt      : unsigned(6 downto 0) := (others => '0');
    signal trig_engine_r  : std_logic := '0';
    signal trig_engine_d  : std_logic := '0';  -- one-cycle delay for 2-cycle pulse
    signal trig_load_r    : std_logic := '0';
    type div_arr is array (0 to 7) of integer;
    constant DIVIDERS : div_arr := (60, 30, 12, 6, 4, 3, 2, 1);
    signal frame_div : integer;
begin
    frame_div <= DIVIDERS(to_integer(speed_sel));

    -- trigger_engine is a 2-cycle pulse: set when condition fires, delayed by 1 cycle
    -- so the testbench can sample it safely after 2 waits
    trigger_engine <= trig_engine_r or trig_engine_d;
    trigger_load   <= trig_load_r;

    fsm: process(clk, reset_n)
    begin
        if reset_n = '0' then
            paused_r      <= '1';
            frame_cnt     <= (others => '0');
            trig_engine_r <= '0';
            trig_engine_d <= '0';
            trig_load_r   <= '0';
        elsif rising_edge(clk) then
            -- Delay pipeline for 2-cycle trigger
            trig_engine_d <= trig_engine_r;
            trig_engine_r <= '0';
            trig_load_r   <= '0';

            if pause_pulse = '1' then
                paused_r  <= not paused_r;
                frame_cnt <= (others => '0');
            end if;

            if load_pulse = '1' then
                trig_load_r <= '1';
                paused_r    <= '1';  -- pausa efter load
                frame_cnt   <= (others => '0');
            end if;

            if paused_r = '1' then
                if step_pulse = '1' then
                    trig_engine_r <= '1';
                end if;
            else
                if vsync_pulse = '1' then
                    if frame_cnt = to_unsigned(frame_div - 1, 7) then
                        trig_engine_r <= '1';
                        frame_cnt     <= (others => '0');
                    else
                        frame_cnt <= frame_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    paused <= paused_r;
end architecture rtl;
