// ============================================================================
// ALU Testbench — Standalone Unit Test
//
// Verifies all 8 ALU operations with known input/output pairs.
// Checks result, zero_flag, carry_flag, neg_flag, and overflow_flag.
// ============================================================================

`timescale 1ns / 1ps

module alu_tb;

    reg  [15:0] a, b;
    reg  [3:0]  alu_op;
    wire [15:0] result;
    wire        zero_flag, carry_flag, neg_flag, overflow_flag;

    alu uut (
        .a            (a),
        .b            (b),
        .alu_op       (alu_op),
        .result       (result),
        .zero_flag    (zero_flag),
        .carry_flag   (carry_flag),
        .neg_flag     (neg_flag),
        .overflow_flag(overflow_flag)
    );

    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_NOT = 4'd5;
    localparam ALU_SHL = 4'd6;
    localparam ALU_SHR = 4'd7;

    integer pass_count;
    integer fail_count;

    initial begin
        pass_count = 0;
        fail_count = 0;
    end

    task check;
        input [15:0] exp_result;
        input        exp_zero;
        input        exp_carry;
        input        exp_neg;
        input        exp_ovf;
        input [63:0] op_name;
        begin
            #10;
            if (result === exp_result && zero_flag === exp_zero &&
                carry_flag === exp_carry && neg_flag === exp_neg &&
                overflow_flag === exp_ovf) begin
                $display("[PASS] %-8s | A=0x%04h B=0x%04h | R=0x%04h Z=%b C=%b N=%b V=%b",
                         op_name, a, b, result, zero_flag, carry_flag, neg_flag, overflow_flag);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %-8s | A=0x%04h B=0x%04h | Got R=0x%04h Z=%b C=%b N=%b V=%b | Exp R=0x%04h Z=%b C=%b N=%b V=%b",
                         op_name, a, b, result, zero_flag, carry_flag, neg_flag, overflow_flag,
                         exp_result, exp_zero, exp_carry, exp_neg, exp_ovf);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $display("==========================================================");
        $display(" ALU Unit Test (with C/N/V flags)");
        $display("==========================================================");
        $display("");

        // ----- ADD -----
        a = 16'h0005; b = 16'h0003; alu_op = ALU_ADD;
        check(16'h0008, 1'b0, 1'b0, 1'b0, 1'b0, "ADD     ");

        a = 16'hFFFF; b = 16'h0001; alu_op = ALU_ADD;
        check(16'h0000, 1'b1, 1'b1, 1'b0, 1'b0, "ADD(ZC) ");

        a = 16'h7FFF; b = 16'h0001; alu_op = ALU_ADD;
        check(16'h8000, 1'b0, 1'b0, 1'b1, 1'b1, "ADD(NV) ");

        // ----- SUB (b - a) -----
        a = 16'h0003; b = 16'h0005; alu_op = ALU_SUB;
        check(16'h0002, 1'b0, 1'b0, 1'b0, 1'b0, "SUB     ");

        a = 16'h0005; b = 16'h0005; alu_op = ALU_SUB;
        check(16'h0000, 1'b1, 1'b0, 1'b0, 1'b0, "SUB(Z)  ");

        a = 16'h0005; b = 16'h0003; alu_op = ALU_SUB;
        check(16'hFFFE, 1'b0, 1'b1, 1'b1, 1'b0, "SUB(CN) ");

        // ----- AND -----
        a = 16'hFF00; b = 16'h0F0F; alu_op = ALU_AND;
        check(16'h0F00, 1'b0, 1'b0, 1'b0, 1'b0, "AND     ");

        a = 16'hFF00; b = 16'h00FF; alu_op = ALU_AND;
        check(16'h0000, 1'b1, 1'b0, 1'b0, 1'b0, "AND(Z)  ");

        // ----- OR -----
        a = 16'hFF00; b = 16'h00FF; alu_op = ALU_OR;
        check(16'hFFFF, 1'b0, 1'b0, 1'b1, 1'b0, "OR(N)   ");

        // ----- XOR -----
        a = 16'hAAAA; b = 16'h5555; alu_op = ALU_XOR;
        check(16'hFFFF, 1'b0, 1'b0, 1'b1, 1'b0, "XOR(N)  ");

        a = 16'hAAAA; b = 16'hAAAA; alu_op = ALU_XOR;
        check(16'h0000, 1'b1, 1'b0, 1'b0, 1'b0, "XOR(Z)  ");

        // ----- NOT -----
        a = 16'hFF00; b = 16'h0000; alu_op = ALU_NOT;
        check(16'h00FF, 1'b0, 1'b0, 1'b0, 1'b0, "NOT     ");

        a = 16'hFFFF; b = 16'h0000; alu_op = ALU_NOT;
        check(16'h0000, 1'b1, 1'b0, 1'b0, 1'b0, "NOT(Z)  ");

        // ----- SHL (carry = old MSB) -----
        a = 16'h0001; b = 16'h0000; alu_op = ALU_SHL;
        check(16'h0002, 1'b0, 1'b0, 1'b0, 1'b0, "SHL     ");

        a = 16'h8000; b = 16'h0000; alu_op = ALU_SHL;
        check(16'h0000, 1'b1, 1'b1, 1'b0, 1'b0, "SHL(ZC) ");

        a = 16'hC000; b = 16'h0000; alu_op = ALU_SHL;
        check(16'h8000, 1'b0, 1'b1, 1'b1, 1'b0, "SHL(CN) ");

        // ----- SHR (carry = old LSB) -----
        a = 16'h0002; b = 16'h0000; alu_op = ALU_SHR;
        check(16'h0001, 1'b0, 1'b0, 1'b0, 1'b0, "SHR     ");

        a = 16'h0001; b = 16'h0000; alu_op = ALU_SHR;
        check(16'h0000, 1'b1, 1'b1, 1'b0, 1'b0, "SHR(ZC) ");

        // ----- Summary -----
        $display("");
        $display("==========================================================");
        $display(" Results: %0d PASSED, %0d FAILED out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("==========================================================");

        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" SOME TESTS FAILED");

        $finish;
    end

endmodule
