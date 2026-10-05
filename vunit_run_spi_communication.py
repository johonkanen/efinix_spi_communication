#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv(compile_builtins=False, vhdl_standard="2008")
VU.add_vhdl_builtins()

lib = VU.add_library("lib")
lib.add_source_files(ROOT / "source/spi_secondary.vhd")
lib.add_source_files(ROOT / "efinity_spi_comm/top_trion.vhd")

lib.add_source_files(ROOT / "source/vhdl_serial/bit_operations_pkg.vhd")
lib.add_source_files(ROOT / "source/vhdl_serial/source/clock_divider/clock_divider_generic_pkg.vhd")
lib.add_source_files(ROOT / "source/vhdl_serial/source/spi_master/spi_transmitter_generic_pkg.vhd")

lib.add_source_files(ROOT / "source/fpga_communication/hVHDL_fpga_interconnect/fpga_interconnect_generic_pkg.vhd")
lib.add_source_files(ROOT / "source/serial_protocol_generic_pkg.vhd")
lib.add_source_files(ROOT / "source/fpga_interconnect_pkg.vhd")

lib.add_source_files(ROOT / "source/spi_communication_protocol_pkg.vhd")

lib.add_source_files(ROOT / "testbenches/spi_communication/spi_communication_tb.vhd")
# main clock is 120 MHz, so spi clock period in main clocks is 120/f_spi
tb = lib.test_bench("spi_communication_tb")
for spi_mhz, clocks_per_bit in [(30, 4), (15, 8), (7.5, 16)]:
    tb.add_config(name=f"spi_{spi_mhz}MHz", generics=dict(g_spi_clock_divider=clocks_per_bit - 1))

VU.set_sim_option("nvc.sim_flags", ["-w"])

VU.main()
