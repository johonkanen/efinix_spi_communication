LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.clock_divider_pkg.all;
    use work.spi_master_pkg.all;

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
    signal spi_data_out : std_logic;

    signal user_led : std_logic_vector(3 downto 0);

    signal self : spi_master_record := init_spi_master;


    signal capture_buffer : std_logic_vector(15 downto 0);

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(user_led = "1111", "leds were not turned on");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            create_spi_master(self, spi_data_out);

            CASE simulation_counter is
                WHEN 50 => transmit_number_of_bytes(self,2);
                load_transmit_register(self, x"acdc");
                WHEN others => --do nothing
            end CASE;
            if ready_to_receive_packet(self) then
                load_transmit_register(self, x"dc");
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    dut_top : entity work.top
    port map(
        main_clock   => simulator_clock           ,
        spi_data_in  => self.spi_data_from_master ,
        spi_clock    => self.spi_clock            ,
        spi_cs_in    => self.spi_cs_in            ,
        spi_data_out => spi_data_out              ,
        user_led     => user_led
    );
------------------------------------------------------------------------
    catch_spi : process(self.spi_clock)
        
    begin
        if falling_edge(self.spi_clock) then
            capture_buffer <= capture_buffer(14 downto 0) & self.spi_data_from_master;
        end if; --rising_edge
    end process catch_spi;	
end vunit_simulation;
