// ============================================================================
// Output Register — 16-bit
// Latches TOS value on the OUT instruction. Holds until next OUT.
// Drives LED[15:0] and 7-segment display input.
// ============================================================================

module output_reg (
    input  wire        clk,
    input  wire        clk_en,   // FIX #1: clock enable from clk_div
    input  wire        rst,
    input  wire        out_en,
    input  wire [15:0] data_in,
    output reg  [15:0] data_out
);

    always @(posedge clk) begin
        if (rst) begin
            data_out <= 16'd0;
        end else if (clk_en && out_en) begin   // FIX #1
            data_out <= data_in;
        end
    end

endmodule
