// ============================================================================
// Data RAM — 256 × 16-bit Read/Write Memory
//
// General-purpose data memory for LOAD/STORE instructions.
// Addressed by the 8-bit field IR[7:0] from the immediate.
// Combinational read, synchronous write (gated by clk_en).
// ============================================================================

module data_ram #(
    parameter DEPTH      = 256,
    parameter ADDR_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   clk_en,
    input  wire                   rst,
    input  wire                   wr_en,          // STORE: write TOS to address
    input  wire [ADDR_WIDTH-1:0]  addr,
    input  wire [15:0]            data_in,        // TOS value for STORE
    output wire [15:0]            data_out         // Read data for LOAD
);

    reg [15:0] ram [0:DEPTH-1];

    // Combinational read — always available
    assign data_out = ram[addr];

    always @(posedge clk) begin
        if (rst) begin : ram_reset
            integer i;
            for (i = 0; i < DEPTH; i = i + 1)
                ram[i] <= 16'd0;
        end else if (clk_en && wr_en) begin
            ram[addr] <= data_in;
        end
    end

endmodule
