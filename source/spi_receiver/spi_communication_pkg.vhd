library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.bit_operations_pkg.left_shift;

package spi_communication_pkg is

    type spi_receiver_record is record
        cs_buffer          : std_logic_vector(2 downto 0);
        spi_clock_buffer   : std_logic_vector(2 downto 0);
        input_data_buffer  : std_logic_vector(15 downto 0);
        output_data_buffer : std_logic_vector(15 downto 0);

        i                      : natural range 0 to 4;
        transmitted_data_index : natural range 0 to 15;
        received_byte_index    : natural range 0 to 15;
        byte_is_ready          : boolean;
        received_byte          : std_logic_vector(7 downto 0);
    end record;

    constant init_spi_receiver : spi_receiver_record := (
        (others => '0'), (others => '0'), (others => '0'), (others => '0'), 0, 0, 0, false, (others => '0'));

    procedure create_spi_receiver (
        signal self         : inout spi_receiver_record;
        spi_cs              : in std_logic;
        spi_clock           : in std_logic;
        spi_data_in         : in std_logic;
        signal spi_data_out : out std_logic;
        frame_out_of_spi    : in std_logic_vector(15 downto 0));

-------------------------------------------
   function rising_edge_detected ( signal_buffer : std_logic_vector )
       return boolean;
-------------------------------------------
   function falling_edge_detected ( signal_buffer : std_logic_vector )
       return boolean;
-------------------------------------------
   function get_first_bit ( input : std_logic_vector)
       return std_logic;
-------------------------------------------
   function byte_received ( self : spi_receiver_record)
       return boolean;
-------------------------------------------
   function get_received_byte ( self : spi_receiver_record)
       return std_logic_vector;
-------------------------------------------

end package spi_communication_pkg;

package body spi_communication_pkg is

    procedure create_spi_receiver
    (
        signal self         : inout spi_receiver_record;
        spi_cs              : in std_logic;
        spi_clock           : in std_logic;
        spi_data_in         : in std_logic;
        signal spi_data_out : out std_logic;
        frame_out_of_spi    : in std_logic_vector(15 downto 0)
    ) is
    begin
        self.spi_clock_buffer <= self.spi_clock_buffer(self.spi_clock_buffer'left-1 downto 0) & spi_clock;
        self.cs_buffer        <= self.cs_buffer(self.cs_buffer'left-1 downto 0) & spi_cs;

        if falling_edge_detected(self.cs_buffer) then
            self.transmitted_data_index <= 1;
            self.received_byte_index    <= 0;
            self.output_data_buffer     <= frame_out_of_spi(frame_out_of_spi'left-1 downto 0) & '0';
            spi_data_out                <= get_first_bit(std_logic_vector(frame_out_of_spi));
        end if;

        self.byte_is_ready <=false;
        if falling_edge_detected(self.spi_clock_buffer) then
            if self.transmitted_data_index < 8 then
                self.transmitted_data_index <= self.transmitted_data_index + 1;
            else
                self.transmitted_data_index <= 0;
                self.received_byte_index <= self.received_byte_index + 1;
                self.byte_is_ready <=true;
                self.received_byte <= self.output_data_buffer(6 downto 0) & '0';
            end if;
            self.output_data_buffer <= self.output_data_buffer(self.output_data_buffer'left-1 downto 0) & '0';
            spi_data_out       <= get_first_bit(self.output_data_buffer);
        end if;

        if rising_edge_detected(self.spi_clock_buffer) then
            left_shift(self.input_data_buffer, spi_data_in);
        end if;
        
    end create_spi_receiver;

-------------------------------------------
   function rising_edge_detected
   (
       signal_buffer : std_logic_vector 
   )
   return boolean
   is
   begin
       return signal_buffer(signal_buffer'left downto signal_buffer'left-1) = "01";
   end rising_edge_detected; 

-------------------------------------------
   function falling_edge_detected
   (
       signal_buffer : std_logic_vector 
   )
   return boolean
   is
   begin
       return signal_buffer(signal_buffer'left downto signal_buffer'left-1) = "10";
   end falling_edge_detected; 

-------------------------------------------
   function get_first_bit
   (
       input : std_logic_vector
   )
   return std_logic
   is
   begin
       return input(input'left);
       
   end get_first_bit;
-------------------------------------------
   function byte_received
   (
       self : spi_receiver_record
   )
   return boolean
   is
   begin
       return self.byte_is_ready;
   end byte_received;
-------------------------------------------
   function get_received_byte
   (
       self : spi_receiver_record
   )
   return std_logic_vector
   is
   begin
       return self.received_byte;
   end get_received_byte;
-------------------------------------------

end package body spi_communication_pkg;
