use work.spi_secondary_pkg.all;

package uart_protocol_pkg is new work.serial_protocol_generic_pkg
    generic map(serial_rx_data_output_record => spi_rx_out_record,
                serial_tx_data_input_record  => spi_tx_in_record,
                serial_tx_data_output_record => spi_tx_out_record,
                --------------------------------
                serial_rx_data_is_ready => spi_rx_data_is_ready,
                --------------------------------
                get_serial_rx_data => get_spi_rx_data,
                --------------------------------
                init_uart => init_spi,
                --------------------------------
                transmit_8bit_data_package => transmit_8bit_data_package,
                --------------------------------
                serial_tx_is_ready => spi_tx_is_ready);
