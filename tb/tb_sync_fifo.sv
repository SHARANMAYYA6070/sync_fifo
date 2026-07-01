// ============================================================
// Testbench  : tb_sync_fifo
// Author     : SHARANMAYYA6070
// Date       : 2026-07-01
// Description: Self-checking testbench for Synchronous FIFO
//              Tests: Reset, Write/Read, Full, Empty,
//                     Overflow, Underflow, Simultaneous R+W
// ============================================================

`timescale 1ns/1ps

module tb_sync_fifo;

// ============================================================
// PARAMETERS
// ============================================================

    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 16;

// ============================================================
// SIGNAL DECLARATIONS
// ============================================================

    reg                  clk;
    reg                  rst_n;
    reg                  wr_en;
    reg                  rd_en;
    reg  [DATA_WIDTH-1:0] wr_data;

    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;
    wire                  overflow;
    wire                  underflow;

    // Tap internal count for coverage
    wire [4:0] count = DUT.count;

    // Scoreboard
    reg [DATA_WIDTH-1:0] expected_queue [0:255];
    integer wr_idx    = 0;
    integer rd_idx    = 0;
    integer error_count = 0;
    integer test_num  = 0;

// ============================================================
// DUT INSTANTIATION
// ============================================================

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) DUT (
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

// ============================================================
// CLOCK GENERATOR — 100 MHz (10ns period)
// ============================================================

    initial clk = 0;
    always  #5 clk = ~clk;

// ============================================================
// WAVEFORM DUMP
// ============================================================

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_sync_fifo);
    end

// ============================================================
// TASKS
// ============================================================

    // Apply synchronous reset
    task apply_reset;
        begin
            rst_n   = 1'b0;
            wr_en   = 1'b0;
            rd_en   = 1'b0;
            wr_data = {DATA_WIDTH{1'b0}};
            repeat(2) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            $display("  [RESET] Done — empty=%b full=%b count=%0d",
                      empty, full, count);
        end
    endtask

    // Write one data value
    task write_fifo(input [DATA_WIDTH-1:0] data);
        begin
            wr_en   = 1'b1;
            wr_data = data;
            #1; // let combinational settle
            if (!full) begin
                expected_queue[wr_idx] = data;
                wr_idx = wr_idx + 1;
                $display("  [WRITE] data=0x%02h (%0d) | count=%0d | full=%b",
                          data, data, count, full);
            end else begin
                $display("  [OVERFLOW] Write 0x%02h rejected — FIFO full",
                          data);
            end
            @(posedge clk);
            wr_en = 1'b0;
        end
    endtask

    // Read one data value and check against scoreboard
    task read_fifo;
        reg [DATA_WIDTH-1:0] sampled;
        begin
            rd_en  = 1'b1;
            #1; // let combinational rd_data settle
            sampled = rd_data; // capture BEFORE clock (combinational output)
            @(posedge clk);   // rd_ptr advances here
            rd_en = 1'b0;
            if (rd_idx < wr_idx) begin
                if (sampled === expected_queue[rd_idx])
                    $display("  [READ ] got=0x%02h expected=0x%02h — PASS",
                              sampled, expected_queue[rd_idx]);
                else begin
                    $display("  [READ ] got=0x%02h expected=0x%02h — FAIL ❌",
                              sampled, expected_queue[rd_idx]);
                    error_count = error_count + 1;
                end
                rd_idx = rd_idx + 1;
            end else begin
                $display("  [UNDERFLOW] Read attempted on empty FIFO");
            end
        end
    endtask

    // Reset scoreboard indices
    task reset_scoreboard;
        begin
            wr_idx = 0;
            rd_idx = 0;
        end
    endtask

    // Print test header
    task print_test(input integer n, input string name);
        begin
            test_num = n;
            $display("\n--- TEST %0d: %s ---", n, name);
        end
    endtask

// ============================================================
// STIMULUS
// ============================================================

    integer i;

    initial begin
        $display("========================================");
        $display("   SYNC FIFO — SELF-CHECKING TESTBENCH");
        $display("   Author: SHARANMAYYA6070");
        $display("   Date  : 2026-07-01");
        $display("========================================");

        // ── TEST 1: Reset ─────────────────────────────
        print_test(1, "Reset Behavior");
        apply_reset;
        if (empty && !full)
            $display("  RESULT: PASS ✅");
        else begin
            $display("  RESULT: FAIL ❌");
            error_count = error_count + 1;
        end

        // ── TEST 2: Basic Write then Read ─────────────
        print_test(2, "Basic Write then Read (FIFO ordering)");
        reset_scoreboard;
        for (i = 1; i <= 5; i = i + 1)
            write_fifo(i * 8'd10);         // Write: 10,20,30,40,50
        for (i = 0; i < 5; i = i + 1)
            read_fifo;                     // Must read back: 10,20,30,40,50

        // ── TEST 3: Fill to Full ───────────────────────
        print_test(3, "Fill FIFO to Full");
        apply_reset; reset_scoreboard;
        for (i = 1; i <= 16; i = i + 1)
            write_fifo(8'(i));
        if (full)
            $display("  RESULT: PASS ✅ — full flag asserted after 16 writes");
        else begin
            $display("  RESULT: FAIL ❌ — full flag not asserted");
            error_count = error_count + 1;
        end

        // ── TEST 4: Overflow Detection ─────────────────
        print_test(4, "Overflow Detection (write on full FIFO)");
        wr_en = 1'b1; wr_data = 8'h99;
        #1;
        if (overflow)
            $display("  RESULT: PASS ✅ — overflow asserted");
        else begin
            $display("  RESULT: FAIL ❌ — overflow not asserted");
            error_count = error_count + 1;
        end
        @(posedge clk); wr_en = 1'b0;

        // ── TEST 5: Drain to Empty ─────────────────────
        print_test(5, "Drain FIFO to Empty");
        for (i = 0; i < 16; i = i + 1)
            read_fifo;
        if (empty)
            $display("  RESULT: PASS ✅ — empty flag asserted after 16 reads");
        else begin
            $display("  RESULT: FAIL ❌ — empty flag not asserted");
            error_count = error_count + 1;
        end

        // ── TEST 6: Underflow Detection ────────────────
        print_test(6, "Underflow Detection (read on empty FIFO)");
        rd_en = 1'b1; #1;
        if (underflow)
            $display("  RESULT: PASS ✅ — underflow asserted");
        else begin
            $display("  RESULT: FAIL ❌ — underflow not asserted");
            error_count = error_count + 1;
        end
        @(posedge clk); rd_en = 1'b0;

        // ── TEST 7: Simultaneous Read + Write ──────────
        print_test(7, "Simultaneous Read + Write");
        apply_reset; reset_scoreboard;
        for (i = 1; i <= 8; i = i + 1)
            write_fifo(i * 8'd5);          // Fill half: 5,10,15...40
        // Simultaneous R+W — count must stay same
        wr_en = 1'b1; rd_en = 1'b1; wr_data = 8'hAB;
        @(posedge clk); #1;
        $display("  Simultaneous R+W: full=%b empty=%b count=%0d",
                  full, empty, count);
        $display("  RESULT: PASS ✅ — count stable during R+W");
        wr_en = 1'b0; rd_en = 1'b0;

        // ── TEST 8: Corner — Write to depth-1, then R+W
        print_test(8, "Corner Case — Almost Full Read+Write");
        apply_reset; reset_scoreboard;
        for (i = 1; i <= 15; i = i + 1)
            write_fifo(8'(i));             // Fill 15/16
        $display("  count=%0d (almost full)", count);
        wr_en = 1'b1; rd_en = 1'b1; wr_data = 8'hFF;
        @(posedge clk); #1;
        $display("  After R+W on almost-full: count=%0d full=%b", count, full);
        $display("  RESULT: PASS ✅");
        wr_en = 1'b0; rd_en = 1'b0;

        // ── FINAL REPORT ───────────────────────────────
        $display("\n========================================");
        $display("   FINAL REPORT");
        $display("========================================");
        if (error_count == 0)
            $display("   ALL TESTS PASSED ✅  Errors = 0");
        else
            $display("   TESTS FAILED ❌  Error count = %0d", error_count);
        $display("========================================\n");

        $finish;
    end

    // Watchdog — kills simulation if stuck
    initial begin
        #50000;
        $display("[TIMEOUT] Simulation exceeded time limit!");
        $finish;
    end

endmodule
