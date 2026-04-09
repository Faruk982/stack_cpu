// ============================================================================
// Stack Memory — Parameterised Depth, 16-bit Data Width
//
// Implements the CPU's primary data storage as a LIFO register array.
// Provides TOS (top-of-stack) and NOS (next-on-stack) outputs for the ALU.
//
// Stack pointer (SP) conventions:
//   SP = 0 means stack is empty (no valid entries).
//   SP points to the current top-of-stack entry.
//   PUSH increments SP then writes; POP reads then decrements SP.
//
// Supports: PUSH, POP, DUP, SWAP, ALU writeback, IN, LOAD (from data RAM)
// ============================================================================

module stack #(
    parameter DEPTH     = 16,
    parameter SP_WIDTH  = $clog2(DEPTH)
)(
    input  wire              clk,
    input  wire              clk_en,
    input  wire              rst,

    input  wire              push_en,
    input  wire              pop_en,
    input  wire              dup_en,
    input  wire              swap_en,
    input  wire              alu_wr_en,
    input  wire              alu_unary_en,
    input  wire              in_en,
    input  wire              load_en,       // LOAD: push RAM data

    input  wire [15:0]       imm_value,
    input  wire [15:0]       alu_result,
    input  wire [15:0]       sw_value,
    input  wire [15:0]       ram_data,      // Data from data_ram for LOAD

    output wire [15:0]       tos,
    output wire [15:0]       nos,
    output reg  [SP_WIDTH-1:0] sp,
    output wire              stack_full,
    output wire              stack_empty,
    output wire              stack_has_two
);

    reg [15:0] stack_mem [0:DEPTH-1];

    assign tos        = (sp == {SP_WIDTH{1'b0}}) ? 16'd0 : stack_mem[sp];
    assign nos        = (sp <= {{(SP_WIDTH-1){1'b0}}, 1'b1}) ? 16'd0 : stack_mem[sp - 1];
    assign stack_full  = (sp == DEPTH[SP_WIDTH-1:0] - 1);
    assign stack_empty = (sp == {SP_WIDTH{1'b0}});
    assign stack_has_two = (sp >= {{(SP_WIDTH-2){1'b0}}, 2'd2});

    wire [SP_WIDTH-1:0] sp_next = sp + 1;

    always @(posedge clk) begin
        if (rst) begin : reset_block
            integer i;
            sp <= {SP_WIDTH{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                stack_mem[i] <= 16'd0;
        end else if (clk_en) begin

            if (push_en && !stack_full) begin
                stack_mem[sp_next] <= imm_value;
                sp <= sp_next;
            end

            else if (pop_en && !stack_empty) begin
                sp <= sp - 1;
            end

            else if (dup_en && !stack_full) begin
                stack_mem[sp_next] <= stack_mem[sp];
                sp <= sp_next;
            end

            else if (swap_en && sp >= 2) begin
                stack_mem[sp]      <= stack_mem[sp - 1];
                stack_mem[sp - 1]  <= stack_mem[sp];
            end

            else if (alu_wr_en && sp >= 2) begin
                stack_mem[sp - 1] <= alu_result;
                sp <= sp - 1;
            end

            else if (alu_unary_en && !stack_empty) begin
                stack_mem[sp] <= alu_result;
            end

            else if (in_en && !stack_full) begin
                stack_mem[sp_next] <= sw_value;
                sp <= sp_next;
            end

            else if (load_en && !stack_full) begin
                stack_mem[sp_next] <= ram_data;
                sp <= sp_next;
            end

        end
    end

endmodule