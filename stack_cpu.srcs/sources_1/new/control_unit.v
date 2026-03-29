// ============================================================================
// Control Unit — Hardwired FSM
//
// 4+1 state Moore machine that sequences instruction execution:
//   S_RESET  (00) → initialise all registers
//   S_FETCH  (01) → load IR from ROM[PC], increment PC
//   S_DECODE (10) → latch IR from ROM output (ROM latency cycle)
//   S_EXECUTE(11) → assert control signals per opcode
//   S_HALT        → freeze; wait for reset
//
// The alu_op output is driven combinationally so the ALU result and zero_flag
// are valid in the same cycle that the control unit reads them for z_flag latching.
// All other control signals are registered (output on the cycle they're needed).
// ============================================================================

module control_unit (
    input  wire       clk,         // System clock
    input  wire       rst,         // Active-high synchronous reset

    // Instruction Register fields
    input  wire [6:0] opcode,      // IR[15:9]
    input  wire       zero_flag,   // From ALU (combinational)

    // ---- Control signal outputs ----
    output reg        ir_load,     // Load Instruction Register
    output reg        pc_inc,      // Increment Program Counter
    output reg        pc_load,     // Load PC (JMP / JZ / JNZ)

    // Stack control
    output reg        push_en,     // Push immediate
    output reg        pop_en,      // Pop (discard TOS)
    output reg        dup_en,      // Duplicate TOS
    output reg        swap_en,     // Swap TOS <-> NOS
    output reg        alu_wr_en,   // ALU writeback (binary ops)
    output reg        alu_unary_en,// ALU writeback (unary ops)
    output reg        in_en,       // Push switch input

    // ALU control — COMBINATIONAL output
    output reg [3:0]  alu_op,      // ALU operation selector

    // Output register control
    output reg        out_en,      // Latch TOS to output register

    // Status
    output reg        halted       // CPU is halted
);

    // ---- Opcode constants ----
    localparam OP_PUSH = 7'h01;
    localparam OP_POP  = 7'h02;
    localparam OP_DUP  = 7'h03;
    localparam OP_SWAP = 7'h04;
    localparam OP_ADD  = 7'h10;
    localparam OP_SUB  = 7'h11;
    localparam OP_AND  = 7'h12;
    localparam OP_OR   = 7'h13;
    localparam OP_XOR  = 7'h14;
    localparam OP_NOT  = 7'h15;
    localparam OP_SHL  = 7'h16;
    localparam OP_SHR  = 7'h17;
    localparam OP_JMP  = 7'h20;
    localparam OP_JZ   = 7'h21;
    localparam OP_JNZ  = 7'h22;
    localparam OP_OUT  = 7'h30;
    localparam OP_IN   = 7'h31;
    localparam OP_HALT = 7'h3F;

    // ---- ALU operation codes (must match alu.v) ----
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_NOT = 4'd5;
    localparam ALU_SHL = 4'd6;
    localparam ALU_SHR = 4'd7;
    localparam ALU_NOP = 4'd15;

    // ---- FSM states ----
    localparam S_RESET   = 3'd0;
    localparam S_FETCH   = 3'd1;
    localparam S_DECODE  = 3'd2;
    localparam S_EXECUTE = 3'd3;
    localparam S_HALT    = 3'd4;

    reg [2:0] state;

    // Latched zero flag — updated after each ALU operation in S_EXECUTE
    reg z_flag;

    // ========================================================================
    // Combinational ALU op decode
    // This ensures the ALU result and zero_flag are valid when we sample
    // them at the rising clock edge during S_EXECUTE.
    // ========================================================================
    always @(*) begin
        case (opcode)
            OP_ADD: alu_op = ALU_ADD;
            OP_SUB: alu_op = ALU_SUB;
            OP_AND: alu_op = ALU_AND;
            OP_OR:  alu_op = ALU_OR;
            OP_XOR: alu_op = ALU_XOR;
            OP_NOT: alu_op = ALU_NOT;
            OP_SHL: alu_op = ALU_SHL;
            OP_SHR: alu_op = ALU_SHR;
            default: alu_op = ALU_NOP;
        endcase
    end

    // ========================================================================
    // Sequential FSM — state transitions and control signal generation
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state        <= S_RESET;
            z_flag       <= 1'b0;
            ir_load      <= 1'b0;
            pc_inc       <= 1'b0;
            pc_load      <= 1'b0;
            push_en      <= 1'b0;
            pop_en       <= 1'b0;
            dup_en       <= 1'b0;
            swap_en      <= 1'b0;
            alu_wr_en    <= 1'b0;
            alu_unary_en <= 1'b0;
            in_en        <= 1'b0;
            out_en       <= 1'b0;
            halted       <= 1'b0;
        end else begin
            // Default: de-assert all control signals each cycle
            ir_load      <= 1'b0;
            pc_inc       <= 1'b0;
            pc_load      <= 1'b0;
            push_en      <= 1'b0;
            pop_en       <= 1'b0;
            dup_en       <= 1'b0;
            swap_en      <= 1'b0;
            alu_wr_en    <= 1'b0;
            alu_unary_en <= 1'b0;
            in_en        <= 1'b0;
            out_en       <= 1'b0;
            halted       <= 1'b0;

            case (state)
                // --------------------------------------------------------
                // S_RESET: Initialise (1 cycle), then move to FETCH
                // --------------------------------------------------------
                S_RESET: begin
                    state <= S_FETCH;
                end

                // --------------------------------------------------------
                // S_FETCH: Present PC address to ROM; PC <- PC + 1
                // ROM is synchronous: data appears next cycle (S_DECODE)
                // --------------------------------------------------------
                S_FETCH: begin
                    pc_inc <= 1'b1;
                    state  <= S_DECODE;
                end

                // --------------------------------------------------------
                // S_DECODE: Latch IR from ROM output (arrived this cycle)
                // TOS and NOS are available combinationally from stack
                // --------------------------------------------------------
                S_DECODE: begin
                    ir_load <= 1'b1;
                    state   <= S_EXECUTE;
                end

                // --------------------------------------------------------
                // S_EXECUTE: Opcode decode and control signal assertion
                // alu_op is already set combinationally, so ALU result
                // and zero_flag are valid when we latch z_flag here.
                // --------------------------------------------------------
                S_EXECUTE: begin
                    case (opcode)
                        // -- Stack operations --
                        OP_PUSH: begin
                            push_en <= 1'b1;
                        end

                        OP_POP: begin
                            pop_en <= 1'b1;
                        end

                        OP_DUP: begin
                            dup_en <= 1'b1;
                        end

                        OP_SWAP: begin
                            swap_en <= 1'b1;
                        end

                        // -- Binary ALU operations (consume TOS & NOS, push result) --
                        OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR: begin
                            alu_wr_en <= 1'b1;
                            z_flag    <= zero_flag;  // zero_flag is valid (alu_op set combinationally)
                        end

                        // -- Unary ALU operations (replace TOS) --
                        OP_NOT, OP_SHL, OP_SHR: begin
                            alu_unary_en <= 1'b1;
                            z_flag       <= zero_flag;
                        end

                        // -- Control flow --
                        OP_JMP: begin
                            pc_load <= 1'b1;
                        end

                        OP_JZ: begin
                            if (z_flag)
                                pc_load <= 1'b1;
                        end

                        OP_JNZ: begin
                            if (!z_flag)
                                pc_load <= 1'b1;
                        end

                        // -- I/O --
                        OP_OUT: begin
                            out_en <= 1'b1;
                        end

                        OP_IN: begin
                            in_en <= 1'b1;
                        end

                        // -- HALT --
                        OP_HALT: begin
                            halted <= 1'b1;
                            state  <= S_HALT;
                        end

                        default: begin
                            // Unknown opcode — treat as NOP
                        end
                    endcase

                    // All non-HALT instructions return to FETCH
                    if (opcode != OP_HALT)
                        state <= S_FETCH;
                end

                // --------------------------------------------------------
                // S_HALT: Freeze. Only a reset gets us out.
                // --------------------------------------------------------
                S_HALT: begin
                    halted <= 1'b1;
                    state  <= S_HALT;
                end

                default: begin
                    state <= S_RESET;
                end
            endcase
        end
    end

endmodule
