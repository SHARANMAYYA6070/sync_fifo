#!/bin/bash
# ============================================================
# yosys_run.sh — Run Yosys synthesis for sync_fifo
# Run this from the sync_fifo/ directory in WSL:
#   chmod +x synthesis/yosys_run.sh
#   ./synthesis/yosys_run.sh
# ============================================================

echo ""
echo "============================================"
echo "  sync_fifo — Yosys RTL Synthesis"
echo "  Target: sky130_fd_sc_hd (130nm)"
echo "============================================"
echo ""

# Check that Yosys is installed
if ! command -v yosys &> /dev/null; then
    echo "ERROR: Yosys not found. Install with:"
    echo "  sudo apt install yosys"
    exit 1
fi

# Check that liberty file exists
if [ ! -f "lib/sky130_fd_sc_hd__tt_025C_1v80.lib" ]; then
    echo "ERROR: sky130 .lib file not found at lib/"
    echo "Download it with:"
    echo "  mkdir -p lib"
    echo "  wget -P lib https://raw.githubusercontent.com/nickson-jose/vsdstdcelldesign/master/libs/sky130_fd_sc_hd__tt_025C_1v80.lib"
    exit 1
fi

# Run Yosys with our TCL script
yosys -s synthesis/yosys_run.tcl 2>&1 | tee synthesis/yosys_run.log

echo ""
echo "Log saved to: synthesis/yosys_run.log"
echo "Netlist at : synthesis/sync_fifo_synth.v"
