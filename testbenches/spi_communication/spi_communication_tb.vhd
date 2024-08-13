LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity spi_communication_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of spi_communication_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5000;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal spi_clock : std_logic := '0';
    signal spi_cs_in : std_logic := '0';
    signal spi_data_out : std_logic;
    signal user_led : std_logic_vector(3 downto 0);

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
    spi_clock <= not spi_clock after clock_period/8.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    dut_top : entity work.top
    port map(
        main_clock      => simulator_clock,
        spi_data_in     => '1'          ,
        spi_clock       => spi_clock    ,
        spi_cs_in       => spi_cs_in    ,
        spi_data_out    => spi_data_out ,
        user_led        => user_led
    );
------------------------------------------------------------------------

end vunit_simulation;
