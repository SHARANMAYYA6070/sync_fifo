#!/bin/bash
# ============================================================
# run_gls.sh — Gate Level Simulation runner for sync_fifo
# Run from sync_fifo/ directory in WSL:
#   chmod +x gls/run_gls.sh
#   ./gls/run_gls.sh
# ============================================================

echo ""
echo "============================================"
echo "  sync_fifo — Gate Level Simulation (GLS)"
echo "============================================"

# Check that synthesized netlist exists
if [ ! -f "synthesis/sync_fifo_synth.v" ]; then
    echo "ERROR: synthesis/sync_fifo_synth.v not found."
    echo "Run synthesis first: ./synthesis/yosys_run.sh"
    exit 1
fi

# Check sky130 model files
if [ ! -f "verilog_model/primitives.v" ]; then
    echo "ERROR: verilog_model/primitives.v not found."
    echo "Download sky130 Verilog models:"
    echo "  mkdir -p verilog_model"
    echo "  wget -P verilog_model https://raw.githubusercontent.com/nickson-jose/vsdstdcelldesign/master/verilog_model/primitives.v"
    echo "  wget -P verilog_model https://raw.githubusercontent.com/nickson-jose/vsdstdcelldesign/master/verilog_model/sky130_fd_sc_hd.v"
    exit 1
fi

echo ""
echo "Step 1: Compiling (FUNCTIONAL mode - no timing delays)..."
iverilog -DFUNCTIONAL -DUNIT_DELAY=#0 \
    verilog_model/primitives.v \
    verilog_model/sky130_fd_sc_hd.v \
    synthesis/sync_fifo_synth.v \
    gls/tb_sync_fifo_gls.v \
    -o gls/gls_sim
if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed"
    exit 1
fi
echo "Compilation successful."

echo ""
echo "Step 2: Running simulation..."
./gls/gls_sim | tee gls/gls_run.log
echo ""
echo "Log: gls/gls_run.log"
echo "VCD: gls/dump_gls.vcd"

echo ""
echo "Step 3: Open waveform with GTKWave:"
echo "  gtkwave gls/dump_gls.vcd &"
echo ""
