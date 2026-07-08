# ============================================================
# Yosys Synthesis Script — sync_fifo
# Author  : SHARANMAYYA6070
# Tool    : Yosys (open-source RTL synthesis framework)
# Target  : sky130_fd_sc_hd (SkyWater 130nm standard cell library)
# ============================================================
#
# What Yosys does in simple terms:
#   Your RTL (sync_fifo.sv) uses abstract descriptions like:
#     "count <= count + 1"  →  Yosys converts this to actual
#   logic gates: adders, muxes, flip-flops from the sky130 library
#
# Run command (from sync_fifo/ directory in WSL):
#   yosys -s synthesis/yosys_run.tcl
# ============================================================


# ─── STEP 1: Read the design ─────────────────────────────────
# -sv flag tells Yosys to accept SystemVerilog syntax
# $clog2, always @(posedge clk), etc. are handled automatically
puts "=== STEP 1: Reading RTL ==="
read_verilog -sv rtl/sync_fifo.sv


# ─── STEP 2: Elaborate the design ────────────────────────────
# hierarchy: sets the top module, checks that all sub-modules exist
# -check: errors out if any undefined modules found
puts "=== STEP 2: Elaborating hierarchy ==="
hierarchy -check -top sync_fifo


# ─── STEP 3: Generic synthesis (technology-independent) ──────
# This is the "translate" phase — converts RTL to generic gates
# proc      : converts always/initial blocks to netlists
# opt       : optimize (remove dead logic, constants, etc.)
# fsm       : extract and optimize finite state machines
# opt       : optimize again after FSM extraction
# memory    : convert memory arrays (reg [7:0] mem[0:15]) to cells
# opt       : final cleanup
puts "=== STEP 3: Generic synthesis ==="
synth -top sync_fifo


# ─── STEP 4: Map flip-flops to sky130 DFF cells ─────────────
# dfflibmap tells Yosys which flip-flop cells exist in our library
# sky130_fd_sc_hd__dfxtp_2 = standard D-flipflop
# sky130_fd_sc_hd__dfrtp_2 = D-flipflop with reset
puts "=== STEP 4: Mapping flip-flops to sky130 cells ==="
dfflibmap -liberty lib/sky130_fd_sc_hd__tt_025C_1v80.lib


# ─── STEP 5: Technology mapping with ABC ─────────────────────
# abc = Berkeley logic minimization tool integrated in Yosys
# Maps generic gates → actual sky130 standard cells
# -liberty : path to the cell library (.lib file)
# -constr  : optional timing constraints
puts "=== STEP 5: Technology mapping (abc) ==="
abc -liberty lib/sky130_fd_sc_hd__tt_025C_1v80.lib


# ─── STEP 6: Clean up ────────────────────────────────────────
# clean: remove unused wires and cells after mapping
puts "=== STEP 6: Cleaning up ==="
clean


# ─── STEP 7: Write synthesized netlist ───────────────────────
# This is the output — a Verilog file using ONLY sky130 gate cells
# No more "always" blocks — pure gate connections
# -noattr    : don't write Yosys internal attributes
# -noexpr    : write flat gate connections
puts "=== STEP 7: Writing gate-level netlist ==="
write_verilog -noattr synthesis/sync_fifo_synth.v


# ─── STEP 8: Print statistics ────────────────────────────────
# Shows: number of cells, flip-flops, wires, etc.
# This matches what you see in the iiitb_sfifo repo (Gate Count ~600)
puts "=== STEP 8: Synthesis statistics ==="
stat -liberty lib/sky130_fd_sc_hd__tt_025C_1v80.lib


puts ""
puts "============================================"
puts "  SYNTHESIS COMPLETE!"
puts "  Netlist: synthesis/sync_fifo_synth.v"
puts "============================================"
