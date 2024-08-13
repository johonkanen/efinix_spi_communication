library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.clock_divider_pkg.all;

package spi_master_pkg is

    subtype byte is std_logic_vector(7 downto 0);
    type bytearray is array (natural range <>) of byte;

    type spi_master_record is record
        clock_divider           : clock_divider_record;
        number_of_bytes_to_send : natural;
        spi_clock               : std_logic;
        spi_cs_in               : std_logic;
        spi_data_from_master    : std_logic;
        output_shift_register   : byte;
    end record;

    constant init_spi_master : spi_master_record := (init_clock_divider, 0, '0', '1', '1', (others => '0'));

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
        word_to_be_sent : byte);
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
        word_to_be_sent : byte
    ) is
    begin
        self.output_shift_register <= word_to_be_sent;
    end load_transmit_register;

end package body spi_master_pkg;
-------------------------------------------------

LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.clock_divider_pkg.all;
    use work.spi_master_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity spi_communication_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of spi_communication_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5000;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal spi_data_out : std_logic;

    signal user_led : std_logic_vector(3 downto 0);

    signal self : spi_master_record := init_spi_master;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            create_spi_master(self, spi_data_out);

            CASE simulation_counter is
                WHEN 5 => transmit_number_of_bytes(self,8);
                WHEN others => --do nothing
            end CASE;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    dut_top : entity work.top
    port map(
        main_clock      => simulator_clock           ,
        spi_data_in     => self.spi_data_from_master ,
        spi_clock       => self.spi_clock            ,
        spi_cs_in       => self.spi_cs_in            ,
        spi_data_out    => spi_data_out              ,
        user_led        => user_led
    );
------------------------------------------------------------------------

end vunit_simulation;
