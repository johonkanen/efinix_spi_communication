library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

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

end package spi_communication_pkg;

package body spi_communication_pkg is

    procedure create_spi_receiver
    (
        signal self : inout spi_receiver_record;
        spi_cs : in std_logic;
        spi_clock : in std_logic;
        signal spi_data_out : out std_logic;
        frame_out_of_spi : in std_logic_vector(15 downto 0)
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
            spi_data_out       <= self.output_data_buffer(self.output_data_buffer'left);
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

end package body spi_communication_pkg;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.spi_communication_pkg.all;

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

    signal ledstate : std_logic_vector(3 downto 0) := "0101";
    constant testi  : std_logic_vector(15 downto 0) := x"acdc";

    signal testidata : unsigned(15 downto 0) := (15 => '1', 9 => '1', 8 => '1', others => '1');

    type std15array is array (integer range 0 to 4) of std_logic_vector(15 downto 0);
    constant output_data : std15array :=(x"acdc", x"aaaa", x"5555", x"ffff", x"1234");

    signal self : spi_receiver_record := init_spi_receiver;

begin

    user_led <= ledstate;

    test_spi : process(main_clock)
    begin
        if rising_edge(main_clock) then

            if falling_edge_detected(self.cs_buffer) then
                testidata <= testidata + 3;
            end if;

            create_spi_receiver(self, spi_cs_in, spi_clock, spi_data_out, std_logic_vector(testidata));

            if rising_edge_detected(self.spi_clock_buffer) then
                self.input_data_buffer  <= self.input_data_buffer(self.input_data_buffer'left-1 downto 0) & spi_data_in ;
            end if;

            if rising_edge_detected(self.cs_buffer) then
                if self.input_data_buffer = x"acdc" then
                    ledstate <= (others => '1');
                else
                    ledstate <= (others => '0');
                end if;
            end if;

        end if; --rising_edge
    end process test_spi;	

end rtl;
