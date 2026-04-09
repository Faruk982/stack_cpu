// ============================================================================
// Return-Address Stack — Parameterised depth × ADDR_WIDTH-bit LIFO
//
// Dedicated stack for CALL/RET subroutine support.
// Separate from the data stack (Forth dual-stack convention).
//
// SP convention:
//   RSP = 0 means empty.
//   CALL: RSP++, ret_mem[RSP] <= push_addr
//   RET:  top_addr = ret_mem[RSP], RSP--
//
// Depth hardening:
//   DEPTH is silently clamped to a minimum of 4 internally via DEPTH_INT.
//   DEPTH_INT and SP_W are exposed as derived parameters (not localparams)
//   so they are available in the port width context.
// ============================================================================

module return_stack #(
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 9,
    // DEPTH_INT: user DEPTH clamped to 4 minimum. Do not override.
    parameter DEPTH_INT  = (DEPTH < 4) ? 4 : DEPTH,
    // SP_W: derived from clamped depth. Always >= 2. Do not override.
    parameter SP_W       = $clog2(DEPTH_INT)
)(
    input  wire                    clk,
    input  wire                    clk_en,
    input  wire                    rst,
    input  wire                    push_en,       // CALL: push return address
    input  wire                    pop_en,        // RET: pop return address
    input  wire [ADDR_WIDTH-1:0]   push_addr,     // Address to save (current PC)
    output wire [ADDR_WIDTH-1:0]   top_addr,      // Top of return stack (for RET)
    output wire                    rs_full,
    output wire                    rs_empty
);

    reg [ADDR_WIDTH-1:0] rs_mem [0:DEPTH_INT-1];
    reg [SP_W-1:0]       rsp;

    wire [SP_W-1:0] rsp_next = rsp + 1;

    assign top_addr = (rsp == 0) ? {ADDR_WIDTH{1'b0}} : rs_mem[rsp];
    assign rs_full  = (rsp == DEPTH_INT - 1);
    assign rs_empty = (rsp == 0);

    always @(posedge clk) begin
        if (rst) begin : rs_reset
            integer i;
            rsp <= 0;
            for (i = 0; i < DEPTH_INT; i = i + 1)
                rs_mem[i] <= {ADDR_WIDTH{1'b0}};
        end else if (clk_en) begin
            if (push_en && !rs_full) begin
                rs_mem[rsp_next] <= push_addr;
                rsp <= rsp_next;
            end
            else if (pop_en && !rs_empty) begin
                rsp <= rsp - 1;
            end
        end
    end

endmodule
