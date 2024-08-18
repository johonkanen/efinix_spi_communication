#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv(compile_builtins=True, vhdl_standard="2008")

lib = VU.add_library("lib")
lib.add_source_files(ROOT / "efinity_spi_comm/top_trion.vhd")

lib.add_source_files(ROOT / "source/vhdl_serial/bit_operations_pkg.vhd")
lib.add_source_files(ROOT / "source/vhdl_serial/source/clock_divider/clock_divider_generic_pkg.vhd")
lib.add_source_files(ROOT / "source/vhdl_serial/source/spi_master/spi_transmitter_generic_pkg.vhd")
lib.add_source_files(ROOT / "source/vhdl_serial/source/ads7056/clock_divider_pkg.vhd")

lib.add_source_files(ROOT / "source/fpga_communication/hVHDL_fpga_interconnect/fpga_interconnect_generic_pkg.vhd")
lib.add_source_files(ROOT / "source/fpga_communication/serial_protocol_generic_pkg.vhd")
lib.add_source_files(ROOT / "source/fpga_interconnect_pkg.vhd")
lib.add_source_files(ROOT / "source/spi_receiver/spi_communication_pkg.vhd")

lib.add_source_files(ROOT / "testbenches/spi_communication/spi_communication_protocol_pkg.vhd")

lib.add_source_files(ROOT / "testbenches/spi_communication/spi_communication_tb.vhd")
VU.set_sim_option("nvc.sim_flags", ["-w"])

VU.main()
