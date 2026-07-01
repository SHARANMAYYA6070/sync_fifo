// ============================================================
// Module      : sync_fifo_sva
// Author      : SHARANMAYYA6070
// Date        : 2026-07-01
// Description : SystemVerilog Assertions for Synchronous FIFO
//               Bind this module to DUT or include in testbench
// ============================================================

module sync_fifo_sva #(
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
// ASSERTION 1: Overflow fires on write to full FIFO
// ============================================================

    property p_overflow;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && full) |-> overflow;
    endproperty

    A_OVERFLOW: assert property (p_overflow)
    else $error("[SVA FAIL] A_OVERFLOW: wr_en=%b full=%b overflow=%b at t=%0t",
                 wr_en, full, overflow, $time);

// ============================================================
// ASSERTION 2: Underflow fires on read from empty FIFO
// ============================================================

    property p_underflow;
        @(posedge clk) disable iff (!rst_n)
        (rd_en && empty) |-> underflow;
    endproperty

    A_UNDERFLOW: assert property (p_underflow)
    else $error("[SVA FAIL] A_UNDERFLOW: rd_en=%b empty=%b underflow=%b at t=%0t",
                 rd_en, empty, underflow, $time);

// ============================================================
// ASSERTION 3: Full and Empty NEVER both high (impossible state)
// ============================================================

    property p_full_empty_mutex;
        @(posedge clk) disable iff (!rst_n)
        not (full && empty);
    endproperty

    A_FULL_EMPTY_MUTEX: assert property (p_full_empty_mutex)
    else $error("[SVA FAIL] A_FULL_EMPTY_MUTEX: full and empty both 1 at t=%0t",
                 $time);

// ============================================================
// ASSERTION 4: After reset — FIFO must be empty and not full
// ============================================================

    property p_reset_state;
        @(posedge clk)
        (!rst_n) |=> (empty && !full);
    endproperty

    A_RESET_STATE: assert property (p_reset_state)
    else $error("[SVA FAIL] A_RESET_STATE: Not empty after reset at t=%0t",
                 $time);

// ============================================================
// ASSERTION 5: Count must never exceed DEPTH
// ============================================================

    property p_count_max;
        @(posedge clk) disable iff (!rst_n)
        (count <= DEPTH);
    endproperty

    A_COUNT_MAX: assert property (p_count_max)
    else $error("[SVA FAIL] A_COUNT_MAX: count=%0d > DEPTH=%0d at t=%0t",
                 count, DEPTH, $time);

// ============================================================
// ASSERTION 6: Full flag correct — fires when count == DEPTH
// ============================================================

    property p_full_correct;
        @(posedge clk) disable iff (!rst_n)
        (count == DEPTH) |-> full;
    endproperty

    A_FULL_CORRECT: assert property (p_full_correct)
    else $error("[SVA FAIL] A_FULL_CORRECT: count=DEPTH but full=0 at t=%0t",
                 $time);

// ============================================================
// ASSERTION 7: Empty flag correct — fires when count == 0
// ============================================================

    property p_empty_correct;
        @(posedge clk) disable iff (!rst_n)
        (count == 0) |-> empty;
    endproperty

    A_EMPTY_CORRECT: assert property (p_empty_correct)
    else $error("[SVA FAIL] A_EMPTY_CORRECT: count=0 but empty=0 at t=%0t",
                 $time);

// ============================================================
// ASSERTION 8: No overflow when FIFO is not full
// ============================================================

    property p_no_overflow_when_not_full;
        @(posedge clk) disable iff (!rst_n)
        (!full) |-> !overflow;
    endproperty

    A_NO_SPURIOUS_OVERFLOW: assert property (p_no_overflow_when_not_full)
    else $error("[SVA FAIL] A_NO_SPURIOUS_OVERFLOW: overflow=1 but full=0 at t=%0t",
                 $time);

endmodule
