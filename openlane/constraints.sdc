# ============================================================
# constraints.sdc — Timing constraints for sync_fifo
# Used by OpenSTA (Static Timing Analysis) inside OpenLANE
#
# SDC = Synopsys Design Constraints — industry standard format
# ============================================================

# Define the clock signal
# Period = 10ns → 100 MHz target frequency
# The iiitb_sfifo project achieved ~68 MHz, so 10ns is a tough
# constraint. Relax to 15ns (67 MHz) to match their result.
create_clock [get_ports clk] -name clk -period 15.0

# Input delay — signals arrive 2ns after clock edge
set_input_delay 2.0 -clock clk [all_inputs]

# Output delay — signals must be ready 2ns before next clock edge
set_output_delay 2.0 -clock clk [all_outputs]

# Drive strength — specify the driver at inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]

# Load capacitance — specify the load at outputs
set_load 0.2 [all_outputs]
