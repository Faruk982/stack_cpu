// ============================================================================
// Clock Divider — Clock-Enable Generator
//
// This version produces a single-cycle high pulse (clk_en) every
// DIVISOR cycles of the master clock.  All CPU modules remain on the single
// 100 MHz clock domain and gate their registers with this enable signal.
//
// Default: DIVISOR = 25_000_000 → pulse every 0.25 s → 4 Hz effective rate.
// ============================================================================

module clk_div #(
    parameter DIVISOR = 25_000_000   // 100 MHz / 25 M = one pulse per 0.25 s
)(
    input  wire clk,     // 100 MHz master clock
    input  wire rst,     // Active-high synchronous reset
    output reg  clk_en   // Single-cycle enable pulse at divided rate
);

    reg [31:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter <= 32'd0;
            clk_en  <= 1'b0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= 32'd0;
                clk_en  <= 1'b1;   // one-cycle pulse
            end else begin
                counter <= counter + 1;
                clk_en  <= 1'b0;
            end
        end
    end

endmodule