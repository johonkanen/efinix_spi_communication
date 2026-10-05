library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package serial_protocol_generic_pkg is
    generic (type serial_rx_data_output_record
              ; type serial_tx_data_input_record
              ; type serial_tx_data_output_record
             --------------------------------
              ; function serial_rx_data_is_ready(self : serial_rx_data_output_record) return boolean is <>
              ; function get_serial_rx_data(self : serial_rx_data_output_record) return std_logic_vector is <>
              ; procedure init_serial(signal self : out serial_tx_data_input_record) is <>
              ; procedure transmit_8bit_data_package(signal self : out serial_tx_data_input_record ; input : std_logic_vector) is <>
              ; function serial_tx_is_ready(self : serial_tx_data_output_record) return boolean is <>
             --------------------------------
           ; constant g_data_bit_width    : natural
           ; constant g_address_bit_width : natural
         );

    constant read_is_requested_from_address_from_serial : integer := 2;
    constant write_to_address_is_requested_from_serial  : integer := 4;
    constant stream_data_from_address                   : integer := 5;
    constant request_stream_from_address                : integer := 6;

    constant number_of_address_bytes : natural := g_address_bit_width/8;
    constant number_of_data_bytes    : natural := g_data_bit_width/8;

    type base_array is array (natural range <>) of std_logic_vector(7 downto 0);
    constant bufferlength : natural := 8;
    subtype memory_array is base_array(0 to bufferlength-1);

    type serial_communcation_record is record
        number_of_transmitted_words : integer range 0 to bufferlength-1;
        transmit_buffer             : memory_array;
        is_ready                    : boolean;
        is_requested                : boolean;
        ------------------------------
        receive_buffer           : memory_array;
        receive_address          : integer range 0 to bufferlength-1;
        number_of_received_words : integer range 0 to bufferlength-1;
        receive_is_ready         : boolean;
        receive_timeout          : integer range 0 to 2**16-1;
    end record;

    constant init_serial_communcation : serial_communcation_record := (0, (others => x"00"), false, false, (others => x"00"), 0,0, false, 0);

------------------------------------------------------------------------
    procedure create_serial_protocol (
        signal self         : inout serial_communcation_record;
        serial_rx           : in serial_rx_data_output_record;
        signal serial_tx_in : out serial_tx_data_input_record;
        serial_tx_out       : in serial_tx_data_output_record);
------------------------------------------------------------------------
    procedure transmit_words_with_serial (
        signal self : out serial_communcation_record;
        data_words_in : base_array );

------------------------------------------------------------------------
    procedure respond_to_data_request (
        signal self : out serial_communcation_record;
        data_words_in : base_array );

------------------------------------------------------------------------
    function frame_has_been_received ( self : serial_communcation_record)
        return boolean;

------------------------------------------------------------------------
    procedure send_stream_data_packet (
        signal self : out serial_communcation_record;
        data_words_in : base_array );
------------------------------------------------------------------------
    procedure send_stream_data_packet (
        signal self : out serial_communcation_record;
        data_in : std_logic_vector);
------------------------------------------------------------------------
    function transmit_is_ready ( self : serial_communcation_record)
        return boolean;
------------------------------------------------------------------------
    function write_data_to_register ( address : integer; data : std_logic_vector)
        return base_array;
------------------------------------------------------------------------
    function read_data_from_register ( address : integer)
        return base_array;
------------------------------------------------------------------------
    function get_number_of_registers_to_stream (self : serial_communcation_record)
        return integer;
------------------------------------------------------------------------
    function get_command ( self : serial_communcation_record)
        return integer;
------------------------------------------------------------------------
    function get_command_address ( self : serial_communcation_record)
        return integer;
------------------------------------------------------------------------
    function get_command_data ( self : serial_communcation_record)
        return std_logic_vector;
------------------------------------------------------------------------
    function int24_to_bytes ( number : integer)
        return base_array;
------------------------------------------------------------------------
    function int_to_bytes ( number : integer)
        return base_array;
------------------------------------------------------------------------

end package serial_protocol_generic_pkg;

package body serial_protocol_generic_pkg is

------------------------------------------------------------------------
    function get_serial_rx_data
    (
        self_rx_in : serial_rx_data_output_record
    )
    return natural
    is
    begin
        
        return to_integer(unsigned(std_logic_vector'(get_serial_rx_data(self_rx_in))));
    end get_serial_rx_data;
------------------------------------------------------------------------
    procedure create_serial_protocol
    (
        signal self         : inout serial_communcation_record;
        serial_rx           : in serial_rx_data_output_record;
        signal serial_tx_in : out serial_tx_data_input_record;
        serial_tx_out       : in serial_tx_data_output_record
    ) is
        variable serial_protocol_header : integer;
    begin
        init_serial(serial_tx_in);
        
        self.is_ready <= false;
        self.is_requested <= false;

        if self.number_of_transmitted_words > 0 then
            if serial_tx_is_ready(serial_tx_out) or self.is_requested then
                transmit_8bit_data_package(serial_tx_in, self.transmit_buffer(0));
                self.transmit_buffer <= self.transmit_buffer(1 to self.transmit_buffer'high) & x"00";
                self.number_of_transmitted_words <= self.number_of_transmitted_words - 1;
            end if;
        else
            if serial_tx_is_ready(serial_tx_out) then
                self.is_ready <= true;
            end if;
        end if;

        --------------------------------------------------
        self.receive_is_ready <= false;

        if self.receive_timeout > 0 then
            self.receive_timeout <= self.receive_timeout - 1;
        end if;

        if self.receive_timeout = 1 then
            self.number_of_received_words <= 0;
            self.receive_address <= 0;
        end if;

        if serial_rx_data_is_ready(serial_rx) then
            self.receive_timeout <= 65535;
            self.receive_buffer(self.receive_address) <= get_serial_rx_data(serial_rx);
            self.receive_address <= (self.receive_address + 1) mod 8;

            if self.number_of_received_words > 0 then
                self.number_of_received_words <= self.number_of_received_words - 1;
            else
                serial_protocol_header := get_serial_rx_data(serial_rx);
                CASE serial_protocol_header is
                    WHEN read_is_requested_from_address_from_serial => self.number_of_received_words <= g_address_bit_width/8;
                    WHEN write_to_address_is_requested_from_serial  => self.number_of_received_words <= g_address_bit_width/8 + g_data_bit_width/8;
                    WHEN stream_data_from_address                   => self.number_of_received_words <= g_address_bit_width/8 + 3;
                    WHEN request_stream_from_address                => self.number_of_received_words <= g_address_bit_width/8 + 3;
                    WHEN others => self.number_of_received_words <= get_serial_rx_data(serial_rx) mod 8;
                        -- a header without payload, like padding zeros, is dropped so that the next frame starts from address 0
                        if get_serial_rx_data(serial_rx) mod 8 = 0 then
                            self.receive_address <= 0;
                        end if;
                end CASE;
            end if;

            if self.number_of_received_words = 1 then
                self.receive_is_ready <= true;
                self.receive_timeout <= 0;
                self.receive_address <= 0;
            end if;
        end if;
        
    end create_serial_protocol;

------------------------------------------------------------------------
    procedure transmit_words_with_serial
    (
        signal self : out serial_communcation_record;
        data_words_in : base_array 
    ) is
    begin
        self.number_of_transmitted_words <= data_words_in'length;
        for i in 0 to data_words_in'high loop
            self.transmit_buffer(i) <= data_words_in(i);
        end loop;
        self.is_requested <= true;
        
    end transmit_words_with_serial;

    procedure respond_to_data_request
    (
        signal self : out serial_communcation_record;
        data_words_in : base_array 
    ) is
    begin
        self.number_of_transmitted_words <= data_words_in'length+1;

        self.transmit_buffer(0) <= std_logic_vector(to_unsigned(data_words_in'length, 8));
        for i in 1 to data_words_in'high+1 loop
            self.transmit_buffer(i) <= data_words_in(i-1);
        end loop;

        self.is_requested <= true;
    end respond_to_data_request;
        
------------------------------------------------------------------------
    procedure send_stream_data_packet
    (
        signal self : out serial_communcation_record;
        data_words_in : base_array 
    ) is
    begin
        self.number_of_transmitted_words <= data_words_in'length;

        for i in data_words_in'high downto 0 loop
            self.transmit_buffer(i) <= data_words_in(i);
        end loop;
        self.is_requested <= true;
        
    end send_stream_data_packet;

------------------------------------------------------------------------
------------------------------------------------------------------------
    function frame_has_been_received
    (
        self : serial_communcation_record
    )
    return boolean
    is
    begin
        return self.receive_is_ready;
    end frame_has_been_received;
------------------------------------------------------------------------
------------------------------------------------------------------------
    function int_to_bytes
    (
        number : integer
    )
    return base_array 
    is
        variable uint_number : unsigned(15 downto 0);
        variable return_value : base_array(0 to 1);
    begin
        uint_number := to_unsigned(number,16);
        return_value := (std_logic_vector(uint_number(15 downto 8)) , std_logic_vector(uint_number(7 downto 0)));
        return return_value;
    end int_to_bytes;
--------------------------------------------------
    function bytes_to_int
    (
        data : base_array
    )
    return integer
    is
    begin
        return to_integer(unsigned(data(data'left)) & unsigned(data(data'left + 1)));
    end bytes_to_int;
--------------------------------------------------
    function int24_to_bytes
    (
        number : integer
    )
    return base_array 
    is
        variable uint_number : unsigned(23 downto 0);
        variable return_value : base_array(0 to 2);
    begin
        uint_number := to_unsigned(number,24);
        return_value := (std_logic_vector(uint_number(23 downto 16)) ,std_logic_vector(uint_number(15 downto 8)) , std_logic_vector(uint_number(7 downto 0)));
        return return_value;
    end int24_to_bytes;
------------------------------------------------------------------------
------------------------------------------------------------------------
    function write_data_to_register
    (
        address : integer;
        data : std_logic_vector
    )
    return base_array
    is
        variable retval : base_array(0 to g_address_bit_width/8 + g_data_bit_width/8-1);
        constant written_data : unsigned(g_address_bit_width + g_data_bit_width-1 downto 0)
            := to_unsigned(address, g_address_bit_width) & unsigned(data);
    begin

        for i in written_data'high downto 0 loop
            retval(retval'high - i/8)(i mod 8) := written_data(i);
        end loop;

        return retval;
    end write_data_to_register;
------------------------------------------------------------------------
    function read_data_from_register
    (
        address : integer
    )
    return base_array
    is
    begin
        return int_to_bytes(address);
    end read_data_from_register;
------------------------------------------------------------------------
    function get_command
    (
        self : serial_communcation_record
    )
    return integer
    is
    begin
        return to_integer(unsigned(self.receive_buffer(0)));
    end get_command;
------------------------------------------------------------------------
    function get_command_address
    (
        self : serial_communcation_record
    )
    return integer
    is
    begin
        return bytes_to_int(self.receive_buffer(1 to 2));
    end get_command_address;
------------------------------------------------------------------------
    function get_command_data
    (
        self : serial_communcation_record
    )
    return std_logic_vector
    is
        variable retval : std_logic_vector(g_data_bit_width-1 downto 0);
        constant offset : natural := 1+ number_of_address_bytes;
    begin

        for i in offset to offset+number_of_data_bytes-1 loop
            for j in 0 to 7 loop
                retval(retval'left-8*(i-offset) downto retval'length-8*(i-offset+1)) := self.receive_buffer(i);
            end loop;
        end loop;

        return retval;
    end get_command_data;
------------------------------------------------------------------------
    function get_number_of_registers_to_stream
    (
        self : serial_communcation_record
    )
    return integer
    is
        alias data is self.receive_buffer;
    begin
        return to_integer(unsigned(data(3)) & unsigned(data(4))& unsigned(data(5)));

    end get_number_of_registers_to_stream;
------------------------------------------------------------------------
    function transmit_is_ready
    (
        self : serial_communcation_record
    )
    return boolean
    is
    begin
        return self.is_ready;
    end transmit_is_ready;
------------------------------------------------------------------------
    procedure send_stream_data_packet
    (
        signal self : out serial_communcation_record;
        data_in : std_logic_vector
    ) is
        variable retval : base_array(0 to g_data_bit_width/8-1);
        constant written_data : unsigned(g_data_bit_width-1 downto 0)
            := unsigned(data_in);
    begin
        for i in written_data'high downto 0 loop
            retval(retval'high - i/8)(i mod 8) := written_data(i);
        end loop;
        send_stream_data_packet(self, retval);
        
    end send_stream_data_packet;
------------------------------------------------------------------------
end package body serial_protocol_generic_pkg;
