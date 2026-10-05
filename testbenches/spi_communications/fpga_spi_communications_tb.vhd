LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

-- drives fpga_spi_communications with 32 bit data and 16 bit addresses from
-- a behavioural spi primary (mode 0, msb first, chip select low for a whole
-- exchange), the way a pc does with an ftdi mpsse : a command followed by
-- zero padding, the response read from the bytes clocked back. registers :
--   1 : 0x0000acdc, read only
--   3 : read / write
--   4 : read counter, +1 on every read
entity fpga_spi_communications_tb is
  generic (
      runner_cfg : string
      -- main clocks per spi clock half period
      ;g_spi_half_period : positive := 4
  );
end;

architecture vunit_simulation of fpga_spi_communications_tb is

    package fpga_interconnect_pkg is new work.fpga_interconnect_generic_pkg
        generic map(number_of_data_bits    => 32,
                    number_of_address_bits => 16);
    use fpga_interconnect_pkg.all;

    constant clock_period : time := 1 ns;
    constant spi_half     : time := g_spi_half_period * clock_period;

    signal clock        : std_logic := '0';
    signal spi_clock    : std_logic := '0';
    signal spi_cs_in    : std_logic := '1';
    signal spi_data_in  : std_logic := '0';
    signal spi_data_out : std_logic;

    signal bus_to_communications   : fpga_interconnect_record := init_fpga_interconnect;
    signal bus_from_communications : fpga_interconnect_record := init_fpga_interconnect;

    signal read_write_register : std_logic_vector(31 downto 0) := (others => '0');
    signal read_counter        : unsigned(31 downto 0) := (others => '0');

    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
    type word_array is array (natural range <>) of std_logic_vector(31 downto 0);

begin

    clock <= not clock after clock_period/2.0;

------------------------------------------------------------------------
    stimulus : process

        -- one chip select low exchange, mode 0 : data out is set while the
        -- clock is low, data in is sampled just before the rising edge
        procedure exchange (tx : byte_array; rx : out byte_array) is
            variable byte : std_logic_vector(7 downto 0);
        begin
            spi_cs_in <= '0';
            wait for spi_half;
            for i in tx'range loop
                for b in 7 downto 0 loop
                    spi_data_in <= tx(i)(b);
                    wait for spi_half;
                    byte(b)   := spi_data_out;
                    spi_clock <= '1';
                    wait for spi_half;
                    spi_clock <= '0';
                end loop;
                rx(i) := byte;
            end loop;
            wait for spi_half;
            spi_cs_in <= '1';
            wait for 4*spi_half;
        end exchange;

        function address_bytes (address : natural) return byte_array is
            constant a : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(address, 16));
        begin
            return (a(15 downto 8), a(7 downto 0));
        end address_bytes;

        function zeros (count : natural) return byte_array is
        begin
            return (0 to count-1 => x"00");
        end zeros;

        function word (rx : byte_array; first : natural) return std_logic_vector is
        begin
            return rx(first) & rx(first+1) & rx(first+2) & rx(first+3);
        end word;

        procedure write_register (address : natural; data : std_logic_vector(31 downto 0)) is
            constant tx : byte_array := byte_array'(0 => x"04") & address_bytes(address)
                & byte_array'(data(31 downto 24), data(23 downto 16), data(15 downto 8), data(7 downto 0));
            variable rx : byte_array(tx'range);
        begin
            exchange(tx, rx);
        end write_register;

        -- the response is a 7 byte frame (header, address, data), found by its
        -- nonzero header after the first byte out (0xff) ; latency is where
        -- it starts after the end of the command
        procedure read_register (address : natural; data : out std_logic_vector(31 downto 0); latency : out natural) is
            constant command : byte_array := byte_array'(0 => x"02") & address_bytes(address);
            constant tx      : byte_array := command & zeros(24);
            variable rx      : byte_array(tx'range);
            variable first   : integer := -1;
        begin
            exchange(tx, rx);
            for i in 1 to rx'high loop
                if rx(i) /= x"00" then
                    first := i;
                    exit;
                end if;
            end loop;
            check(first >= 0 and first + 6 <= rx'high, "no response to the read of register " & integer'image(address));
            data    := word(rx, first + 3);
            latency := first - command'length;
        end read_register;

        procedure check_register (address : natural; expected : std_logic_vector(31 downto 0)) is
            variable data    : std_logic_vector(31 downto 0);
            variable latency : natural;
        begin
            read_register(address, data, latency);
            check_equal(data, expected, "register " & integer'image(address));
        end check_register;

        -- a stream of count words of one address, the data words follow the
        -- command after the same latency as a read response's header
        procedure stream (address : natural; count : natural; latency : natural; words : out word_array) is
            constant c       : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(count, 24));
            constant command : byte_array := byte_array'(0 => x"05") & address_bytes(address)
                & byte_array'(c(23 downto 16), c(15 downto 8), c(7 downto 0));
            constant tx      : byte_array := command & zeros(latency + 4*count + 4);
            variable rx      : byte_array(tx'range);
        begin
            exchange(tx, rx);
            for k in 0 to count-1 loop
                words(k) := word(rx, command'length + latency + 4*k);
            end loop;
        end stream;

        variable data, data2 : std_logic_vector(31 downto 0);
        variable latency     : natural;
        variable words       : word_array(0 to 7);

    begin
        test_runner_setup(runner, runner_cfg);
        wait for 20*clock_period;

        check_register(1, x"0000acdc");

        write_register(3, x"deadbeef");
        check_register(3, x"deadbeef");
        write_register(3, x"12345678");
        read_register(3, data, latency);
        check_equal(data, std_logic_vector'(x"12345678"), "register 3 after the second write");
        info("read response header " & integer'image(latency) & " bytes after the command");

        read_register(4, data, latency);
        read_register(4, data2, latency);
        check_equal(unsigned(data2), unsigned(data) + 1, "read counter did not count");

        stream(3, 8, latency, words);
        for k in 0 to 7 loop
            check_equal(words(k), std_logic_vector'(x"12345678"), "stream word " & integer'image(k) & " of register 3");
        end loop;

        stream(4, 8, latency, words);
        for k in 1 to 7 loop
            check_equal(unsigned(words(k)), unsigned(words(k-1)) + 1, "stream word " & integer'image(k) & " of the read counter");
        end loop;

        check_register(1, x"0000acdc");

        test_runner_cleanup(runner);
        wait;
    end process stimulus;

    test_runner_watchdog(runner, 1 ms);

------------------------------------------------------------------------
    registers : process(clock)
    begin
        if rising_edge(clock) then
            init_bus(bus_to_communications);
            connect_read_only_data_to_address(bus_from_communications, bus_to_communications, 1, x"0000acdc");
            connect_data_to_address(bus_from_communications, bus_to_communications, 3, read_write_register);
            connect_read_only_data_to_address(bus_from_communications, bus_to_communications, 4, std_logic_vector(read_counter));
            if data_is_requested_from_address(bus_from_communications, 4) then
                read_counter <= read_counter + 1;
            end if;
        end if;
    end process registers;

    u_fpga_spi_communications : entity work.fpga_spi_communications
    generic map(fpga_interconnect_pkg => fpga_interconnect_pkg)
    port map(
        clock                    => clock
        ,spi_clock               => spi_clock
        ,spi_cs_in               => spi_cs_in
        ,spi_data_in             => spi_data_in
        ,spi_data_out            => spi_data_out
        ,bus_to_communications   => bus_to_communications
        ,bus_from_communications => bus_from_communications
    );

end vunit_simulation;
