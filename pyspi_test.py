from pyftdi.spi import SpiController
from pyftdi.ftdi import Ftdi
# List all FTDI devices
print(Ftdi.list_devices())

# Initialize the SPI controller
spi = SpiController()

# Configure the FTDI device, replace 'ftdi://ftdi:2232:0:2/1' with your actual device address
spi.configure('ftdi://ftdi:2232:0:1/1')

# Get an SPI port, configure the clock frequency, and other settings
slave = spi.get_port(cs=0, freq=1E6, mode=0)  # cs=0 is Chip Select 0, freq=10 MHz, mode=0 (CPOL=0, CPHA=0)

# Write data to the SPI device

def send(data_to_send):
    response = slave.exchange(data_to_send, duplex=True)

    hex_response = ' '.join(f'{byte:02X}' for byte in response)
    int_response = [int(byte) for byte in response]

    print("Response from SPI device (Integers):", int_response)
    print("Response from SPI device:", hex_response)

leds_on = [0x00, 0x00, 0xac, 0xdc]  # Replace with the data you want to send
leds_off = [0x00, 0x00]  # Replace with the data you want to send
send(leds_on)
