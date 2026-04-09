// ============================================================================
// CPU Testbench - Full System Integration Test (Multi-Program)
//
// Tests the complete stack-based CPU with 15 programs:
//   1. Countdown Loop (10 → 0)        — LED = 0x0000
//   2. Basic Arithmetic (5 + 3 = 8)   — LED = 0x0008
//   3. Bit Shift Demo (1 << 4 = 16)   — LED = 0x0010
//   4. CALL/RET Demo (double 5 = 10)  — LED = 0x000A
//   5. LOAD/STORE Demo (42+58 = 100)  — LED = 0x0064
//   6. JC Branch Demo                  — LED = 0x0001
//   7. JN Branch Demo                  — LED = 0x0001
//   8. POP Underflow Fault             — FAULT expected
//   9. RET Underflow Fault             — FAULT expected
//  10. CALL Overflow Fault             — FAULT expected
//  11. CMP + JE Demo                    — LED = 0x0001
//  12. CMP + JG Demo (signed)           — LED = 0x0001
//  13. CMP + JNG Demo (signed)          — LED = 0x0001
//  14. CMP + JS Demo                    — LED = 0x0001
//  15. CMP Underflow Fault              — FAULT expected
//
// Pure Verilog-2001 compatible (no SystemVerilog constructs).
// ============================================================================

`timescale 1ns / 1ps

module cpu_tb;

    reg         clk;
    reg         rst;
    reg  [15:0] sw;
    wire [15:0] led;
    wire [6:0]  seg;
    wire [3:0]  an;

    // --- Fast clock enable ---
    wire cpu_clk_en;

    clk_div #(.DIVISOR(2)) u_clk_div (
        .clk(clk), .rst(rst), .clk_en(cpu_clk_en)
    );

    // --- Internal wires ---
    wire [8:0]  pc_out;
    wire        pc_inc, pc_load;
    wire [15:0] rom_data, ir_out;
    wire        ir_load;
    wire [6:0]  opcode;
    wire [8:0]  immediate;

    assign opcode    = ir_out[15:9];
    assign immediate = ir_out[8:0];

    wire [15:0] tos, nos;
    wire [3:0]  sp;
    wire        stack_full, stack_empty, stack_has_two;
    wire [15:0] alu_result;
    wire        alu_zero, alu_carry, alu_neg, alu_overflow;
    wire [3:0]  alu_op;
    wire        push_en, pop_en, dup_en, swap_en;
    wire        alu_wr_en, alu_unary_en;
    wire        in_en, load_en, out_en;
    wire        call_en, ret_en, ram_wr_en;
    wire        halted, fault;
    wire [15:0] out_data;
    wire [8:0]  ret_addr;
    wire        rs_full, rs_empty;
    wire [15:0] ram_data_out;

    wire [8:0] pc_in_mux = ret_en ? ret_addr : immediate;

    // --- Module instances ---
    pc u_pc (
        .clk(clk), .clk_en(cpu_clk_en), .rst(rst),
        .pc_inc(pc_inc), .pc_load(pc_load),
        .pc_in(pc_in_mux), .pc_out(pc_out)
    );

    instr_rom u_rom (
        .clk(clk), .clk_en(cpu_clk_en),
        .addr(pc_out), .instr_out(rom_data)
    );

    instr_reg u_ir (
        .clk(clk), .clk_en(cpu_clk_en), .rst(rst),
        .ir_load(ir_load), .instr_in(rom_data), .instr_out(ir_out)
    );

    control_unit u_ctrl (
        .clk(clk), .clk_en(cpu_clk_en), .rst(rst),
        .opcode(opcode), .immediate(immediate),
        .zero_flag(alu_zero), .carry_flag(alu_carry),
        .neg_flag(alu_neg), .overflow_flag(alu_overflow),
        .stack_full(stack_full), .stack_empty(stack_empty),
        .stack_has_two(stack_has_two),
        .tos(tos), .nos(nos), .in_value(sw),
        .rs_full(rs_full), .rs_empty(rs_empty),
        .ram_data(ram_data_out),
        .ir_load(ir_load), .pc_inc(pc_inc), .pc_load(pc_load),
        .push_en(push_en), .pop_en(pop_en), .dup_en(dup_en),
        .swap_en(swap_en), .alu_wr_en(alu_wr_en),
        .alu_unary_en(alu_unary_en), .in_en(in_en), .load_en(load_en),
        .alu_op(alu_op), .out_en(out_en),
        .call_en(call_en), .ret_en(ret_en), .ram_wr_en(ram_wr_en),
        .halted(halted), .fault(fault)
    );

    alu u_alu (
        .a(tos), .b(nos), .alu_op(alu_op),
        .result(alu_result), .zero_flag(alu_zero),
        .carry_flag(alu_carry), .neg_flag(alu_neg),
        .overflow_flag(alu_overflow)
    );

    stack u_stack (
        .clk(clk), .clk_en(cpu_clk_en), .rst(rst),
        .push_en(push_en), .pop_en(pop_en), .dup_en(dup_en),
        .swap_en(swap_en), .alu_wr_en(alu_wr_en),
        .alu_unary_en(alu_unary_en), .in_en(in_en), .load_en(load_en),
        .imm_value({7'b0, immediate}), .alu_result(alu_result),
        .sw_value(sw), .ram_data(ram_data_out),
        .tos(tos), .nos(nos), .sp(sp),
        .stack_full(stack_full), .stack_empty(stack_empty),
        .stack_has_two(stack_has_two)
    );

    return_stack u_ret_stack (
        .clk(clk), .clk_en(cpu_clk_en), .rst(rst),
        .push_en(call_en), .pop_en(ret_en),
        .push_addr(pc_out), .top_addr(ret_addr),
        .rs_full(rs_full), .rs_empty(rs_empty)
    );

    data_ram u_data_ram (
        .clk(clk), .clk_en(cpu_clk_en), .rst(rst),
        .wr_en(ram_wr_en), .addr(immediate[7:0]),
        .data_in(tos), .data_out(ram_data_out)
    );

    output_reg u_out_reg (
        .clk(clk), .clk_en(cpu_clk_en), .rst(rst),
        .out_en(out_en), .data_in(tos), .data_out(out_data)
    );

    assign led = fault ? 16'hF17E : out_data;

    seg_display_controller u_seg_ctrl (
        .clk(clk), .rst(rst), .value(led), .seg(seg), .an(an)
    );

    // --- Clock ---
    initial clk = 0;
    always #5 clk = ~clk;

    integer test_pass;
    integer test_fail;
    reg     test_done;        // Flag: program finished (halt or fault)
    integer cycle_count;      // Timeout counter

    initial begin
        test_pass = 0;
        test_fail = 0;
    end

    // ========================================================================
    // load_program: write ROM contents for a given test
    // ========================================================================
    task load_program;
        input integer prog_id;
        integer i;
        begin
            for (i = 0; i < 512; i = i + 1)
                u_rom.rom[i] = 16'h7E00;

            case (prog_id)
                1: begin // Countdown 10->0
                    u_rom.rom[0] = 16'h020A;  // PUSH 10
                    u_rom.rom[1] = 16'h0600;  // DUP
                    u_rom.rom[2] = 16'h6000;  // OUT
                    u_rom.rom[3] = 16'h0400;  // POP
                    u_rom.rom[4] = 16'h0201;  // PUSH 1
                    u_rom.rom[5] = 16'h2200;  // SUB
                    u_rom.rom[6] = 16'h4401;  // JNZ 1
                    u_rom.rom[7] = 16'h6000;  // OUT
                    u_rom.rom[8] = 16'h7E00;  // HALT
                end
                2: begin // Arithmetic 5+3=8
                    u_rom.rom[0] = 16'h0205;  // PUSH 5
                    u_rom.rom[1] = 16'h0203;  // PUSH 3
                    u_rom.rom[2] = 16'h2000;  // ADD
                    u_rom.rom[3] = 16'h6000;  // OUT
                    u_rom.rom[4] = 16'h7E00;  // HALT
                end
                3: begin // Bit Shift 1<<4=16
                    u_rom.rom[0] = 16'h0201;  // PUSH 1
                    u_rom.rom[1] = 16'h2C00;  // SHL
                    u_rom.rom[2] = 16'h2C00;  // SHL
                    u_rom.rom[3] = 16'h2C00;  // SHL
                    u_rom.rom[4] = 16'h2C00;  // SHL
                    u_rom.rom[5] = 16'h6000;  // OUT
                    u_rom.rom[6] = 16'h7E00;  // HALT
                end
                4: begin // CALL/RET: double(5) = 10
                    u_rom.rom[0] = 16'h0205;  // PUSH 5
                    u_rom.rom[1] = 16'h4604;  // CALL 4
                    u_rom.rom[2] = 16'h6000;  // OUT     (LED = 10)
                    u_rom.rom[3] = 16'h7E00;  // HALT
                    // subroutine "double" at addr 4:
                    u_rom.rom[4] = 16'h0600;  // DUP
                    u_rom.rom[5] = 16'h2000;  // ADD
                    u_rom.rom[6] = 16'h4800;  // RET
                end
                5: begin // LOAD/STORE: 42+58=100 (0x0064)
                    u_rom.rom[0] = 16'h022A;  // PUSH 42
                    u_rom.rom[1] = 16'h4C00;  // STORE 0
                    u_rom.rom[2] = 16'h023A;  // PUSH 58
                    u_rom.rom[3] = 16'h4C01;  // STORE 1
                    u_rom.rom[4] = 16'h4A00;  // LOAD 0
                    u_rom.rom[5] = 16'h4A01;  // LOAD 1
                    u_rom.rom[6] = 16'h2000;  // ADD
                    u_rom.rom[7] = 16'h6000;  // OUT
                    u_rom.rom[8] = 16'h7E00;  // HALT
                end

                6: begin // JC branch demo
                    // PUSH 0; NOT => 0xFFFF
                    // PUSH 1; ADD => 0x0000 with carry=1
                    // JC target should branch to success path
                    u_rom.rom[0]  = 16'h0200;  // PUSH 0
                    u_rom.rom[1]  = 16'h2A00;  // NOT
                    u_rom.rom[2]  = 16'h0201;  // PUSH 1
                    u_rom.rom[3]  = 16'h2000;  // ADD
                    u_rom.rom[4]  = 16'h4E08;  // JC 8
                    u_rom.rom[5]  = 16'h0200;  // PUSH 0
                    u_rom.rom[6]  = 16'h6000;  // OUT
                    u_rom.rom[7]  = 16'h7E00;  // HALT
                    u_rom.rom[8]  = 16'h0201;  // PUSH 1
                    u_rom.rom[9]  = 16'h6000;  // OUT
                    u_rom.rom[10] = 16'h7E00;  // HALT
                end

                7: begin // JN branch demo
                    // PUSH 0; NOT => 0xFFFF with negative flag set
                    // JN target should branch to success path
                    u_rom.rom[0] = 16'h0200;  // PUSH 0
                    u_rom.rom[1] = 16'h2A00;  // NOT
                    u_rom.rom[2] = 16'h5006;  // JN 6
                    u_rom.rom[3] = 16'h0200;  // PUSH 0
                    u_rom.rom[4] = 16'h6000;  // OUT
                    u_rom.rom[5] = 16'h7E00;  // HALT
                    u_rom.rom[6] = 16'h0201;  // PUSH 1
                    u_rom.rom[7] = 16'h6000;  // OUT
                    u_rom.rom[8] = 16'h7E00;  // HALT
                end

                8: begin // POP underflow -> FAULT
                    u_rom.rom[0] = 16'h0400;  // POP
                    u_rom.rom[1] = 16'h7E00;  // HALT
                end

                9: begin // RET underflow -> FAULT
                    u_rom.rom[0] = 16'h4800;  // RET
                    u_rom.rom[1] = 16'h7E00;  // HALT
                end

                10: begin // CALL overflow -> FAULT when return stack is full
                    u_rom.rom[0] = 16'h4600;  // CALL 0
                end

                11: begin // CMP + JE branch demo
                    u_rom.rom[0] = 16'h0205;  // PUSH 5
                    u_rom.rom[1] = 16'h0205;  // PUSH 5
                    u_rom.rom[2] = 16'h3000;  // CMP
                    u_rom.rom[3] = 16'h5207;  // JE 7
                    u_rom.rom[4] = 16'h0200;  // PUSH 0
                    u_rom.rom[5] = 16'h6000;  // OUT
                    u_rom.rom[6] = 16'h7E00;  // HALT
                    u_rom.rom[7] = 16'h0201;  // PUSH 1
                    u_rom.rom[8] = 16'h6000;  // OUT
                    u_rom.rom[9] = 16'h7E00;  // HALT
                end

                12: begin // CMP + JG (signed) branch demo
                    // Compare NOS=2, TOS=-1. Signed greater should be true.
                    u_rom.rom[0]  = 16'h0202;  // PUSH 2
                    u_rom.rom[1]  = 16'h0200;  // PUSH 0
                    u_rom.rom[2]  = 16'h2A00;  // NOT -> 0xFFFF
                    u_rom.rom[3]  = 16'h3000;  // CMP
                    u_rom.rom[4]  = 16'h5408;  // JG 8
                    u_rom.rom[5]  = 16'h0200;  // PUSH 0
                    u_rom.rom[6]  = 16'h6000;  // OUT
                    u_rom.rom[7]  = 16'h7E00;  // HALT
                    u_rom.rom[8]  = 16'h0201;  // PUSH 1
                    u_rom.rom[9]  = 16'h6000;  // OUT
                    u_rom.rom[10] = 16'h7E00;  // HALT
                end

                13: begin // CMP + JNG (signed not-greater) branch demo
                    u_rom.rom[0] = 16'h0203;  // PUSH 3
                    u_rom.rom[1] = 16'h0203;  // PUSH 3
                    u_rom.rom[2] = 16'h3000;  // CMP
                    u_rom.rom[3] = 16'h5607;  // JNG 7
                    u_rom.rom[4] = 16'h0200;  // PUSH 0
                    u_rom.rom[5] = 16'h6000;  // OUT
                    u_rom.rom[6] = 16'h7E00;  // HALT
                    u_rom.rom[7] = 16'h0201;  // PUSH 1
                    u_rom.rom[8] = 16'h6000;  // OUT
                    u_rom.rom[9] = 16'h7E00;  // HALT
                end

                14: begin // CMP + JS branch demo
                    // Compare NOS=1, TOS=2 => -1, so sign should be set.
                    u_rom.rom[0] = 16'h0201;  // PUSH 1
                    u_rom.rom[1] = 16'h0202;  // PUSH 2
                    u_rom.rom[2] = 16'h3000;  // CMP
                    u_rom.rom[3] = 16'h5807;  // JS 7
                    u_rom.rom[4] = 16'h0200;  // PUSH 0
                    u_rom.rom[5] = 16'h6000;  // OUT
                    u_rom.rom[6] = 16'h7E00;  // HALT
                    u_rom.rom[7] = 16'h0201;  // PUSH 1
                    u_rom.rom[8] = 16'h6000;  // OUT
                    u_rom.rom[9] = 16'h7E00;  // HALT
                end

                15: begin // CMP underflow -> FAULT
                    u_rom.rom[0] = 16'h0201;  // PUSH 1
                    u_rom.rom[1] = 16'h3000;  // CMP
                end
            endcase
        end
    endtask

    // ========================================================================
    // wait_for_completion: poll until halt/fault or timeout
    // ========================================================================
    task wait_for_completion;
        begin
            test_done   = 1'b0;
            cycle_count = 0;
            while (!test_done && cycle_count < 5000) begin
                @(posedge clk);
                if (halted || fault)
                    test_done = 1'b1;
                cycle_count = cycle_count + 1;
            end
            #100;  // Let settling happen
        end
    endtask

    // ========================================================================
    // run_and_expect_fault
    // ========================================================================
    task run_and_expect_fault;
        input integer       prog_id;
        input [8*24-1:0]    prog_name;
        begin
            $display("");
            $display("========== Testing: %0s ==========", prog_name);

            load_program(prog_id);
            rst = 1;
            #200;
            rst = 0;

            wait_for_completion;

            if (fault) begin
                $display(" [PASS] %0s -- FAULT observed as expected", prog_name);
                test_pass = test_pass + 1;
            end else begin
                $display(" [FAIL] %0s -- expected FAULT but got HALT/timeout", prog_name);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // ========================================================================
    // run_and_check
    // ========================================================================
    task run_and_check;
        input integer       prog_id;
        input [15:0]        expected_led;
        input [8*24-1:0]    prog_name;
        begin
            $display("");
            $display("========== Testing: %0s ==========", prog_name);

            load_program(prog_id);
            rst = 1;
            #200;
            rst = 0;

            wait_for_completion;

            if (fault) begin
                $display(" [FAIL] %0s -- FAULT (stack overflow/underflow)", prog_name);
                test_fail = test_fail + 1;
            end else if (!halted) begin
                $display(" [FAIL] %0s -- did not halt (timeout)", prog_name);
                test_fail = test_fail + 1;
            end else if (led === expected_led) begin
                $display(" [PASS] %0s -- LED=0x%04h (expected 0x%04h)", prog_name, led, expected_led);
                test_pass = test_pass + 1;
            end else begin
                $display(" [FAIL] %0s -- LED=0x%04h (expected 0x%04h)", prog_name, led, expected_led);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // --- Monitor ---
    always @(posedge clk) begin
        if (cpu_clk_en && !rst) begin
            #1;
            $display("%8t | PC=0x%03h IR=0x%04h SP=%2d TOS=0x%04h LED=0x%04h H=%b F=%b St=%0d",
                     $time, pc_out, ir_out, sp, tos, led, halted, fault, u_ctrl.state);
        end
    end

    // --- Main Test ---
    initial begin
        $display("==========================================================");
        $display(" Stack CPU -- Multi-Program Integration Testbench");
        $display("==========================================================");

        rst = 1; sw = 16'h0000; #100;

        run_and_check(1, 16'h0000, "Countdown 10->0     ");
        run_and_check(2, 16'h0008, "Arithmetic 5+3=8    ");
        run_and_check(3, 16'h0010, "Bit Shift 1<<4=16   ");
        run_and_check(4, 16'h000A, "CALL/RET double(5)  ");
        run_and_check(5, 16'h0064, "LOAD/STORE 42+58    ");
        run_and_check(6, 16'h0001, "JC branch demo      ");
        run_and_check(7, 16'h0001, "JN branch demo      ");
        run_and_expect_fault(8,  "POP underflow fault ");
        run_and_expect_fault(9,  "RET underflow fault ");
        run_and_expect_fault(10, "CALL overflow fault ");
        run_and_check(11, 16'h0001, "CMP+JE branch demo  ");
        run_and_check(12, 16'h0001, "CMP+JG branch demo  ");
        run_and_check(13, 16'h0001, "CMP+JNG branch demo ");
        run_and_check(14, 16'h0001, "CMP+JS branch demo  ");
        run_and_expect_fault(15, "CMP underflow fault ");

        $display("");
        $display("==========================================================");
        $display(" RESULTS: %0d PASSED, %0d FAILED out of %0d tests",
                 test_pass, test_fail, test_pass + test_fail);
        $display("==========================================================");

        if (test_fail == 0) $display(" ALL TESTS PASSED");
        else                $display(" SOME TESTS FAILED");

        $display("");
        $finish;
    end

    // --- Global timeout ---
    initial begin
        #300000;
        $display(" [TIMEOUT] Global 300 us exceeded.");
        $finish;
    end

endmodule
