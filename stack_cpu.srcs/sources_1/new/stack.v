// ============================================================================
// Stack Memory — 16 entries × 16-bit with Stack Pointer
//
// Implements the CPU's sole data storage as a LIFO register array.
// Provides TOS (top-of-stack) and NOS (next-on-stack) outputs for the ALU.
//
// Stack pointer (SP) conventions:
//   SP = 0 means stack is empty (no valid entries).
//   SP points to the current top-of-stack entry.
//   PUSH increments SP then writes; POP reads then decrements SP.
//
// Supports: PUSH, POP, DUP, SWAP, ALU writeback, IN (switch input)
// ============================================================================

module stack (
    input  wire        clk,          // System clock
    input  wire        rst,          // Active-high synchronous reset

    // Control signals from Control Unit
    input  wire        push_en,      // Push immediate or IN value
    input  wire        pop_en,       // Pop (discard TOS)
    input  wire        dup_en,       // Duplicate TOS
    input  wire        swap_en,      // Swap TOS and NOS
    input  wire        alu_wr_en,    // Write ALU result back (binary ops)
    input  wire        alu_unary_en, // Write ALU result back (unary ops: NOT/SHL/SHR)
    input  wire        in_en,        // Push switch input value

    // Data inputs
    input  wire [15:0] imm_value,    // Immediate value (zero-extended from IR[8:0])
    input  wire [15:0] alu_result,   // Result from ALU
    input  wire [15:0] sw_value,     // Switch input value (for IN)

    // Data outputs
    output wire [15:0] tos,          // Top of Stack value
    output wire [15:0] nos,          // Next on Stack value
    output reg  [3:0]  sp,           // Stack pointer (for debug/observation)
    output wire        stack_full,   // Overflow indicator
    output wire        stack_empty   // Underflow indicator
);

    // 16-entry × 16-bit register array
    reg [15:0] stack_mem [0:15];

    // Combinational read of TOS and NOS
    assign tos = (sp == 4'd0) ? 16'd0 : stack_mem[sp];
    assign nos = (sp <= 4'd1) ? 16'd0 : stack_mem[sp - 1];

    // Overflow / underflow detection
    assign stack_full  = (sp == 4'd15);
    assign stack_empty = (sp == 4'd0);

    // Stack operations — synchronous
    always @(posedge clk) begin
        if (rst) begin : reset_block
            integer i;
            sp <= 4'd0;
            for (i = 0; i < 16; i = i + 1)
                stack_mem[i] <= 16'd0;
        end else begin
            // PUSH immediate
            if (push_en && !stack_full) begin
                sp <= sp + 4'd1;
                stack_mem[sp + 1] <= imm_value;
            end

            // POP (discard TOS)
            else if (pop_en && !stack_empty) begin
                sp <= sp - 4'd1;
            end

            // DUP (duplicate TOS)
            else if (dup_en && !stack_full) begin
                sp <= sp + 4'd1;
                stack_mem[sp + 1] <= stack_mem[sp];
            end

            // SWAP (exchange TOS and NOS)
            else if (swap_en && sp >= 4'd2) begin
                stack_mem[sp]     <= stack_mem[sp - 1];
                stack_mem[sp - 1] <= stack_mem[sp];
            end

            // ALU writeback — binary operations (consume 2, push 1)
            // Result goes to stack[SP-1], SP decrements by 1
            else if (alu_wr_en && sp >= 4'd2) begin
                stack_mem[sp - 1] <= alu_result;
                sp <= sp - 4'd1;
            end

            // ALU writeback — unary operations (NOT, SHL, SHR)
            // Result replaces TOS, SP unchanged
            else if (alu_unary_en && !stack_empty) begin
                stack_mem[sp] <= alu_result;
            end

            // IN (push switch value)
            else if (in_en && !stack_full) begin
                sp <= sp + 4'd1;
                stack_mem[sp + 1] <= sw_value;
            end
        end
    end

endmodule
