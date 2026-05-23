library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity tb_control_fsm is end entity;

architecture sim of tb_control_fsm is
    signal clk        : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal vsync      : std_logic := '0';
    signal pause_pulse: std_logic := '0';
    signal step_pulse : std_logic := '0';
    signal load_pulse : std_logic := '0';
    signal engine_done: std_logic := '0';
    signal speed_sel  : unsigned(2 downto 0) := "111";  -- 60 gen/sek
    signal paused     : std_logic;
    signal trig_engine: std_logic;
    signal trig_load  : std_logic;
begin
    clk <= not clk after 20 ns;

    uut: entity work.control_fsm
        port map (
            clk          => clk,
            reset_n      => reset_n,
            vsync_pulse  => vsync,
            pause_pulse  => pause_pulse,
            step_pulse   => step_pulse,
            load_pulse   => load_pulse,
            engine_done  => engine_done,
            speed_sel    => speed_sel,
            paused       => paused,
            trigger_engine => trig_engine,
            trigger_load => trig_load
        );

    stim: process
    begin
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;

        -- Vid uppstart ska paused vara '1' (start pausad)
        assert paused = '1' report "FAIL: ska starta pausad" severity failure;

        -- Pulsa pause -> ska ga ur paus
        pause_pulse <= '1'; wait until rising_edge(clk); pause_pulse <= '0';
        wait until rising_edge(clk);
        assert paused = '0' report "FAIL: pause-toggle borde gora paused=0" severity failure;

        -- Pulsa vsync -> ska trigga engine (speed 111 = 60 gen/s = N=1)
        vsync <= '1'; wait until rising_edge(clk); vsync <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);  -- en cykel for FSM
        assert trig_engine = '1' report "FAIL: trigger_engine ska pulsa efter vsync" severity failure;

        -- Pulsa load -> ska trigga load
        load_pulse <= '1'; wait until rising_edge(clk); load_pulse <= '0';
        wait until rising_edge(clk);
        assert trig_load = '1' report "FAIL: trigger_load ska pulsa" severity failure;

        report "PASS: control_fsm grundlogik fungerar";
        finish;
    end process;
end architecture sim;
