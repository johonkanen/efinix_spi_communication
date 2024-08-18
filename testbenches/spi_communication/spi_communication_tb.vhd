
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.clock_divider_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity spi_communication_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of spi_communication_tb is

    package spi_transmitter_pkg is new work.spi_transmitter_generic_pkg generic map(g_clock_divider => 5);
    use spi_transmitter_pkg.all;

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5000;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal spi_data_out : std_logic;

    signal user_led : std_logic_vector(3 downto 0);

    signal spi_transmmitter : spi_transmitter_record := init_spi_transmitter;

    signal capture_buffer : std_logic_vector(15 downto 0);
    signal packet_counter : natural := 0;

    constant test_frame : bytearray :=(x"04", x"00", x"01", x"ac", x"dc");
    /* constant test_frame : bytearray :=(x"02", x"00", x"01", x"ac", x"dc",x"dc", x"dc", x"dc"); */

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

    ------------------------------------------------
        procedure create_spi_master 
        (
            signal spi_transmmitter : inout spi_transmitter_record
        )
        is
        begin
            create_spi_transmitter(spi_transmmitter, spi_data_out);
            if ready_to_receive_packet(spi_transmmitter) and packet_counter < test_frame'high  then
                transmit_byte(spi_transmmitter, test_frame(packet_counter+1));
                packet_counter <= packet_counter + 1;
            end if;
            
        end create_spi_master;
    ------------------------------------------------
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_spi_master(spi_transmmitter);

            CASE simulation_counter is
                WHEN 50 => 
                    transmit_byte(spi_transmmitter, test_frame(0));
                WHEN others => --do nothing
            end CASE;
        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    dut_top : entity work.top
    port map(
        main_clock   => simulator_clock           ,
        spi_data_in  => spi_transmmitter.spi_data_from_master ,
        spi_clock    => spi_transmmitter.spi_clock            ,
        spi_cs_in    => spi_transmmitter.spi_cs_in            ,
        spi_data_out => spi_data_out              ,
        user_led     => user_led
    );
------------------------------------------------------------------------
    catch_spi : process(spi_transmmitter.spi_clock)
    begin
        if rising_edge(spi_transmmitter.spi_clock) then
            capture_buffer <= capture_buffer(14 downto 0) & spi_data_out;
        end if; --rising_edge
    end process catch_spi;	
------------------------------------------------------------------------
end vunit_simulation;
