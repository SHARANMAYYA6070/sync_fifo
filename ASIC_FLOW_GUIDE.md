# Complete ASIC Flow Guide — sync_fifo
**RTL → Synthesis → GLS → Physical Design → GDSII**

> Reference: [iiitb_sfifo by Anmol-S314](https://github.com/Anmol-S314/iiitb_sfifo)  
> Your repo: [sync_fifo by SHARANMAYYA6070](https://github.com/SHARANMAYYA6070/sync_fifo)

---

## Understanding the Flow — Simple Explanation

Think of it this way:

| Stage | Real-world analogy |
|---|---|
| RTL Design | You write a recipe in English |
| Synthesis | The recipe is converted to exact chemical steps |
| GLS | You run the chemical steps and confirm output matches |
| Floorplan | You draw the kitchen layout |
| Placement | You place each appliance in the kitchen |
| CTS | You run one electrical cable to every appliance simultaneously |
| Routing | You connect all appliances with wires |
| GDSII | The final blueprint sent to the factory |

---

## STEP 0: Environment Setup (Windows → WSL2)

All tools run on **Linux**. On Windows, use WSL2 (Windows Subsystem for Linux).

### 0.1 Install WSL2

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

This installs Ubuntu 22.04. Restart your PC when prompted.

Then open the **Ubuntu** app from Start menu and create a username/password.

### 0.2 Install iverilog and Yosys

In your Ubuntu terminal:

```bash
sudo apt update
sudo apt install -y iverilog yosys git wget
```

Verify:
```bash
iverilog -V   # Should show: Icarus Verilog version 11.0
yosys --version   # Should show: Yosys 0.9+4081
```

### 0.3 Clone your repo into WSL

```bash
cd ~
git clone https://github.com/SHARANMAYYA6070/sync_fifo.git
cd sync_fifo
```

### 0.4 Download sky130 library files

```bash
# Liberty file for Yosys synthesis
mkdir -p lib
wget -P lib https://raw.githubusercontent.com/nickson-jose/vsdstdcelldesign/master/libs/sky130_fd_sc_hd__tt_025C_1v80.lib

# Verilog models for GLS
mkdir -p verilog_model
wget -P verilog_model https://raw.githubusercontent.com/nickson-jose/vsdstdcelldesign/master/verilog_model/primitives.v
wget -P verilog_model https://raw.githubusercontent.com/nickson-jose/vsdstdcelldesign/master/verilog_model/sky130_fd_sc_hd.v
```

---

## STEP 1: Functional Simulation ✅ (Already Done on EDA Playground)

You already completed this using EDA Playground + Aldec Riviera-PRO.

To repeat locally in WSL using iverilog:

```bash
cd ~/sync_fifo

# Compile
iverilog -g2012 rtl/sync_fifo.sv tb/tb_sync_fifo.sv -o sim/func_sim

# Run
./sim/func_sim

# View waveform
gtkwave dump.vcd &
```

Expected output: `ALL TESTS PASSED ✅  Errors = 0`

---

## STEP 2: Synthesis with Yosys

**What happens:** Yosys reads your RTL and converts it to real logic gates from the sky130 standard cell library.

- `always @(posedge clk) count <= count + 1` becomes actual D-flipflops and adder cells
- `assign full = (count == DEPTH)` becomes AND/comparator gates
- Output: `synthesis/sync_fifo_synth.v` — pure gate-level Verilog

```bash
cd ~/sync_fifo
chmod +x synthesis/yosys_run.sh
./synthesis/yosys_run.sh
```

### Expected Yosys Output (statistics):

```
=== sync_fifo ===

   Number of wires:            XXX
   Number of cells:            ~150
     sky130_fd_sc_hd__a21oi_2    XX
     sky130_fd_sc_hd__and2_2     XX
     sky130_fd_sc_hd__buf_2      XX
     sky130_fd_sc_hd__dfxtp_2    XX   ← D flip-flops (count, ptrs)
     sky130_fd_sc_hd__dfrtp_2    XX   ← D flip-flops with reset
     sky130_fd_sc_hd__inv_2      XX
     sky130_fd_sc_hd__mux2_1     XX
     sky130_fd_sc_hd__nand2_2    XX
     ...

   Chip area for module '\sync_fifo': XXXXX.XX um²
```

### What does the synthesized netlist look like?

Your original RTL:
```verilog
always @(posedge clk)
    if (!rst_n) wr_ptr <= 4'b0;
    else if (wr_en && !full) wr_ptr <= wr_ptr + 1;
```

After synthesis becomes:
```verilog
// Real sky130 cells
sky130_fd_sc_hd__dfrtp_2 wr_ptr_reg_0 (.CLK(clk), .D(wr_ptr_next[0]), .RESET_B(rst_n), .Q(wr_ptr[0]));
sky130_fd_sc_hd__dfrtp_2 wr_ptr_reg_1 (.CLK(clk), .D(wr_ptr_next[1]), .RESET_B(rst_n), .Q(wr_ptr[1]));
sky130_fd_sc_hd__and2_2  and_wr       (.A(wr_en), .B(wr_not_full), .X(do_write));
// ... etc
```

---

## STEP 3: Gate Level Simulation (GLS)

**Why?** After synthesis, your logic is now expressed as sky130 gates. We need to prove the gates behave identically to your RTL.

```bash
cd ~/sync_fifo
chmod +x gls/run_gls.sh
./gls/run_gls.sh
```

### Expected GLS Output:

```
============================================
  GATE LEVEL SIMULATION — sync_fifo
  Netlist: synthesis/sync_fifo_synth.v
============================================
--- GLS TEST 1: Reset state ---
[GLS PASS ] empty=1 after reset
[GLS PASS ] full=0 after reset
--- GLS TEST 2: Write 5 + Read 5 ---
[GLS PASS ] READ: 0x0a matched expected
[GLS PASS ] READ: 0x14 matched expected
...
============================================
  GLS PASSED — Netlist matches RTL ✅
  Errors = 0
============================================
```

### View GLS waveform:

```bash
gtkwave gls/dump_gls.vcd &
```

**What to compare:** Open both `dump.vcd` (RTL sim) and `dump_gls.vcd` (GLS) in GTKWave. The waveforms should be identical. Any difference = synthesis bug.

---

## STEP 4: Physical Design — OpenLANE

OpenLANE is an automated RTL-to-GDSII flow. It requires **Docker**.

### 4.1 Install Docker in WSL2

```bash
# In Ubuntu WSL terminal:
sudo apt-get install -y ca-certificates curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
```

Close and reopen Ubuntu terminal. Verify: `docker run hello-world`

### 4.2 Install OpenLANE

```bash
cd ~
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane
sudo make    # This downloads ~22GB of PDKs — takes 30-60 minutes
sudo make test   # Should print: Basic test passed
```

### 4.3 Prepare your design

```bash
# Copy your synthesized Verilog into OpenLANE design directory
mkdir -p ~/OpenLane/designs/sync_fifo/src
cp ~/sync_fifo/rtl/sync_fifo.sv ~/OpenLane/designs/sync_fifo/src/sync_fifo.v
cp ~/sync_fifo/openlane/config.json ~/OpenLane/designs/sync_fifo/
cp ~/sync_fifo/openlane/constraints.sdc ~/OpenLane/designs/sync_fifo/src/
```

### 4.4 Run OpenLANE — Interactive Mode

```bash
cd ~/OpenLane
sudo make mount
# You are now inside the OpenLANE Docker container
```

Inside the container:

```tcl
./flow.tcl -interactive
package require openlane 0.9
prep -design sync_fifo
```

### 4.5 Run each stage manually

```tcl
# Stage 5: Synthesis (inside OpenLANE)
run_synthesis

# Stage 6: Floorplan
run_floorplan

# Stage 7: Placement
run_placement

# Stage 8: CTS (Clock Tree Synthesis)
run_cts

# Stage 9: Routing
run_routing

# Stage 10: GDSII Generation
run_magic
```

### 4.6 Or run the full automated flow:

```bash
cd ~/OpenLane
sudo make mount
./flow.tcl -design sync_fifo
```

---

## STEP 5: View Layout in Magic

```bash
cd ~/OpenLane/designs/sync_fifo/runs/<latest_run>/results/final/def
magic -T /root/OpenLane/pdks/sky130A/libs.tech/magic/sky130A.tech \
      lef read ../../../tmp/merged.max.lef \
      def read sync_fifo.def &
```

---

## STEP 6: Post-Layout Results to Document

After OpenLANE completes, collect these numbers and add to your README:

| Metric | How to get it | Expected |
|---|---|---|
| Gate Count | `run_synthesis` stats | ~150 cells |
| Core Area | `run_floorplan` output | ~70,000 µm² |
| Performance | `report_checks` in OpenSTA | ~67 MHz |
| Flop Ratio | flops / total cells | ~0.24 |
| Total Power | `report_power` | ~228 µW |
| WNS (Worst Slack) | STA report | > 0 (no violations) |

---

## Project File Structure (Complete)

```
sync_fifo/
├── rtl/
│   └── sync_fifo.sv              # RTL design (synthesizable SV)
├── tb/
│   ├── tb_sync_fifo.sv           # Self-checking RTL testbench
│   └── sync_fifo_sva.sv          # SVA assertions
├── coverage/
│   └── sync_fifo_coverage.sv     # Functional coverage
├── synthesis/
│   ├── yosys_run.sh              # Run synthesis (bash script)
│   ├── yosys_run.tcl             # Yosys TCL commands (annotated)
│   └── sync_fifo_synth.v         # ← Generated gate-level netlist
├── gls/
│   ├── tb_sync_fifo_gls.v        # GLS testbench
│   ├── run_gls.sh                # Run GLS (bash script)
│   ├── gls_sim                   # ← Compiled GLS binary
│   ├── dump_gls.vcd              # ← GLS waveform
│   └── gls_run.log               # ← GLS log
├── verilog_model/
│   ├── primitives.v              # sky130 primitives (for GLS)
│   └── sky130_fd_sc_hd.v         # sky130 cell models (for GLS)
├── lib/
│   └── sky130_fd_sc_hd__tt_025C_1v80.lib  # sky130 liberty file
├── openlane/
│   ├── config.json               # OpenLANE configuration
│   └── constraints.sdc           # Timing constraints
├── docs/
│   ├── waveform_1.png
│   ├── waveform_2.png
│   └── waveform_analysis.md
├── sync_fifo_simulator.html
├── Synchronous FIFO Simulator.html
├── ASIC_FLOW_GUIDE.md            # ← This file
├── README.md
└── .gitignore
```

---

## Common Mistakes and Fixes

| Stage | Mistake | Fix |
|---|---|---|
| Synthesis | `$clog2` not supported | Use `yosys -s` (not old versions). Or precompute: `localparam PTR_WIDTH = 4;` |
| Synthesis | .lib file not found | Check path: `lib/sky130_fd_sc_hd__tt_025C_1v80.lib` |
| GLS | `primitives.v` missing | Download from nickson-jose/vsdstdcelldesign |
| GLS | X states in outputs | Add `-DFUNCTIONAL` to iverilog command |
| OpenLANE | `make mount` fails | Ensure Docker daemon is running: `sudo service docker start` |
| OpenLANE | DRC violations | Increase `FP_CORE_UTIL` from 50 to 40 (less dense) |
| STA | Negative slack | Increase `CLOCK_PERIOD` from 10ns to 15ns in constraints.sdc |

---

## Interview Questions — Physical Design

1. What is the difference between RTL simulation and GLS?
2. What does Yosys synthesize `$clog2` into?
3. Why do we use sky130 PDK? What does PDK stand for?
4. What is the difference between global and detailed placement?
5. What is CTS and why is clock skew bad?
6. What is the difference between DRC and LVS?
7. What is a GDSII file and who uses it?
8. What does "flop ratio" tell you about a design?
9. What is WNS (Worst Negative Slack) in STA?
10. What happens if routing has DRC violations?

---

## Author

**SHARANMAYYA6070** — Full ASIC RTL-to-GDSII flow  
Language: SystemVerilog + sky130 PDK  
Tools: EDA Playground, Yosys, iverilog, OpenLANE, Magic  
Date: July 2026
