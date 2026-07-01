// ============================================================
// Module      : sync_fifo_coverage
// Author      : SHARANMAYYA6070
// Date        : 2026-07-01
// Description : Functional Coverage for Synchronous FIFO
//               Include in testbench after DUT instantiation
// ============================================================

module sync_fifo_coverage #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input wire                   clk,
    input wire                   rst_n,
    input wire                   wr_en,
    input wire                   rd_en,
    input wire [DATA_WIDTH-1:0]  wr_data,
    input wire [DATA_WIDTH-1:0]  rd_data,
    input wire                   full,
    input wire                   empty,
    input wire                   overflow,
    input wire                   underflow,
    input wire [$clog2(DEPTH):0] count
);

// ============================================================
// COVERGROUP 1: FIFO Fill Level
// Goal: Ensure all fill levels were exercised
// ============================================================

    covergroup cg_fill_level @(posedge clk);
        option.name    = "Fill Level Coverage";
        option.comment = "Tracks FIFO occupancy across all ranges";

        cp_count: coverpoint count {
            bins empty_state = {0};           // Completely empty
            bins low         = {[1:4]};       // 1–4 entries (low traffic)
            bins mid_low     = {[5:8]};       // 5–8 entries (half)
            bins mid_high    = {[9:12]};      // 9–12 entries (above half)
            bins high        = {[13:15]};     // 13–15 entries (almost full)
            bins full_state  = {DEPTH};       // Completely full
        }
    endgroup

// ============================================================
// COVERGROUP 2: Operation Types
// Goal: All 4 operation combinations must be seen
// ============================================================

    covergroup cg_operations @(posedge clk);
        option.name    = "Operation Coverage";
        option.comment = "Tracks all combinations of wr_en and rd_en";

        cp_op: coverpoint ({wr_en, rd_en}) {
            bins idle       = {2'b00};  // No operation
            bins write_only = {2'b10};  // Write only
            bins read_only  = {2'b01};  // Read only
            bins both       = {2'b11};  // Simultaneous read + write
        }
    endgroup

// ============================================================
// COVERGROUP 3: Error Conditions
// Goal: Both overflow and underflow must be triggered
// ============================================================

    covergroup cg_errors @(posedge clk);
        option.name    = "Error Condition Coverage";
        option.comment = "Overflow and underflow must both be seen";

        cp_overflow: coverpoint overflow {
            bins normal   = {0};   // No overflow
            bins violated = {1};   // Overflow occurred — must be hit!
        }

        cp_underflow: coverpoint underflow {
            bins normal   = {0};   // No underflow
            bins violated = {1};   // Underflow occurred — must be hit!
        }
    endgroup

// ============================================================
// COVERGROUP 4: Cross Coverage
// Goal: Confirm writes happen at different fill levels
// ============================================================

    covergroup cg_cross @(posedge clk);
        option.name    = "Cross Coverage";
        option.comment = "Operation at boundary conditions";

        cp_wr: coverpoint wr_en;
        cp_rd: coverpoint rd_en;
        cp_full:  coverpoint full;
        cp_empty: coverpoint empty;

        // Write attempted at each fill boundary
        cx_write_vs_full: cross cp_wr, cp_full;

        // Read attempted at each fill boundary
        cx_read_vs_empty: cross cp_rd, cp_empty;
    endgroup

// ============================================================
// COVERGROUP 5: Data Pattern Coverage
// Goal: Diverse data values were written
// ============================================================

    covergroup cg_data @(posedge clk);
        option.name    = "Data Pattern Coverage";
        option.comment = "Checks variety of data values written";

        cp_wr_data: coverpoint wr_data iff (wr_en && !full) {
            bins zero    = {8'h00};          // All zeros
            bins all_one = {8'hFF};          // All ones
            bins low     = {[8'h01:8'h3F]}; // Low values
            bins mid     = {[8'h40:8'hBF]}; // Mid values
            bins high    = {[8'hC0:8'hFE]}; // High values
        }
    endgroup

// ============================================================
// INSTANTIATE ALL COVERGROUPS
// ============================================================

    cg_fill_level  cg_fill  = new();
    cg_operations  cg_ops   = new();
    cg_errors      cg_err   = new();
    cg_cross       cg_cross_inst = new();
    cg_data        cg_dat   = new();

// ============================================================
// COVERAGE REPORT — printed at end of simulation
// ============================================================

    final begin
        $display("\n============================================");
        $display("       FUNCTIONAL COVERAGE REPORT");
        $display("============================================");
        $display("  Fill Level Coverage  : %0.1f%%",
                  cg_fill.get_coverage());
        $display("  Operations Coverage  : %0.1f%%",
                  cg_ops.get_coverage());
        $display("  Error Conditions     : %0.1f%%",
                  cg_err.get_coverage());
        $display("  Cross Coverage       : %0.1f%%",
                  cg_cross_inst.get_coverage());
        $display("  Data Patterns        : %0.1f%%",
                  cg_dat.get_coverage());
        $display("--------------------------------------------");
        $display("  TOTAL COVERAGE       : %0.1f%%",
                  ($get_coverage()));
        $display("============================================\n");
    end

endmodule
