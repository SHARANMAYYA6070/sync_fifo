// ============================================================
// Gate Level Simulation (GLS) Testbench — sync_fifo
// Author  : SHARANMAYYA6070
//
// WHAT IS GLS?
// ─────────────────────────────────────────────────────────────
// After Yosys synthesis, we have sync_fifo_synth.v — a netlist
// made of real sky130 gate cells (sky130_fd_sc_hd__and2_2, etc.)
//
// GLS = running the SAME testbench on this netlist instead of RTL.
//
// WHY DO WE DO GLS?
//   1. Verify that synthesis did not change the logic
//   2. Catch X-propagation issues (uninitialized flops)
//   3. Check timing (with -DUNIT_DELAY=#1)
//   4. Prove functional equivalence: RTL output == netlist output
//
// HOW TO RUN (from sync_fifo/ directory in WSL):
//   iverilog -DFUNCTIONAL -DUNIT_DELAY=#0 \
//     verilog_model/primitives.v \
//     verilog_model/sky130_fd_sc_hd.v \
//     synthesis/sync_fifo_synth.v \
//     gls/tb_sync_fifo_gls.v \
//     -o gls/gls_sim
//   ./gls/gls_sim
//   gtkwave gls/dump_gls.vcd
//
// DIFFERENCE FROM RTL TESTBENCH:
//   - We include sky130 primitives (verilog_model/*.v)
//   - We use -DFUNCTIONAL to disable timing checks first
//   - The DUT (sync_fifo) is now instantiated from synth netlist
//   - Waveform saved to dump_gls.vcd instead of dump.vcd
// ============================================================

`timescale 1ns/1ps

module tb_sync_fifo_gls;

// ─── Clock and Reset ────────────────────────────────────────
reg clk, rst_n;

// ─── DUT ports ──────────────────────────────────────────────
reg        wr_en, rd_en;
reg  [7:0] wr_data;
wire [7:0] rd_data;
wire       full, empty, overflow, underflow;

// ─── Scoreboard ─────────────────────────────────────────────
reg [7:0] expected_q [0:255];
integer   wr_idx = 0, rd_idx = 0;
integer   error_count = 0;

// ─── Instantiate synthesized netlist ────────────────────────
// This is the key difference — we use sync_fifo_synth.v, not RTL
sync_fifo #(.DATA_WIDTH(8), .DEPTH(16)) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_en    (wr_en),
    .rd_en    (rd_en),
    .wr_data  (wr_data),
    .rd_data  (rd_data),
    .full     (full),
    .empty    (empty),
    .overflow (overflow),
    .underflow(underflow)
);

// ─── Clock generator: 10ns period = 100 MHz ─────────────────
initial clk = 0;
always #5 clk = ~clk;

// ─── VCD dump for GTKWave ───────────────────────────────────
initial begin
    $dumpfile("gls/dump_gls.vcd");
    $dumpvars(0, tb_sync_fifo_gls);
end

// ─── Task: Write one value ──────────────────────────────────
task write_fifo;
    input [7:0] data;
    begin
        @(negedge clk);
        wr_en   = 1;
        wr_data = data;
        expected_q[wr_idx & 8'hFF] = data;
        wr_idx = wr_idx + 1;
        @(posedge clk);
        #1;
        wr_en = 0;
    end
endtask

// ─── Task: Read one value ───────────────────────────────────
// CRITICAL: rd_data is combinational — sample BEFORE clock edge
task read_fifo;
    reg [7:0] sampled;
    begin
        @(negedge clk);
        rd_en = 1;
        // Sample combinational output NOW (before posedge advances rd_ptr)
        #1; sampled = rd_data;
        @(posedge clk);
        #1;
        rd_en = 0;
        // Check sampled value vs expected
        if (sampled !== expected_q[rd_idx & 8'hFF]) begin
            $display("[GLS ERROR] READ: got=0x%02h expected=0x%02h at time %0t",
                     sampled, expected_q[rd_idx & 8'hFF], $time);
            error_count = error_count + 1;
        end else begin
            $display("[GLS PASS ] READ: 0x%02h matched expected", sampled);
        end
        rd_idx = rd_idx + 1;
    end
endtask

// ─── Main test sequence ─────────────────────────────────────
initial begin
    $display("");
    $display("============================================");
    $display("  GATE LEVEL SIMULATION — sync_fifo");
    $display("  Netlist: synthesis/sync_fifo_synth.v");
    $display("============================================");

    // RESET
    wr_en = 0; rd_en = 0; wr_data = 0;
    rst_n = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // ── TEST 1: Reset state ──────────────────────────────────
    $display("--- GLS TEST 1: Reset state ---");
    @(posedge clk); #1;
    if (empty !== 1'b1) begin
        $display("[GLS ERROR] empty not asserted after reset"); error_count++;
    end else $display("[GLS PASS ] empty=1 after reset");
    if (full !== 1'b0) begin
        $display("[GLS ERROR] full asserted after reset"); error_count++;
    end else $display("[GLS PASS ] full=0 after reset");

    // ── TEST 2: Write 5, Read 5, check ordering ──────────────
    $display("--- GLS TEST 2: Write 5 + Read 5 ---");
    write_fifo(8'h0A);
    write_fifo(8'h14);
    write_fifo(8'h1E);
    write_fifo(8'h28);
    write_fifo(8'h32);
    read_fifo; read_fifo; read_fifo; read_fifo; read_fifo;

    // ── TEST 3: Fill to full ─────────────────────────────────
    $display("--- GLS TEST 3: Fill to full ---");
    repeat(16) begin
        write_fifo($urandom_range(0, 255));
    end
    @(posedge clk); #1;
    if (full !== 1'b1) begin
        $display("[GLS ERROR] full not asserted when count=16"); error_count++;
    end else $display("[GLS PASS ] full=1 at count=16");

    // ── TEST 4: Overflow detection ───────────────────────────
    $display("--- GLS TEST 4: Overflow ---");
    @(negedge clk);
    wr_en = 1; wr_data = 8'h99;
    #1;
    if (overflow !== 1'b1) begin
        $display("[GLS ERROR] overflow not detected when writing to full FIFO");
        error_count++;
    end else $display("[GLS PASS ] overflow=1 when writing to full FIFO");
    @(posedge clk); #1; wr_en = 0;

    // ── TEST 5: Drain to empty ───────────────────────────────
    $display("--- GLS TEST 5: Drain to empty ---");
    repeat(16) read_fifo;
    @(posedge clk); #1;
    if (empty !== 1'b1) begin
        $display("[GLS ERROR] empty not asserted after draining"); error_count++;
    end else $display("[GLS PASS ] empty=1 after drain");

    // ── TEST 6: Underflow detection ──────────────────────────
    $display("--- GLS TEST 6: Underflow ---");
    @(negedge clk);
    rd_en = 1;
    #1;
    if (underflow !== 1'b1) begin
        $display("[GLS ERROR] underflow not detected when reading empty FIFO");
        error_count++;
    end else $display("[GLS PASS ] underflow=1 when reading empty FIFO");
    @(posedge clk); #1; rd_en = 0;

    // ─── Final report ────────────────────────────────────────
    $display("");
    $display("============================================");
    if (error_count == 0)
        $display("  GLS PASSED — Netlist matches RTL ✅");
    else
        $display("  GLS FAILED — %0d errors found ❌", error_count);
    $display("  Errors = %0d", error_count);
    $display("============================================");
    $display("");

    $finish;
end

// ─── Timeout watchdog ───────────────────────────────────────
initial begin
    #50000;
    $display("[TIMEOUT] Simulation exceeded 50us — possible hang");
    $finish;
end

endmodule
