library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


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

    signal spi_clock_buffer : std_logic_vector(2 downto 0);
    signal input_data_buffer : std_logic_vector(15 downto 0) := x"5555";
    signal ledstate : std_logic_vector(3 downto 0) := "0101";
    signal output_data_buffer : std_logic_vector(15 downto 0) := x"acdc";

begin

    user_led <= ledstate;

    test_spi : process(main_clock)

       function rising_edge_detected
       (
           signal_buffer : std_logic_vector 
       )
       return boolean
       is
       begin
           return signal_buffer(signal_buffer'left downto signal_buffer'left-1) = "01";
       end rising_edge_detected; 
        
    begin
        if rising_edge(main_clock) then
            spi_clock_buffer <= spi_clock_buffer(spi_clock_buffer'left-1 downto 0) & spi_clock;

            if rising_edge_detected(spi_clock_buffer) then
                output_data_buffer <= spi_data_in & output_data_buffer(output_data_buffer'left downto 1);
                spi_data_out       <= output_data_buffer(0);
                input_data_buffer  <= input_data_buffer(input_data_buffer'left-1 downto 0) & spi_data_in ;
            end if;

            if input_data_buffer = x"acdc" or input_data_buffer = x"abba" then
                ledstate <= (others => '1');
            end if;

            if input_data_buffer = x"abba" or output_data_buffer = x"acdc" then
                ledstate <= (others => '0');
            end if;
            ledstate <= input_data_buffer(3 downto 0);

        end if; --rising_edge
    end process test_spi;	

end rtl;
