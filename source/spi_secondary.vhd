library ieee;
    use ieee.std_logic_1164.all;

package spi_secondary_pkg is

    type spi_fpga_input_record is record
        spi_data_in     : std_logic;
        spi_clock       : std_logic;
        spi_cs_in       : std_logic;
    end record;

    type spi_fpga_output_record is record
        spi_data_out : std_logic;
    end record;

    type spi_tx_in_record is record
        data_send_is_requested      : boolean;
        data_to_be_sent_through_spi : std_logic_vector(7 downto 0);
    end record;

    type spi_tx_out_record is record
        byte_is_transmitted : boolean;
    end record;

    type spi_rx_out_record is record
        received_byte_is_ready : boolean;
        received_byte : std_logic_vector(7 downto 0);
    end record;

---------------------------------------------------
    procedure init_spi (
        signal self_tx_in : out spi_tx_in_record);
---------------------------------------------------
    function spi_rx_data_is_ready ( self_rx_out : spi_rx_out_record)
        return boolean;
---------------------------------------------------
    function get_spi_rx_data ( self_rx_out : spi_rx_out_record)
        return std_logic_vector;
---------------------------------------------------
    procedure transmit_8bit_data_package (
        signal self_tx_in : out spi_tx_in_record;
        data_to_be_sent_through_spi : in std_logic_vector(7 downto 0));
---------------------------------------------------
    function spi_tx_is_ready ( self : spi_tx_out_record)
        return boolean;
---------------------------------------------------

end package spi_secondary_pkg;

package body spi_secondary_pkg is

---------------------------------------------------
    function spi_rx_data_is_ready
    (
        self_rx_out : spi_rx_out_record
    )
    return boolean
    is
    begin
        return self_rx_out.received_byte_is_ready;
    end spi_rx_data_is_ready;

---------------------------------------------------
    function get_spi_rx_data
    (
        self_rx_out : spi_rx_out_record
    )
    return std_logic_vector 
    is
    begin
        return self_rx_out.received_byte;
    end get_spi_rx_data;

---------------------------------------------------
    procedure init_spi
    (
        signal self_tx_in : out spi_tx_in_record
    ) is
    begin
        self_tx_in.data_send_is_requested      <= false;
        self_tx_in.data_to_be_sent_through_spi <= (others => '0');
    end init_spi;

---------------------------------------------------
    procedure transmit_8bit_data_package
    (
        signal self_tx_in : out spi_tx_in_record;
        data_to_be_sent_through_spi : in std_logic_vector(7 downto 0)
    ) is
    begin
        
        self_tx_in.data_send_is_requested      <= true;
        self_tx_in.data_to_be_sent_through_spi <= data_to_be_sent_through_spi;
    end transmit_8bit_data_package;

---------------------------------------------------
    function spi_tx_is_ready
    (
        self : spi_tx_out_record
    )
    return boolean
    is
    begin

        return self.byte_is_transmitted;
        
    end spi_tx_is_ready;
---------------------------------------------------
end package body spi_secondary_pkg;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.spi_secondary_pkg.all;

entity spi_secondary is
    port (
        main_clock   : in std_logic;
        spi_fpga_in  : in spi_fpga_input_record;
        spi_fpga_out : out spi_fpga_output_record;
        spi_rx_out   : out spi_rx_out_record;
        spi_tx_in    : in spi_tx_in_record;
        spi_tx_out   : out spi_tx_out_record
    );
end entity spi_secondary;

architecture rtl of spi_secondary is

    use work.spi_communication_pkg.all;
    use work.bit_operations_pkg.all;

    signal test_register : std_logic_vector(15 downto 0) := x"acdc";
    signal testidata : unsigned(15 downto 0) := (15 => '1', 9 => '1', 8 => '1', others => '1');
    signal self : spi_receiver_record := init_spi_receiver;

begin

    spi_rx_out <= (received_byte_is_ready => byte_received(self),
                   received_byte          => get_received_byte(self));

    spi_receiver : process(main_clock)
        
    begin
        if rising_edge(main_clock) then
            create_spi_receiver(self , spi_fpga_in.spi_cs_in , spi_fpga_in.spi_clock , spi_fpga_in.spi_data_in , spi_fpga_out.spi_data_out , std_logic_vector(testidata));
        end if; --rising_edge
    end process spi_receiver;	

end rtl;
--------------------------------------------------
