// ============================================================================
// ALU — 16-bit Combinational Arithmetic/Logic Unit
//
// Purely combinational: no clock, no state.
// Inputs:  a[15:0]    = TOS (top-of-stack)
//          b[15:0]    = NOS (next-on-stack)
//          alu_op[3:0] = operation selector
// Outputs: result[15:0], zero_flag, carry_flag, neg_flag, overflow_flag
// ============================================================================

module alu (
    input  wire [15:0] a,             // Operand A (TOS)
    input  wire [15:0] b,             // Operand B (NOS)
    input  wire [3:0]  alu_op,
    output wire [15:0] result,
    output wire        zero_flag,
    output wire        carry_flag,
    output wire        neg_flag,
    output wire        overflow_flag
);

    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_NOT = 4'd5;
    localparam ALU_SHL = 4'd6;
    localparam ALU_SHR = 4'd7;
    localparam ALU_NOP = 4'd15;

    reg [15:0] res_r;
    reg        carry_r;
    reg        ovf_r;

    always @(*) begin
        carry_r = 1'b0;
        ovf_r   = 1'b0;
        case (alu_op)
            ALU_ADD: begin
                {carry_r, res_r} = {1'b0, b} + {1'b0, a};
                ovf_r = (~b[15] & ~a[15] & res_r[15]) |
                        ( b[15] &  a[15] & ~res_r[15]);
            end
            ALU_SUB: begin
                {carry_r, res_r} = {1'b0, b} - {1'b0, a};
                ovf_r = (~b[15] &  a[15] & res_r[15]) |
                        ( b[15] & ~a[15] & ~res_r[15]);
            end
            ALU_AND: res_r = b & a;
            ALU_OR:  res_r = b | a;
            ALU_XOR: res_r = b ^ a;
            ALU_NOT: res_r = ~a;
            ALU_SHL: {carry_r, res_r} = {a, 1'b0};
            ALU_SHR: begin res_r = {1'b0, a[15:1]}; carry_r = a[0]; end
            default: res_r = a;
        endcase
    end

    assign result        = res_r;
    assign zero_flag     = (res_r == 16'd0);
    assign carry_flag    = carry_r;
    assign neg_flag      = res_r[15];
    assign overflow_flag = ovf_r;

endmodule