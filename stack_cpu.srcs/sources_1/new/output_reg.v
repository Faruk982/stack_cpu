// ============================================================================
// Output Register — 16-bit
// Latches TOS value on the OUT instruction. Holds until next OUT.
// Drives LED[15:0] and 7-segment display input.
// ============================================================================

module output_reg (
    input  wire        clk,       // System clock
    input  wire        rst,       // Active-high synchronous reset
    input  wire        out_en,    // Write enable (asserted for OUT instruction)
    input  wire [15:0] data_in,   // TOS value to latch
    output reg  [15:0] data_out   // Latched output → LEDs / 7-seg
);

    always @(posedge clk) begin
        if (rst) begin
            data_out <= 16'd0;
        end else if (out_en) begin
            data_out <= data_in;
        end
        // else: hold current value
    end

endmodule
