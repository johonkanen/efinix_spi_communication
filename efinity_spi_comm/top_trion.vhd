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

    signal cs_buffer : std_logic_vector(2 downto 0);
    signal spi_clock_buffer : std_logic_vector(2 downto 0);
    signal input_data_buffer : std_logic_vector(15 downto 0) := x"5555";
    signal ledstate : std_logic_vector(3 downto 0) := "0101";
    signal output_data_buffer : std_logic_vector(15 downto 0) := x"acdc";

    constant testi : std_logic_vector(15 downto 0) := x"acdc";

    type std15array is array (integer range 0 to 4) of std_logic_vector(15 downto 0);
    constant output_data : std15array :=(x"acdc", x"bdca", x"acab", x"ffff", x"1234");
    signal i : natural range output_data'range := 0;

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

       function falling_edge_detected
       (
           signal_buffer : std_logic_vector 
       )
       return boolean
       is
       begin
           return signal_buffer(signal_buffer'left downto signal_buffer'left-1) = "10";
       end falling_edge_detected; 
        
    begin
        if rising_edge(main_clock) then
            spi_clock_buffer <= spi_clock_buffer(spi_clock_buffer'left-1 downto 0) & spi_clock;
            cs_buffer        <= cs_buffer(cs_buffer'left-1 downto 0) & spi_cs_in;


            if falling_edge_detected(cs_buffer) then
                if i < output_data'high then
                    i <= i + 1;
                else
                    i <= 0;
                end if;
                output_data_buffer <= output_data(i);
            end if;

            if rising_edge_detected(spi_clock_buffer) then
                output_data_buffer <= '0' & output_data_buffer(output_data_buffer'left downto 1);
                spi_data_out       <= output_data_buffer(0);
                input_data_buffer  <= input_data_buffer(input_data_buffer'left-1 downto 0) & spi_data_in ;
            end if;

            if rising_edge_detected(cs_buffer) then
                if input_data_buffer = x"acdc" then
                    ledstate <= (others => '1');
                else
                    ledstate <= (others => '0');
                end if;
            end if;
            /* ledstate <= input_data_buffer(15 downto 12); */

        end if; --rising_edge
    end process test_spi;	

end rtl;
