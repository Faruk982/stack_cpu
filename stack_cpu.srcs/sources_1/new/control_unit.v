// ============================================================================
// Control Unit — Hardwired 6-State FSM
//
// States: S_RESET, S_FETCH, S_DECODE, S_EXECUTE, S_HALT, S_FAULT
// ISA:    31 instructions (26 current + CMP, JE, JG, JNG, JS)
// Flags:  Z (zero), C (carry), N (negative), V (overflow)
// ============================================================================

module control_unit (
    input  wire       clk,
    input  wire       clk_en,
    input  wire       rst,

    // Instruction Register fields
    input  wire [6:0] opcode,
    input  wire [8:0] immediate,

    // ALU flags (combinational from ALU)
    input  wire       zero_flag,
    input  wire       carry_flag,
    input  wire       neg_flag,
    input  wire       overflow_flag,

    // Stack status
    input  wire        stack_full,
    input  wire        stack_empty,
    input  wire        stack_has_two,
    input  wire [15:0] tos,
    input  wire [15:0] nos,
    input  wire [15:0] in_value,

    // Return stack status
    input  wire        rs_full,
    input  wire        rs_empty,

    // Data RAM read value (for LOAD z_flag)
    input  wire [15:0] ram_data,

    // ---- Control signal outputs ----
    output reg        ir_load,
    output reg        pc_inc,
    output reg        pc_load,

    output reg        push_en,
    output reg        pop_en,
    output reg        dup_en,
    output reg        swap_en,
    output reg        alu_wr_en,
    output reg        alu_unary_en,
    output reg        in_en,
    output reg        load_en,       // LOAD: push RAM data to stack

    output reg [3:0]  alu_op,

    output reg        out_en,
    output reg        call_en,       // CALL: push PC to return stack
    output reg        ret_en,        // RET: pop return stack, load PC
    output reg        ram_wr_en,     // STORE: write TOS to data RAM
    output reg        halted,
    output reg        fault
);

    // ---- Opcode constants ----
    localparam OP_PUSH  = 7'h01;
    localparam OP_POP   = 7'h02;
    localparam OP_DUP   = 7'h03;
    localparam OP_SWAP  = 7'h04;
    localparam OP_ADD   = 7'h10;
    localparam OP_SUB   = 7'h11;
    localparam OP_AND   = 7'h12;
    localparam OP_OR    = 7'h13;
    localparam OP_XOR   = 7'h14;
    localparam OP_NOT   = 7'h15;
    localparam OP_SHL   = 7'h16;
    localparam OP_SHR   = 7'h17;
    localparam OP_CMP   = 7'h18;
    localparam OP_JMP   = 7'h20;
    localparam OP_JZ    = 7'h21;
    localparam OP_JNZ   = 7'h22;
    localparam OP_CALL  = 7'h23;
    localparam OP_RET   = 7'h24;
    localparam OP_LOAD  = 7'h25;
    localparam OP_STORE = 7'h26;
    localparam OP_JC    = 7'h27;
    localparam OP_JN    = 7'h28;
    localparam OP_JE    = 7'h29;
    localparam OP_JG    = 7'h2A;
    localparam OP_JNG   = 7'h2B;
    localparam OP_JS    = 7'h2C;
    localparam OP_OUT   = 7'h30;
    localparam OP_IN    = 7'h31;
    localparam OP_HALT  = 7'h3F;

    // ---- ALU operation codes (must match alu.v) ----
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

    // ---- FSM states ----
    localparam S_RESET   = 3'd0;
    localparam S_FETCH   = 3'd1;
    localparam S_DECODE  = 3'd2;
    localparam S_EXECUTE = 3'd3;
    localparam S_HALT    = 3'd4;
    localparam S_FAULT   = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Registered flags — updated after every relevant instruction
    reg z_flag;   // Zero:     updated by all TOS-modifying instructions
    reg c_flag;   // Carry:    updated by ALU operations only
    reg n_flag;   // Negative: updated by ALU operations only
    reg v_flag;   // Overflow: updated by ALU operations only

    // ========================================================================
    // Combinational ALU op decode
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
            OP_CMP: alu_op = ALU_CMP;
            default: alu_op = ALU_NOP;
        endcase
    end

    // ========================================================================
    // Next-state decode
    // ========================================================================
    always @(*) begin
        next_state = state;

        case (state)
            S_RESET: begin
                next_state = S_FETCH;
            end

            S_FETCH: begin
                next_state = S_DECODE;
            end

            S_DECODE: begin
                next_state = S_EXECUTE;
            end

            S_EXECUTE: begin
                case (opcode)
                    OP_PUSH:  next_state = stack_full    ? S_FAULT : S_FETCH;
                    OP_POP:   next_state = stack_empty   ? S_FAULT : S_FETCH;
                    OP_DUP:   next_state = stack_full    ? S_FAULT : S_FETCH;
                    OP_SWAP:  next_state = !stack_has_two ? S_FAULT : S_FETCH;

                    OP_ADD,
                    OP_SUB,
                    OP_AND,
                    OP_OR,
                    OP_XOR:   next_state = !stack_has_two ? S_FAULT : S_FETCH;

                    OP_NOT,
                    OP_SHL,
                    OP_SHR:   next_state = stack_empty   ? S_FAULT : S_FETCH;

                    OP_CMP:   next_state = !stack_has_two ? S_FAULT : S_FETCH;

                    OP_CALL:  next_state = rs_full       ? S_FAULT : S_FETCH;
                    OP_RET:   next_state = rs_empty      ? S_FAULT : S_FETCH;

                    OP_LOAD:  next_state = stack_full    ? S_FAULT : S_FETCH;
                    OP_STORE: next_state = stack_empty   ? S_FAULT : S_FETCH;

                    OP_HALT:  next_state = S_HALT;

                    default:  next_state = S_FETCH;
                endcase
            end

            S_HALT: begin
                next_state = S_HALT;
            end

            S_FAULT: begin
                next_state = S_FAULT;
            end

            default: begin
                next_state = S_RESET;
            end
        endcase
    end

    // ========================================================================
    // Combinational control output decode
    // ========================================================================
    always @(*) begin
        ir_load      = 1'b0;
        pc_inc       = 1'b0;
        pc_load      = 1'b0;
        push_en      = 1'b0;
        pop_en       = 1'b0;
        dup_en       = 1'b0;
        swap_en      = 1'b0;
        alu_wr_en    = 1'b0;
        alu_unary_en = 1'b0;
        in_en        = 1'b0;
        load_en      = 1'b0;
        out_en       = 1'b0;
        call_en      = 1'b0;
        ret_en       = 1'b0;
        ram_wr_en    = 1'b0;
        halted       = 1'b0;
        fault        = 1'b0;

        case (state)
            S_FETCH: begin
                pc_inc = 1'b1;
            end

            S_DECODE: begin
                ir_load = 1'b1;
            end

            S_EXECUTE: begin
                case (opcode)
                    OP_PUSH: begin
                        if (!stack_full)
                            push_en = 1'b1;
                    end

                    OP_POP: begin
                        if (!stack_empty)
                            pop_en = 1'b1;
                    end

                    OP_DUP: begin
                        if (!stack_full)
                            dup_en = 1'b1;
                    end

                    OP_SWAP: begin
                        if (stack_has_two)
                            swap_en = 1'b1;
                    end

                    OP_ADD,
                    OP_SUB,
                    OP_AND,
                    OP_OR,
                    OP_XOR: begin
                        if (stack_has_two)
                            alu_wr_en = 1'b1;
                    end

                    OP_NOT,
                    OP_SHL,
                    OP_SHR: begin
                        if (!stack_empty)
                            alu_unary_en = 1'b1;
                    end

                    OP_JMP: begin
                        pc_load = 1'b1;
                    end

                    OP_JZ: begin
                        if (z_flag)
                            pc_load = 1'b1;
                    end

                    OP_JNZ: begin
                        if (!z_flag)
                            pc_load = 1'b1;
                    end

                    OP_JC: begin
                        if (c_flag)
                            pc_load = 1'b1;
                    end

                    OP_JN: begin
                        if (n_flag)
                            pc_load = 1'b1;
                    end

                    OP_CALL: begin
                        if (!rs_full) begin
                            call_en = 1'b1;
                            pc_load = 1'b1;
                        end
                    end

                    OP_RET: begin
                        if (!rs_empty) begin
                            ret_en  = 1'b1;
                            pc_load = 1'b1;
                        end
                    end

                    OP_LOAD: begin
                        if (!stack_full)
                            load_en = 1'b1;
                    end

                    OP_STORE: begin
                        if (!stack_empty) begin
                            pop_en    = 1'b1;
                            ram_wr_en = 1'b1;
                        end
                    end

                    OP_OUT: begin
                        out_en = 1'b1;
                    end

                    OP_JE: begin
                        if (z_flag)
                            pc_load = 1'b1;
                    end

                    OP_JG: begin
                        if (!z_flag && (n_flag == v_flag))
                            pc_load = 1'b1;
                    end

                    OP_JNG: begin
                        if (z_flag || (n_flag != v_flag))
                            pc_load = 1'b1;
                    end

                    OP_JS: begin
                        if (n_flag)
                            pc_load = 1'b1;
                    end

                    OP_IN: begin
                        if (!stack_full)
                            in_en = 1'b1;
                    end

                    default: begin
                    end
                endcase
            end

            S_HALT: begin
                halted = 1'b1;
            end

            S_FAULT: begin
                fault = 1'b1;
            end

            default: begin
            end
        endcase
    end

    // ========================================================================
    // Sequential state and flag registers
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state  <= S_RESET;
            z_flag <= 1'b0;
            c_flag <= 1'b0;
            n_flag <= 1'b0;
            v_flag <= 1'b0;
        end else if (clk_en) begin
            state <= next_state;

            if (state == S_EXECUTE) begin
                case (opcode)
                    OP_PUSH: begin
                        if (!stack_full)
                            z_flag <= (immediate == 9'd0);
                    end

                    OP_POP: begin
                        if (!stack_empty)
                            z_flag <= (nos == 16'd0);
                    end

                    OP_DUP: begin
                        if (!stack_full)
                            z_flag <= (tos == 16'd0);
                    end

                    OP_SWAP: begin
                        if (stack_has_two)
                            z_flag <= (nos == 16'd0);
                    end

                    OP_ADD,
                    OP_SUB,
                    OP_AND,
                    OP_OR,
                    OP_XOR: begin
                        if (stack_has_two) begin
                            z_flag <= zero_flag;
                            c_flag <= carry_flag;
                            n_flag <= neg_flag;
                            v_flag <= overflow_flag;
                        end
                    end

                    OP_NOT,
                    OP_SHL,
                    OP_SHR: begin
                        if (!stack_empty) begin
                            z_flag <= zero_flag;
                            c_flag <= carry_flag;
                            n_flag <= neg_flag;
                            v_flag <= overflow_flag;
                        end
                    end

                    OP_LOAD: begin
                        if (!stack_full)
                            z_flag <= (ram_data == 16'd0);
                    end

                    OP_CMP: begin
                        if (stack_has_two) begin
                            z_flag <= zero_flag;
                            c_flag <= carry_flag;
                            n_flag <= neg_flag;
                            v_flag <= overflow_flag;
                        end
                    end

                    OP_STORE: begin
                        if (!stack_empty)
                            z_flag <= (nos == 16'd0);
                    end

                    OP_IN: begin
                        if (!stack_full)
                            z_flag <= (in_value == 16'd0);
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

endmodule