
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity spi_communication_tb is
  generic (runner_cfg : string;
           -- spi clock period is g_spi_clock_divider+1 simulator clocks
           g_spi_clock_divider : natural := 5);
end;

architecture vunit_simulation of spi_communication_tb is

    package spi_transmitter_pkg is new work.spi_transmitter_generic_pkg generic map(g_clock_divider => g_spi_clock_divider);
    use spi_transmitter_pkg.all;

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5000;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal spi_data_out : std_logic;

    signal user_led : std_logic_vector(3 downto 0);

    signal spi_transmitter : spi_transmitter_record := init_spi_transmitter;

    signal capture_buffer : std_logic_vector(15 downto 0);
    signal packet_counter : natural := 0;

    constant write_leds_on_frame : bytearray := (x"04", x"00", x"01", x"ac", x"dc");

    constant read_from_address_1_frame : bytearray := (x"02", x"00", x"01", x"00", x"00", x"00", x"00", x"00", x"00");

    -- read command is 3 bytes, the response starts one byte after it
    constant first_read_response_byte_index : natural := 4;

    constant number_of_streamed_words : natural := 10;
    -- streamed words start after the command echo, same as response[7:] in pyspi_test.py
    constant first_streamed_byte_index : natural := 7;
    -- stream command for 10 words from address 1, followed by dummy bytes to clock out the response
    constant stream_10_words_frame : bytearray := (x"05", x"00", x"01", x"00", x"00", x"0a",
                                                    x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00",
                                                    x"00",x"00");

    signal test_frame : bytearray(0 to 31) := (others => x"00");
    signal test_frame_length : natural := 0;

    signal received_bytes : bytearray(0 to 63) := (others => x"00");
    signal number_of_received_bytes : natural := 0;
    signal received_bit_counter : natural range 0 to 7 := 0;

begin

------------------------------------------------------------------------
    simtime : process
        procedure set_test_frame(frame : bytearray) is
        begin
            test_frame(0 to frame'length-1) <= frame;
            test_frame_length <= frame'length;
        end set_test_frame;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
            if run("write turns leds on") then
                set_test_frame(write_leds_on_frame);
                wait for simtime_in_clocks*clock_period;
                check(user_led = "1111", "leds were not turned on");

            elsif run("write directly after stream turns leds on") then
                -- padding bytes of the stream frame must not shift the following command
                set_test_frame(stream_10_words_frame & write_leds_on_frame);
                wait for simtime_in_clocks*clock_period;
                check(user_led = "1111", "leds were not turned on");

            elsif run("read from address") then
                set_test_frame(read_from_address_1_frame);
                wait for simtime_in_clocks*clock_period;
                check_equal(
                    received_bytes(first_read_response_byte_index) & received_bytes(first_read_response_byte_index + 1),
                    std_logic_vector'(x"abcd"),
                    "read response");

            elsif run("stream data from address") then
                set_test_frame(stream_10_words_frame);
                wait for simtime_in_clocks*clock_period;
                for i in 0 to number_of_streamed_words-1 loop
                    check_equal(
                        received_bytes(first_streamed_byte_index + 2*i) & received_bytes(first_streamed_byte_index + 2*i + 1),
                        std_logic_vector'(x"abcd"),
                        "streamed word " & integer'image(i));
                end loop;
            end if;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
    ------------------------------------------------
        procedure create_spi_master 
        (
            signal spi_transmitter : inout spi_transmitter_record
        )
        is
        begin
            create_spi_transmitter(spi_transmitter, spi_data_out);
            if ready_to_receive_packet(spi_transmitter) and packet_counter < test_frame_length-1  then
                transmit_byte(spi_transmitter, test_frame(packet_counter+1));
                packet_counter <= packet_counter + 1;
            end if;
            
        end create_spi_master;
    ------------------------------------------------
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_spi_master(spi_transmitter);

            CASE simulation_counter is
                WHEN 50 => 
                    transmit_byte(spi_transmitter, test_frame(0));
                WHEN others => --do nothing
            end CASE;
        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    dut_top : entity work.top
    port map(
        main_clock   => simulator_clock ,
        spi_data_in  => spi_transmitter.spi_data_from_master ,
        spi_clock    => spi_transmitter.spi_clock            ,
        spi_cs_in    => spi_transmitter.spi_cs_in            ,
        spi_data_out => spi_data_out                          ,
        user_led     => user_led
    );
------------------------------------------------------------------------
    catch_spi : process(spi_transmitter.spi_clock)
    begin
        if rising_edge(spi_transmitter.spi_clock) then
            capture_buffer <= capture_buffer(14 downto 0) & spi_data_out;

            if received_bit_counter = 7 then
                received_bit_counter <= 0;
                received_bytes(number_of_received_bytes) <= capture_buffer(6 downto 0) & spi_data_out;
                number_of_received_bytes <= number_of_received_bytes + 1;
            else
                received_bit_counter <= received_bit_counter + 1;
            end if;
        end if; --rising_edge
    end process catch_spi;	
------------------------------------------------------------------------
end vunit_simulation;
