library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.fpga_interconnect_pkg.all;
    use work.spi_communication_pkg.all;

    use work.spi_secondary_pkg.all;
    use work.spi_protocol_pkg.all;

entity top is
    port (
        main_clock      : in std_logic;
        spi_data_in     : in std_logic;
        spi_clock       : in std_logic;
        spi_cs_in       : in std_logic;
        spi_data_out    : out std_logic;
        user_led        : out std_logic_vector(3 downto 0)
    );
end entity top;

architecture rtl of top is

    signal ledstate : std_logic_vector(3 downto 0) := "0000";

    signal bus_from_main : fpga_interconnect_record := init_fpga_interconnect;
    signal bus_from_test : fpga_interconnect_record := init_fpga_interconnect;

    signal bus_to_main : fpga_interconnect_record := init_fpga_interconnect;
    signal test_register : std_logic_vector(15 downto 0) := x"abcd";

    signal spi_rx_out : spi_rx_out_record;
    signal spi_tx_in  : spi_tx_in_record;
    signal spi_tx_out : spi_tx_out_record;

    signal spi_protocol : serial_communcation_record := init_serial_communcation;

    signal transmit_buffer : std_logic_vector(15 downto 0);

begin

    user_led <= ledstate;

------------------------------------------
    main : process(main_clock)
    begin
        if rising_edge(main_clock) then
            init_bus(bus_from_main);
            create_serial_protocol(spi_protocol, spi_rx_out, spi_tx_in, spi_tx_out);

            if frame_has_been_received(spi_protocol) then
                CASE get_command(spi_protocol) is
                    WHEN read_is_requested_from_address_from_uart =>
                        request_data_from_address(bus_from_main, get_command_address(spi_protocol));
                    WHEN write_to_address_is_requested_from_uart =>
                        write_data_to_address(bus_from_main, get_command_address(spi_protocol), get_command_data(spi_protocol));
                    WHEN others => --do nothing
                end CASE;
            end if;

            if write_to_address_is_requested(bus_to_main, 0) then
                transmit_words_with_uart(spi_protocol, (bus_to_main.data(15 downto 8), bus_to_main.data(7 downto 0)));
                transmit_buffer <= bus_to_main.data;
            end if;

        end if; --rising_edge
    end process main;
------------------------------------------
    test : process(main_clock)
    begin
        if rising_edge(main_clock) then
            bus_to_main <= bus_from_test;
        end if; --rising_edge
    end process test;	
------------------------------------------
    test_interconnect : process(main_clock)
    begin
        if rising_edge(main_clock) then
            init_bus(bus_from_test);
            connect_data_to_address(bus_from_main, bus_from_test, 1, test_register);
            if test_register = x"acdc" then
                ledstate <= "1111";
            else
                ledstate <= test_register(3 downto 0);
            end if;
        end if; --rising_edge
    end process test_interconnect;	
------------------------------------------
    u_spi_secondary : entity work.spi_secondary
    port map(
        main_clock                                ,
        spi_fpga_in.spi_data_in   => spi_data_in  ,
        spi_fpga_in.spi_clock     => spi_clock    ,
        spi_fpga_in.spi_cs_in     => spi_cs_in    ,
        spi_fpga_out.spi_data_out => spi_data_out ,
        spi_rx_out                => spi_rx_out   ,
        spi_tx_in                 => spi_tx_in    ,
        spi_tx_out                => spi_tx_out
    );
------------------------------------------
end rtl;
