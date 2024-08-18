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

    type spi_input_record is record
        data : std_logic;
    end record;

    type spi_output_record is record
        received_byte : std_logic_vector(7 downto 0);
        byte_is_ready_when_1 : boolean;
    end record;

end package spi_secondary_pkg;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.spi_secondary_pkg.all;

entity spi_secondary is
    port (
        main_clock   : in std_logic;
        spi_fpga_in  : in spi_fpga_input_record;
        spi_fpga_out : out spi_fpga_output_record
    );
end entity spi_secondary;

architecture rtl of spi_secondary is

    use work.spi_communication_pkg.all;
    use work.bit_operations_pkg.all;

    signal test_register : std_logic_vector(15 downto 0) := x"acdc";
    signal testidata : unsigned(15 downto 0) := (15 => '1', 9 => '1', 8 => '1', others => '1');
    signal self : spi_receiver_record := init_spi_receiver;

begin

    spi_receiver : process(main_clock)
        
    begin
        if rising_edge(main_clock) then
            create_spi_receiver(self , spi_fpga_in  .spi_cs_in , spi_fpga_in.spi_clock , spi_fpga_in.spi_data_in , spi_fpga_out.spi_data_out , std_logic_vector(testidata));
        end if; --rising_edge
    end process spi_receiver;	

end rtl;
--------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.fpga_interconnect_pkg.all;
    use work.spi_communication_pkg.all;
    use work.bit_operations_pkg.all;

    use work.spi_secondary_pkg.all;

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

    signal ledstate : std_logic_vector(3 downto 0) := "1111";
    constant testi  : std_logic_vector(15 downto 0) := x"acdc";

    signal testidata : unsigned(15 downto 0) := (15 => '1', 9 => '1', 8 => '1', others => '1');

    type std15array is array (integer range 0 to 4) of std_logic_vector(15 downto 0);
    constant output_data : std15array :=(x"acdc", x"aaaa", x"5555", x"ffff", x"1234");

    signal self : spi_receiver_record := init_spi_receiver;
    signal bus_from_main : fpga_interconnect_record := init_fpga_interconnect;
    signal bus_from_test : fpga_interconnect_record := init_fpga_interconnect;

    signal bus_to_main : fpga_interconnect_record := init_fpga_interconnect;
    signal test_register : std_logic_vector(15 downto 0) := x"acdc";
    signal dummy_spi_data_out : std_logic;

begin

    user_led <= ledstate;

------------------------------------------
    main : process(main_clock)
    begin
        if rising_edge(main_clock) then
            init_bus(bus_from_main);

            if falling_edge_detected(self.cs_buffer) then
                testidata <= testidata + 3;
            end if;

            create_spi_receiver(self, spi_cs_in, spi_clock, spi_data_in, spi_data_out, std_logic_vector(testidata));

            if rising_edge_detected(self.cs_buffer) then
                CASE self.input_data_buffer is
                    WHEN x"acdc" =>
                        ledstate <= (others => '1');
                        request_data_from_address(bus_from_main, 10);
                    WHEN others =>
                        ledstate <= (others => '0');
                end CASE;
            end if;

        end if; --rising_edge
    end process main;
------------------------------------------
    test : process(main_clock)
    begin
        if rising_edge(main_clock) then
            bus_to_main <= bus_from_test;
        end if; --rising_edge
    end process test;	
------------------------------------------
    test_interconnect : process(main_clock)
    begin
        if rising_edge(main_clock) then
            init_bus(bus_from_test);
            connect_data_to_address(bus_from_main, bus_from_test, 10, test_register);
        end if; --rising_edge
    end process test_interconnect;	
------------------------------------------
    u_spi_secondary : entity work.spi_secondary
    port map(
        main_clock                               ,
        spi_fpga_in.spi_data_in   => spi_data_in ,
        spi_fpga_in.spi_clock     => spi_clock   ,
        spi_fpga_in.spi_cs_in     => spi_cs_in   ,
        spi_fpga_out.spi_data_out => dummy_spi_data_out);
------------------------------------------
end rtl;
