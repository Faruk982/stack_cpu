// ============================================================================
// ALU — 16-bit Combinational Arithmetic/Logic Unit
//
// Purely combinational: no clock, no state.
// Inputs:  a[15:0]  = TOS (top-of-stack)
//          b[15:0]  = NOS (next-on-stack)
//          alu_op[3:0] = operation selector
// Outputs: result[15:0], zero_flag (result == 0)
// ============================================================================

module alu (
    input  wire [15:0] a,           // Operand A (TOS)
    input  wire [15:0] b,           // Operand B (NOS)
    input  wire [3:0]  alu_op,      // Operation selector
    output reg  [15:0] result,      // ALU result
    output wire        zero_flag    // 1 when result == 0
);

    // ALU operation encoding (matches control_unit alu_op assignments)
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_NOT = 4'd5;
    localparam ALU_SHL = 4'd6;
    localparam ALU_SHR = 4'd7;
    localparam ALU_NOP = 4'd15;  // No operation / pass-through

    always @(*) begin
        case (alu_op)
            ALU_ADD: result = b + a;         // NOS + TOS
            ALU_SUB: result = b - a;         // NOS - TOS
            ALU_AND: result = b & a;         // NOS & TOS
            ALU_OR:  result = b | a;         // NOS | TOS
            ALU_XOR: result = b ^ a;         // NOS ^ TOS
            ALU_NOT: result = ~a;            // ~TOS (unary)
            ALU_SHL: result = a << 1;        // TOS << 1 (unary)
            ALU_SHR: result = a >> 1;        // TOS >> 1 (unary, logical)
            default: result = 16'd0;
        endcase
    end

    // Zero flag: asserted when result is zero
    assign zero_flag = (result == 16'd0);

endmodule
