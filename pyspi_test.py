from pyftdi.spi import SpiController
from pyftdi.ftdi import Ftdi
# List all FTDI devices
print(Ftdi.list_devices())

# Initialize the SPI controller
spi = SpiController()

# Configure the FTDI device, replace 'ftdi://ftdi:2232:0:2/1' with your actual device address
spi.configure('ftdi://ftdi:2232:0:1/1')

# Get an SPI port, configure the clock frequency, and other settings
slave = spi.get_port(cs=0, freq=8E6, mode=0)  # cs=0 is Chip Select 0, freq=10 MHz, mode=0 (CPOL=0, CPHA=0)

# Write data to the SPI device

def send(data_to_send):
    response = slave.exchange(data_to_send, duplex=True)
    remaining_bytes = response[7:]

    integers = [
        int.from_bytes(remaining_bytes[i:i+2], byteorder='big') 
        for i in range(0, len(remaining_bytes), 2)
    ]

    hex_response = ' '.join(f'{byte:02X}' for byte in response)
    int_response = [int(byte) for byte in response]

    print("Response from SPI device (Integers):", int_response)
    print("Response from SPI device:", hex_response)
    print("data as integers : ", integers)

leds_on   = [0x04, 0x00, 0x01, 0xac, 0xdc]
leds_off  = [0x04, 0x00, 0x01, 0x00, 0x00]
read_data = [0x02, 0x00, 0x01, 0x00, 0x00]

stream_10_data = [ 0x05, 0x00, 0x01, 0x00, 0x00, 0x0a,
                  0x00, 
                  0x00, 0x00,
                  0x00, 0x00,
                  0x00, 0x00,
                  0x00, 0x00,
                  0x00, 0x00,
                  0x00, 0x00,
                  0x00, 0x00,
                  0x00, 0x00,
                  0x00, 0x00, 
                  0x00, 0x00]

send(leds_on)
