from pyftdi.spi import SpiController
from pyftdi.ftdi import Ftdi
# List all FTDI devices
print(Ftdi.list_devices())

# Iterate and print the available FTDI devices
# for idx, device in enumerate(ftdi_devices):
#     vendor, product, sn = device
#     print(f"Device {idx}:")
#     print(f"  Vendor: {vendor:04x}")
#     print(f"  Product: {product:04x}")
#     print(f"  Serial: {sn}")

# Initialize the SPI controller
spi = SpiController()

# Configure the FTDI device, replace 'ftdi:///1' with your actual device address
spi.configure('ftdi://ftdi:2232:0:2/1')

# Get an SPI port, configure the clock frequency, and other settings
slave = spi.get_port(cs=0, freq=10E6, mode=0)  # cs=0 is Chip Select 0, freq=1 MHz, mode=0 (CPOL=0, CPHA=0)

# Write data to the SPI device
data_to_send = [0xb5, 0x1d]  # Replace with the data you want to send
response = slave.exchange(data_to_send, duplex=True)

# Read the response from the SPI device
print("Response from SPI device:", response)
