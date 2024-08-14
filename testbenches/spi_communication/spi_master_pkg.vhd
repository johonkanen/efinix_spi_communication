library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package spi_master_pkg is

    package clock_divider_pkg is new work.clock_divider_generic_pkg 
        generic map(g_count_max => 11);
    use clock_divider_pkg.all;

    subtype byte is std_logic_vector(7 downto 0);
    type bytearray is array (natural range <>) of byte;

    type spi_master_record is record
        clock_divider           : clock_divider_record;
        number_of_bytes_to_send : natural;
        spi_clock               : std_logic;
        spi_cs_in               : std_logic;
        spi_data_from_master    : std_logic;
        output_buffer           : byte;
        output_shift_register   : std_logic_vector(15 downto 0);
    end record;

    constant init_spi_master : spi_master_record := (init_clock_divider, 0, '0', '1', '1', (others => '0'),(others => '0'));

-------------------------------------------------
    procedure create_spi_master (
        signal self : inout spi_master_record;
        spi_data_slave_to_master : in std_logic);
-------------------------------------------------
    procedure transmit_number_of_bytes (
        signal self : inout spi_master_record;
        number_of_bytes_to_send : natural);
-------------------------------------------------
    procedure load_transmit_register (
        signal self : inout spi_master_record;
        word_to_be_sent : std_logic_vector);
-------------------------------------------------
    function ready_to_receive_packet ( self : spi_master_record)
        return boolean;
-------------------------------------------------

end package spi_master_pkg;

package body spi_master_pkg is

-------------------------------------------------
    procedure create_spi_master
    (
        signal self : inout spi_master_record;
        spi_data_slave_to_master : in std_logic
    ) is
    begin
        create_clock_divider(self.clock_divider);
        if clock_divider_is_ready(self.clock_divider) then
            self.spi_cs_in <= '1';
        end if;

        self.spi_clock <= get_clock_from_divider(self.clock_divider);
        if get_clock_counter(self.clock_divider) = 0 then
            self.spi_data_from_master <= self.output_shift_register(self.output_shift_register'left);
            self.output_shift_register <= self.output_shift_register(self.output_shift_register'left-1 downto 0) & '0';
        end if;
        
    end create_spi_master;

-------------------------------------------------
    procedure transmit_number_of_bytes
    (
        signal self : inout spi_master_record;
        number_of_bytes_to_send : natural
    ) is
    begin
        request_number_of_clock_pulses(self.clock_divider, number_of_bytes_to_send*8);
        self.number_of_bytes_to_send <= number_of_bytes_to_send;
        self.spi_cs_in <= '0';
        
    end transmit_number_of_bytes;

-------------------------------------------------
    procedure load_transmit_register
    (
        signal self : inout spi_master_record;
        word_to_be_sent : std_logic_vector
    ) is
    begin
        for i in word_to_be_sent'range loop
            self.output_shift_register(self.output_shift_register'left-i) <= word_to_be_sent(i);
        end loop;
        /* self.output_shift_register <= word_to_be_sent; */
    end load_transmit_register;

-------------------------------------------------
    function ready_to_receive_packet
    (
        self : spi_master_record
    )
    return boolean
    is
    begin
        return false;
    end ready_to_receive_packet;
-------------------------------------------------
end package body spi_master_pkg;
