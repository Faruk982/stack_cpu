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
    localparam ALU_CMP = 4'd8;
    localparam ALU_NOP = 4'd15;

    wire [15:0] add_result;
    wire        add_carry;
    wire        add_ovf;

    wire [15:0] sub_result;
    wire        sub_carry;
    wire        sub_ovf;

    wire [15:0] and_result;
    wire [15:0] or_result;
    wire [15:0] xor_result;
    wire [15:0] not_result;
    wire [15:0] shl_result;
    wire [15:0] shr_result;
    wire        shl_carry;
    wire        shr_carry;

    reg  [15:0] res_r;
    reg         carry_r;
    reg         ovf_r;

    adder_subtractor_16 u_add (
        .a        (a),
        .b        (b),
        .sub_en   (1'b0),
        .result   (add_result),
        .carry_out(add_carry),
        .overflow (add_ovf)
    );

    adder_subtractor_16 u_sub (
        .a        (a),
        .b        (b),
        .sub_en   (1'b1),
        .result   (sub_result),
        .carry_out(sub_carry),
        .overflow (sub_ovf)
    );

    bitwise_and_16 u_and (
        .a(a),
        .b(b),
        .result(and_result)
    );

    bitwise_or_16 u_or (
        .a(a),
        .b(b),
        .result(or_result)
    );

    bitwise_xor_16 u_xor (
        .a(a),
        .b(b),
        .result(xor_result)
    );

    bitwise_not_16 u_not (
        .a(a),
        .result(not_result)
    );

    shl1_16 u_shl (
        .a(a),
        .result(shl_result),
        .carry_out(shl_carry)
    );

    shr1_16 u_shr (
        .a(a),
        .result(shr_result),
        .carry_out(shr_carry)
    );

    always @(*) begin
        carry_r = 1'b0;
        ovf_r   = 1'b0;
        case (alu_op)
            ALU_ADD: begin
                res_r   = add_result;
                carry_r = add_carry;
                ovf_r   = add_ovf;
            end
            ALU_SUB: begin
                res_r   = sub_result;
                carry_r = sub_carry;
                ovf_r   = sub_ovf;
            end
            ALU_AND: res_r = and_result;
            ALU_OR:  res_r = or_result;
            ALU_XOR: res_r = xor_result;
            ALU_NOT: res_r = not_result;
            ALU_SHL: begin
                res_r   = shl_result;
                carry_r = shl_carry;
            end
            ALU_SHR: begin
                res_r   = shr_result;
                carry_r = shr_carry;
            end
            ALU_CMP: begin
                // CMP reuses NOS-TOS subtraction result for combinational flag decisions.
                res_r   = sub_result;
                carry_r = sub_carry;
                ovf_r   = sub_ovf;
            end
            default: res_r = a;
        endcase
    end

    assign result        = res_r;
    assign zero_flag     = (res_r == 16'd0);
    assign carry_flag    = carry_r;
    assign neg_flag      = res_r[15];
    assign overflow_flag = ovf_r;

endmodule