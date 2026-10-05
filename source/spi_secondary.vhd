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

    type spi_tx_in_record is record
        data_send_is_requested      : boolean;
        data_to_be_sent_through_spi : std_logic_vector(7 downto 0);
    end record;

    type spi_tx_out_record is record
        byte_is_transmitted : boolean;
    end record;

    type spi_rx_out_record is record
        received_byte_is_ready : boolean;
        received_byte : std_logic_vector(7 downto 0);
    end record;

---------------------------------------------------
    procedure init_spi (
        signal self_tx_in : out spi_tx_in_record);
---------------------------------------------------
    function spi_rx_data_is_ready ( self_rx_out : spi_rx_out_record)
        return boolean;
---------------------------------------------------
    function get_spi_rx_data ( self_rx_out : spi_rx_out_record)
        return std_logic_vector;
---------------------------------------------------
    procedure transmit_8bit_data_package (
        signal self_tx_in : out spi_tx_in_record;
        data_to_be_sent_through_spi : in std_logic_vector(7 downto 0));
---------------------------------------------------
    function spi_tx_is_ready ( self : spi_tx_out_record)
        return boolean;
---------------------------------------------------

end package spi_secondary_pkg;

package body spi_secondary_pkg is

---------------------------------------------------
    function spi_rx_data_is_ready
    (
        self_rx_out : spi_rx_out_record
    )
    return boolean
    is
    begin
        return self_rx_out.received_byte_is_ready;
    end spi_rx_data_is_ready;

---------------------------------------------------
    function get_spi_rx_data
    (
        self_rx_out : spi_rx_out_record
    )
    return std_logic_vector 
    is
    begin
        return self_rx_out.received_byte;
    end get_spi_rx_data;

---------------------------------------------------
    procedure init_spi
    (
        signal self_tx_in : out spi_tx_in_record
    ) is
    begin
        self_tx_in.data_send_is_requested      <= false;
        self_tx_in.data_to_be_sent_through_spi <= (others => '0');
    end init_spi;

---------------------------------------------------
    procedure transmit_8bit_data_package
    (
        signal self_tx_in : out spi_tx_in_record;
        data_to_be_sent_through_spi : in std_logic_vector(7 downto 0)
    ) is
    begin
        
        self_tx_in.data_send_is_requested      <= true;
        self_tx_in.data_to_be_sent_through_spi <= data_to_be_sent_through_spi;
    end transmit_8bit_data_package;

---------------------------------------------------
    function spi_tx_is_ready
    (
        self : spi_tx_out_record
    )
    return boolean
    is
    begin

        return self.byte_is_transmitted;
        
    end spi_tx_is_ready;
---------------------------------------------------
end package body spi_secondary_pkg;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.spi_secondary_pkg.all;

entity spi_secondary is
    port (
        main_clock   : in std_logic;
        spi_fpga_in  : in spi_fpga_input_record;
        spi_fpga_out : out spi_fpga_output_record;
        spi_rx_out   : out spi_rx_out_record;
        spi_tx_in    : in spi_tx_in_record;
        spi_tx_out   : out spi_tx_out_record
    );
end entity spi_secondary;

architecture rtl of spi_secondary is

    -- The shift registers run directly from spi_clock, so the spi clock rate is not
    -- limited by oversampling with main_clock. A byte ends on the 8th rising edge,
    -- where the received byte is stored and the next byte to transmit is loaded.

    function to_gray(number : natural range 0 to 3) return std_logic_vector is
        constant binary : unsigned(1 downto 0) := to_unsigned(number, 2);
    begin
        return std_logic_vector(binary xor ('0' & binary(1)));
    end to_gray;

    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

    -- spi clock domain
    signal bit_counter        : natural range 0 to 7 := 0;
    signal rx_shift_register  : std_logic_vector(6 downto 0) := (others => '0');
    signal rx_byte            : std_logic_vector(7 downto 0) := (others => '0');
    signal byte_toggle        : std_logic := '0';
    signal tx_shift_register  : std_logic_vector(7 downto 0) := (others => '1');
    signal tx_fifo_read_index : natural range 0 to 3 := 0;

    -- main clock domain
    signal byte_toggle_sync       : std_logic_vector(2 downto 0) := (others => '0');
    signal byte_is_done_pipeline  : std_logic_vector(2 downto 0) := (others => '0');
    signal received_byte          : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_fifo_write_index    : natural range 0 to 3 := 0;

    -- Written in main clock domain and read in spi clock domain at the end of a byte.
    -- Writes are made a few main clocks after a byte has ended, so these are stable for
    -- most of a byte time when they are read. The write index is gray coded.
    signal tx_fifo            : byte_array(0 to 3) := (others => (others => '0'));
    signal tx_fifo_write_gray : std_logic_vector(1 downto 0) := (others => '0');

begin

    spi_rx_out <= (received_byte_is_ready => byte_is_done_pipeline(0) = '1',
                   received_byte          => received_byte);
    -- delayed so that the protocol has handled a received frame before the transmit ready
    spi_tx_out <= (byte_is_transmitted => byte_is_done_pipeline(2) = '1');

    spi_fpga_out.spi_data_out <= tx_shift_register(tx_shift_register'left);

------------------------------------------
    bit_counting : process(spi_fpga_in.spi_clock, spi_fpga_in.spi_cs_in)
    begin
        if spi_fpga_in.spi_cs_in = '1' then
            bit_counter <= 0;
        elsif rising_edge(spi_fpga_in.spi_clock) then
            bit_counter <= (bit_counter + 1) mod 8;
        end if;
    end process bit_counting;

    receive : process(spi_fpga_in.spi_clock)
    begin
        if rising_edge(spi_fpga_in.spi_clock) then
            rx_shift_register <= rx_shift_register(rx_shift_register'left-1 downto 0) & spi_fpga_in.spi_data_in;
            if bit_counter = 7 then
                rx_byte     <= rx_shift_register & spi_fpga_in.spi_data_in;
                byte_toggle <= not byte_toggle;
            end if;
        end if;
    end process receive;

------------------------------------------
    -- Data out changes on the rising edge right after the master has sampled it. The
    -- clock to output delay holds the previous bit long enough for the master, and the
    -- next bit then has almost a full spi clock period to reach the master.
    transmit : process(spi_fpga_in.spi_clock, spi_fpga_in.spi_cs_in)
    begin
        if spi_fpga_in.spi_cs_in = '1' then
            tx_shift_register <= (others => '1');
        elsif rising_edge(spi_fpga_in.spi_clock) then
            if bit_counter = 7 then
                if to_gray(tx_fifo_read_index) /= tx_fifo_write_gray then
                    tx_shift_register <= tx_fifo(tx_fifo_read_index);
                else
                    tx_shift_register <= (others => '0');
                end if;
            else
                tx_shift_register <= tx_shift_register(tx_shift_register'left-1 downto 0) & '0';
            end if;
        end if;
    end process transmit;

    transmit_fifo_read : process(spi_fpga_in.spi_clock)
    begin
        if rising_edge(spi_fpga_in.spi_clock) then
            if bit_counter = 7 and to_gray(tx_fifo_read_index) /= tx_fifo_write_gray then
                tx_fifo_read_index <= (tx_fifo_read_index + 1) mod 4;
            end if;
        end if;
    end process transmit_fifo_read;

------------------------------------------
    main : process(main_clock)
    begin
        if rising_edge(main_clock) then
            byte_toggle_sync      <= byte_toggle_sync(1 downto 0) & byte_toggle;
            byte_is_done_pipeline <= byte_is_done_pipeline(1 downto 0) & (byte_toggle_sync(2) xor byte_toggle_sync(1));

            if byte_toggle_sync(2) /= byte_toggle_sync(1) then
                received_byte <= rx_byte;
            end if;

            if spi_tx_in.data_send_is_requested then
                tx_fifo(tx_fifo_write_index) <= spi_tx_in.data_to_be_sent_through_spi;
                tx_fifo_write_index          <= (tx_fifo_write_index + 1) mod 4;
                tx_fifo_write_gray           <= to_gray((tx_fifo_write_index + 1) mod 4);
            end if;
        end if; --rising_edge
    end process main;
------------------------------------------

end rtl;
--------------------------------------------------
