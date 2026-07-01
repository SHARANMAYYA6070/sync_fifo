// ============================================================
// Module      : sync_fifo
// Author      : SHARANMAYYA6070
// Date        : 2026-07-01
// Description : Parameterized Synchronous FIFO
//               - Counter-based full/empty detection
//               - Circular buffer memory array
//               - Overflow and Underflow detection
//               - Combinational read output (zero latency)
// ============================================================

module sync_fifo #(
    parameter DATA_WIDTH = 8,   // Width of each data word
    parameter DEPTH      = 16   // Number of entries in FIFO
)(
    input  wire                  clk,        // System clock
    input  wire                  rst_n,      // Active-low synchronous reset
    input  wire                  wr_en,      // Write enable
    input  wire                  rd_en,      // Read enable
    input  wire [DATA_WIDTH-1:0] wr_data,    // Data to write

    output wire [DATA_WIDTH-1:0] rd_data,    // Data read out (combinational)
    output wire                  full,       // FIFO full flag
    output wire                  empty,      // FIFO empty flag
    output wire                  overflow,   // Write attempted when full
    output wire                  underflow   // Read attempted when empty
);

// ============================================================
// LOCAL PARAMETERS
// ============================================================

    localparam PTR_WIDTH   = $clog2(DEPTH);       // 4 bits for depth=16
    localparam COUNT_WIDTH = $clog2(DEPTH) + 1;   // 5 bits for depth=16

// ============================================================
// INTERNAL SIGNALS
// ============================================================

    reg [DATA_WIDTH-1:0]  mem [0:DEPTH-1];   // Memory array (16 x 8-bit)
    reg [PTR_WIDTH-1:0]   wr_ptr;             // Write pointer (0-15)
    reg [PTR_WIDTH-1:0]   rd_ptr;             // Read pointer  (0-15)
    reg [COUNT_WIDTH-1:0] count;              // Entry counter (0-16)

// ============================================================
// FLAG LOGIC — Combinational
// ============================================================

    assign full      = (count == DEPTH);  // All 16 slots filled
    assign empty     = (count == 0);      // No data present
    assign overflow  = wr_en &  full;     // Illegal write attempt
    assign underflow = rd_en &  empty;    // Illegal read attempt
    assign rd_data   = mem[rd_ptr];       // Combinational read output

// ============================================================
// WRITE LOGIC — Sequential
// ============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= {PTR_WIDTH{1'b0}};
        end
        else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;        // Store data
            wr_ptr      <= wr_ptr + 1;     // Auto wrap-around (4-bit overflow)
        end
        // If wr_en && full: overflow → data dropped silently
    end

// ============================================================
// READ LOGIC — Sequential
// ============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= {PTR_WIDTH{1'b0}};
        end
        else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;          // Advance pointer (auto wrap-around)
        end
        // rd_data is combinational — always reflects mem[rd_ptr]
    end

// ============================================================
// COUNT LOGIC — Sequential
// ============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            count <= {COUNT_WIDTH{1'b0}};
        end
        else begin
            case ({wr_en & !full, rd_en & !empty})
                2'b10   : count <= count + 1;  // Write only
                2'b01   : count <= count - 1;  // Read only
                2'b11   : count <= count;       // Simultaneous R+W → no change
                default : count <= count;       // Idle
            endcase
        end
    end

// ============================================================
// SVA ASSERTIONS (simulation only — excluded from synthesis)
// ============================================================

`ifndef SYNTHESIS
    // Full and Empty must never be simultaneously asserted
    property p_full_empty_mutex;
        @(posedge clk) disable iff (!rst_n)
        not (full && empty);
    endproperty
    A_FULL_EMPTY_MUTEX: assert property (p_full_empty_mutex)
    else $error("[ASSERT FAIL] full and empty both high at time %0t", $time);

    // Count must never exceed DEPTH
    property p_count_range;
        @(posedge clk) disable iff (!rst_n)
        (count <= DEPTH);
    endproperty
    A_COUNT_RANGE: assert property (p_count_range)
    else $error("[ASSERT FAIL] count=%0d exceeded DEPTH=%0d at time %0t",
                 count, DEPTH, $time);

    // Overflow must fire when write on full
    property p_overflow_check;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && full) |-> overflow;
    endproperty
    A_OVERFLOW: assert property (p_overflow_check)
    else $error("[ASSERT FAIL] overflow not asserted at time %0t", $time);

    // Underflow must fire when read on empty
    property p_underflow_check;
        @(posedge clk) disable iff (!rst_n)
        (rd_en && empty) |-> underflow;
    endproperty
    A_UNDERFLOW: assert property (p_underflow_check)
    else $error("[ASSERT FAIL] underflow not asserted at time %0t", $time);

    // After reset: empty=1, full=0
    property p_reset_state;
        @(posedge clk)
        (!rst_n) |=> (empty && !full);
    endproperty
    A_RESET_STATE: assert property (p_reset_state)
    else $error("[ASSERT FAIL] FIFO not empty after reset at time %0t", $time);
`endif

endmodule
