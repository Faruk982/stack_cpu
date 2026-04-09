// ============================================================================
// Program Counter (PC) — 9-bit
// Holds the address of the current instruction in ROM (512 locations).
// Supports: reset (→0), auto-increment (+1), absolute load (JMP/CALL target).
// ============================================================================

module pc (
    input  wire       clk,
    input  wire       clk_en,
    input  wire       rst,
    input  wire       pc_inc,
    input  wire       pc_load,
    input  wire [8:0] pc_in,
    output reg  [8:0] pc_out
);

    always @(posedge clk) begin
        if (rst) begin
            pc_out <= 9'd0;
        end else if (clk_en) begin
            if (pc_load)
                pc_out <= pc_in;
            else if (pc_inc)
                pc_out <= pc_out + 9'd1;
        end
    end

endmodule