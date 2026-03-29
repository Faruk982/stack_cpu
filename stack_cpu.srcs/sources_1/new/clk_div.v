// ============================================================================
// Clock Divider Module
// Divides 100 MHz system clock to a slower frequency for demo visibility.
// Default: ~2 Hz (DIVISOR = 25_000_000)
// ============================================================================

module clk_div #(
    parameter DIVISOR = 25_000_000   // 100MHz / (2*25M) = 2 Hz
)(
    input  wire clk,        // 100 MHz input clock
    input  wire rst,        // Active-high synchronous reset
    output reg  clk_out     // Divided clock output
);

    reg [31:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter <= 32'd0;
            clk_out <= 1'b0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= 32'd0;
                clk_out <= ~clk_out;
            end else begin
                counter <= counter + 1;
            end
        end
    end

endmodule
