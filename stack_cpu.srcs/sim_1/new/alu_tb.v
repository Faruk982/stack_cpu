// ============================================================================
// ALU Testbench — Standalone Unit Test
//
// Verifies all 8 ALU operations with known input/output pairs.
// Checks both result and zero_flag.
// ============================================================================

`timescale 1ns / 1ps

module alu_tb;

    // Signals
    reg  [15:0] a, b;
    reg  [3:0]  alu_op;
    wire [15:0] result;
    wire        zero_flag;

    // Instantiate ALU
    alu uut (
        .a        (a),
        .b        (b),
        .alu_op   (alu_op),
        .result   (result),
        .zero_flag(zero_flag)
    );

    // ALU op codes
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_NOT = 4'd5;
    localparam ALU_SHL = 4'd6;
    localparam ALU_SHR = 4'd7;

    // Test counter
    integer pass_count = 0;
    integer fail_count = 0;

    // Verify task
    task check;
        input [15:0] expected_result;
        input        expected_zero;
        input [63:0] op_name;  // 8-char string
        begin
            #10;  // Wait for combinational settle
            if (result === expected_result && zero_flag === expected_zero) begin
                $display("[PASS] %-6s | A=0x%04h B=0x%04h | Result=0x%04h Z=%b",
                         op_name, a, b, result, zero_flag);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %-6s | A=0x%04h B=0x%04h | Got=0x%04h Z=%b | Expected=0x%04h Z=%b",
                         op_name, a, b, result, zero_flag, expected_result, expected_zero);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Test sequence
    initial begin
        $display("==========================================================");
        $display(" ALU Unit Test");
        $display("==========================================================");
        $display("");

        // ----- ADD -----
        a = 16'h0005; b = 16'h0003; alu_op = ALU_ADD;
        check(16'h0008, 1'b0, "ADD   ");

        a = 16'hFFFF; b = 16'h0001; alu_op = ALU_ADD;
        check(16'h0000, 1'b1, "ADD(Z)");

        // ----- SUB -----
        a = 16'h0003; b = 16'h0005; alu_op = ALU_SUB;
        check(16'h0002, 1'b0, "SUB   ");

        a = 16'h0005; b = 16'h0005; alu_op = ALU_SUB;
        check(16'h0000, 1'b1, "SUB(Z)");

        // ----- AND -----
        a = 16'hFF00; b = 16'h0F0F; alu_op = ALU_AND;
        check(16'h0F00, 1'b0, "AND   ");

        a = 16'hFF00; b = 16'h00FF; alu_op = ALU_AND;
        check(16'h0000, 1'b1, "AND(Z)");

        // ----- OR -----
        a = 16'hFF00; b = 16'h00FF; alu_op = ALU_OR;
        check(16'hFFFF, 1'b0, "OR    ");

        // ----- XOR -----
        a = 16'hAAAA; b = 16'h5555; alu_op = ALU_XOR;
        check(16'hFFFF, 1'b0, "XOR   ");

        a = 16'hAAAA; b = 16'hAAAA; alu_op = ALU_XOR;
        check(16'h0000, 1'b1, "XOR(Z)");

        // ----- NOT -----
        a = 16'hFF00; b = 16'h0000; alu_op = ALU_NOT;
        check(16'h00FF, 1'b0, "NOT   ");

        a = 16'hFFFF; b = 16'h0000; alu_op = ALU_NOT;
        check(16'h0000, 1'b1, "NOT(Z)");

        // ----- SHL -----
        a = 16'h0001; b = 16'h0000; alu_op = ALU_SHL;
        check(16'h0002, 1'b0, "SHL   ");

        a = 16'h8000; b = 16'h0000; alu_op = ALU_SHL;
        check(16'h0000, 1'b1, "SHL(Z)");

        // ----- SHR -----
        a = 16'h0002; b = 16'h0000; alu_op = ALU_SHR;
        check(16'h0001, 1'b0, "SHR   ");

        a = 16'h0001; b = 16'h0000; alu_op = ALU_SHR;
        check(16'h0000, 1'b1, "SHR(Z)");

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
