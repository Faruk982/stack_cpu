// ============================================================================
// Return-Address Stack — 16-entry × 9-bit LIFO
//
// Dedicated stack for CALL/RET subroutine support.
// Separate from the data stack (Forth dual-stack convention).
//
// SP convention matches data stack:
//   RSP = 0 means empty.
//   CALL: RSP++, ret_mem[RSP] <= push_addr
//   RET:  pop_addr = ret_mem[RSP], RSP--
// ============================================================================

module return_stack #(
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 9
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

    localparam SP_W = $clog2(DEPTH);

    reg [ADDR_WIDTH-1:0] rs_mem [0:DEPTH-1];
    reg [SP_W-1:0]       rsp;

    wire [SP_W-1:0] rsp_next = rsp + 1;

    assign top_addr = (rsp == {SP_W{1'b0}}) ? {ADDR_WIDTH{1'b0}} : rs_mem[rsp];
    assign rs_full  = (rsp == DEPTH[SP_W-1:0] - 1);
    assign rs_empty = (rsp == {SP_W{1'b0}});

    always @(posedge clk) begin
        if (rst) begin : rs_reset
            integer i;
            rsp <= {SP_W{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
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
