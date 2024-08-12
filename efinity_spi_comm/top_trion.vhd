library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


entity top is
    port (
        main_clock      : in std_logic;
        spi_data_in     : in std_logic;
        spi_clock       : in std_logic;
        spi_cs_in       : in std_logic;
        spi_data_out    : out std_logic
    );
end entity top;


architecture rtl of top is

    signal spi_clock_buffer : std_logic_vector(2 downto 0);

begin

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
                spi_data_out <= spi_data_in;
            end if;

        end if; --rising_edge
    end process test_spi;	


end rtl;
