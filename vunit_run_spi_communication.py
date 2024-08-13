#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv(compile_builtins=True, vhdl_standard="2008")
lib = VU.add_library("lib")
lib.add_source_files(ROOT / "efinity_spi_comm/top_trion.vhd")
lib.add_source_files(ROOT / "testbenches/spi_communication/spi_communication_tb.vhd")

VU.main()
