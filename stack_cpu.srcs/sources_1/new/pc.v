// ============================================================================
// Program Counter (PC) — 8-bit
// Holds the address of the current instruction in ROM.
// Supports: reset (→0), auto-increment (+1), absolute load (JMP target).
// ============================================================================

module pc (
    input  wire       clk,       // System clock
    input  wire       rst,       // Active-high synchronous reset
    input  wire       pc_inc,    // Increment enable
    input  wire       pc_load,   // Load enable (for JMP/JZ/JNZ)
    input  wire [7:0] pc_in,     // Load value (jump target)
    output reg  [7:0] pc_out     // Current PC value → ROM address
);

    always @(posedge clk) begin
        if (rst) begin
            pc_out <= 8'd0;
        end else if (pc_load) begin
            pc_out <= pc_in;
        end else if (pc_inc) begin
            pc_out <= pc_out + 8'd1;
        end
        // else: hold current value
    end

endmodule
