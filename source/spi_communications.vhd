------------------------------------------------------------------------
-- fpga_spi_communications - fpga_communication's register access over spi
--
-- the spi counterpart of fpga_communication's fpga_communications : the
-- same fpga_interconnect bus ports and the same serial protocol (read,
-- write, stream and request stream frames, responses with the same frames
-- as over the uart), with spi_secondary in place of the uart. the data and
-- address widths come from the fpga_interconnect package.
--
-- spi mode 0, msb first. the primary clocks the responses out by sending
-- bytes after its command ; zero bytes are not frames and are dropped by the
-- protocol, so it pads with zeros. after chip select falls the first byte
-- out is 0xff and idle bytes are 0x00, a response frame starts with its
-- nonzero header byte.
------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity fpga_spi_communications is
    generic(
        package fpga_interconnect_pkg is new work.fpga_interconnect_generic_pkg generic map(<>)
    );
    port (
        clock                    : in std_logic
        ;spi_clock               : in std_logic
        ;spi_cs_in               : in std_logic
        ;spi_data_in             : in std_logic
        ;spi_data_out            : out std_logic
        ;bus_to_communications   : in fpga_interconnect_pkg.fpga_interconnect_record
        ;bus_from_communications : out fpga_interconnect_pkg.fpga_interconnect_record
    );
end entity fpga_spi_communications;

architecture rtl of fpga_spi_communications is

    use work.spi_secondary_pkg.all;
    use fpga_interconnect_pkg.all;

    package spi_serial_protocol_pkg is new work.serial_protocol_generic_pkg
    generic map(serial_rx_data_output_record => spi_rx_out_record
                ,serial_tx_data_input_record  => spi_tx_in_record
                ,serial_tx_data_output_record => spi_tx_out_record
                --------------------------------
                ,serial_rx_data_is_ready => spi_rx_data_is_ready
                --------------------------------
                ,get_serial_rx_data => get_spi_rx_data
                --------------------------------
                ,init_serial => init_spi
                --------------------------------
                ,transmit_8bit_data_package => transmit_8bit_data_package
                --------------------------------
                ,serial_tx_is_ready  => spi_tx_is_ready
                ,g_data_bit_width    => bus_to_communications.data'length
                ,g_address_bit_width => bus_to_communications.address'length
            );

    use spi_serial_protocol_pkg.all;
    alias bus_in  is bus_to_communications;
    alias bus_out is bus_from_communications;

    signal spi_rx_out   : spi_rx_out_record;
    signal spi_tx_in    : spi_tx_in_record;
    signal spi_tx_out   : spi_tx_out_record;
    signal spi_protocol : serial_communcation_record := init_serial_communcation;

    signal number_of_registers_to_stream : integer range 0 to 2**23-1 := 0;
    signal stream_address : integer range 0 to 2**16-1 := 0;

    signal fpga_controlled_stream_requested : boolean := false;

begin

------------------------------------------------------------------------
    -- the frame handling of fpga_communications
    protocol : process(clock)
    begin
        if rising_edge(clock) then

            init_bus(bus_out);
            create_serial_protocol(spi_protocol, spi_rx_out, spi_tx_in, spi_tx_out);

            if frame_has_been_received(spi_protocol) then
                CASE get_command(spi_protocol) is
                    WHEN read_is_requested_from_address_from_serial =>
                        request_data_from_address(bus_out, get_command_address(spi_protocol));

                    WHEN write_to_address_is_requested_from_serial =>
                        write_data_to_address(bus_out, get_command_address(spi_protocol), get_command_data(spi_protocol));

                    -- unlike fpga_communications, no request here : spi_secondary
                    -- reports every byte, the command's last one included, as
                    -- transmitted, a couple of clocks after it was received, and
                    -- that transmit_is_ready requests the first word below. a
                    -- request here as well would start the first word twice.
                    WHEN stream_data_from_address =>
                        number_of_registers_to_stream <= get_number_of_registers_to_stream(spi_protocol);
                        stream_address                <= get_command_address(spi_protocol);
                        fpga_controlled_stream_requested <= false;

                    WHEN request_stream_from_address =>
                        request_data_from_address(bus_out, get_command_address(spi_protocol));
                        number_of_registers_to_stream <= get_number_of_registers_to_stream(spi_protocol);
                        fpga_controlled_stream_requested <= true;

                    WHEN others => -- do nothing
                end CASE;
            end if;

            if number_of_registers_to_stream > 0 then
                if not fpga_controlled_stream_requested then
                    if transmit_is_ready(spi_protocol) then
                        request_data_from_address(bus_out, stream_address);
                    end if;
                end if;

                if write_to_address_is_requested(bus_in, 0) then
                    number_of_registers_to_stream <= number_of_registers_to_stream - 1;
                    send_stream_data_packet(spi_protocol, get_slv_data(bus_in));
                    if number_of_registers_to_stream = 1 then
                        fpga_controlled_stream_requested <= false;
                    end if;
                end if;
            else
                if write_to_address_is_requested(bus_in, 0) then
                    respond_to_data_request(spi_protocol
                        , write_data_to_register(address => 0
                        , data => get_slv_data(bus_in))
                    );
                end if;
            end if;

        end if; -- rising_edge
    end process protocol;

------------------------------------------------------------------------
    u_spi_secondary : entity work.spi_secondary
    port map(
        main_clock                 => clock
        ,spi_fpga_in.spi_data_in   => spi_data_in
        ,spi_fpga_in.spi_clock     => spi_clock
        ,spi_fpga_in.spi_cs_in     => spi_cs_in
        ,spi_fpga_out.spi_data_out => spi_data_out
        ,spi_rx_out                => spi_rx_out
        ,spi_tx_in                 => spi_tx_in
        ,spi_tx_out                => spi_tx_out
    );

end rtl;
