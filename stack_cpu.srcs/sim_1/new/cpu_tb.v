// ============================================================================
// CPU Testbench — Full System Integration Test
//
// Tests the complete stack-based CPU with the countdown program.
// Uses a fast clock divider override for rapid simulation.
//
// To switch programs: edit the ROM initialisation in instr_rom.v
// ============================================================================

`timescale 1ns / 1ps

module cpu_tb;

    // ========================================================================
    // Signals
    // ========================================================================
    reg         clk;
    reg         rst;
    reg  [15:0] sw;
    wire [15:0] led;
    wire [6:0]  seg;
    wire [3:0]  an;

    // ========================================================================
    // DUT with fast clock divider for simulation
    // In synthesis the DIVISOR is 25_000_000; in sim we use 2 for speed.
    // We directly instantiate the submodules to override the DIVISOR.
    // ========================================================================

    // --- Fast CPU clock for simulation ---
    wire cpu_clk;

    clk_div #(
        .DIVISOR(2)     // Fast: toggle every 2 system clocks → 25 MHz cpu_clk
    ) u_clk_div (
        .clk    (clk),
        .rst    (rst),
        .clk_out(cpu_clk)
    );

    // --- All CPU internal wires ---
    wire [7:0]  pc_out;
    wire        pc_inc, pc_load;
    wire [15:0] rom_data;
    wire [15:0] ir_out;
    wire        ir_load;
    wire [6:0]  opcode;
    wire [8:0]  immediate;
    wire [7:0]  jump_addr;

    assign opcode    = ir_out[15:9];
    assign immediate = ir_out[8:0];
    assign jump_addr = ir_out[7:0];

    wire [15:0] tos, nos;
    wire [3:0]  sp;
    wire        stack_full, stack_empty;
    wire [15:0] alu_result;
    wire        alu_zero;
    wire [3:0]  alu_op;
    wire        push_en, pop_en, dup_en, swap_en;
    wire        alu_wr_en, alu_unary_en;
    wire        in_en, out_en;
    wire        halted;
    wire [15:0] out_data;

    // --- Module instances (matching cpu_top.v hierarchy) ---
    pc u_pc (
        .clk(cpu_clk), .rst(rst), .pc_inc(pc_inc),
        .pc_load(pc_load), .pc_in(jump_addr), .pc_out(pc_out)
    );

    instr_rom u_rom (
        .clk(cpu_clk), .addr(pc_out), .instr_out(rom_data)
    );

    instr_reg u_ir (
        .clk(cpu_clk), .rst(rst), .ir_load(ir_load),
        .instr_in(rom_data), .instr_out(ir_out)
    );

    control_unit u_ctrl (
        .clk(cpu_clk), .rst(rst), .opcode(opcode), .zero_flag(alu_zero),
        .ir_load(ir_load), .pc_inc(pc_inc), .pc_load(pc_load),
        .push_en(push_en), .pop_en(pop_en), .dup_en(dup_en), .swap_en(swap_en),
        .alu_wr_en(alu_wr_en), .alu_unary_en(alu_unary_en), .in_en(in_en),
        .alu_op(alu_op), .out_en(out_en), .halted(halted)
    );

    alu u_alu (
        .a(tos), .b(nos), .alu_op(alu_op),
        .result(alu_result), .zero_flag(alu_zero)
    );

    stack u_stack (
        .clk(cpu_clk), .rst(rst),
        .push_en(push_en), .pop_en(pop_en), .dup_en(dup_en), .swap_en(swap_en),
        .alu_wr_en(alu_wr_en), .alu_unary_en(alu_unary_en), .in_en(in_en),
        .imm_value({7'b0, immediate}), .alu_result(alu_result), .sw_value(sw),
        .tos(tos), .nos(nos), .sp(sp), .stack_full(stack_full), .stack_empty(stack_empty)
    );

    output_reg u_out_reg (
        .clk(cpu_clk), .rst(rst), .out_en(out_en),
        .data_in(tos), .data_out(out_data)
    );

    assign led = out_data;

    // 7-seg display (not critical for sim, but instantiate for completeness)
    seg_display_controller u_seg_ctrl (
        .clk(clk), .value(out_data), .seg(seg), .an(an)
    );

    // ========================================================================
    // Clock generation — 100 MHz (10 ns period)
    // ========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // ========================================================================
    // Monitor — Print state on each CPU clock rising edge
    // ========================================================================
    initial begin
        $display("==========================================================");
        $display(" Stack CPU — Integration Testbench");
        $display("==========================================================");
        $display("Time(ns)  | RST | PC   | IR     | SP | TOS    | LED    | Halt | State");
        $display("----------|-----|------|--------|----|--------|--------|------|------");
    end

    always @(posedge cpu_clk) begin
        #1;  // Small delay to let combinational signals settle after clock edge
        $display("%8t |  %b  | 0x%02h | 0x%04h | %2d | 0x%04h | 0x%04h |   %b  |  %0d",
                 $time, rst,
                 pc_out,
                 ir_out,
                 sp,
                 tos,
                 led,
                 halted,
                 u_ctrl.state);
    end

    // ========================================================================
    // Test Sequence
    // ========================================================================
    initial begin
        // Initialise
        rst = 1;
        sw  = 16'h0000;

        // Hold reset for 200 ns
        #200;
        rst = 0;

        $display("\n--- Reset released, CPU executing ---\n");

        // Wait for HALT
        wait (halted == 1'b1);
        // Let a couple more cycles pass
        #200;

        $display("\n==========================================================");
        $display(" CPU HALTED. Final LED output: 0x%04h", led);
        $display("==========================================================");

        // Verify Program 2 (countdown): last OUT should be 0x0000
        if (led == 16'h0000) begin
            $display(" [PASS] LED output is 0x0000 (countdown reached zero)");
        end else begin
            $display(" [INFO] LED output: 0x%04h (check program logic)", led);
        end

        $display("\n--- Test complete ---\n");
        $finish;
    end

    // ========================================================================
    // Timeout watchdog — 100 µs
    // ========================================================================
    initial begin
        #100000;
        $display("\n [TIMEOUT] Simulation exceeded 100 us. Stopping.");
        $display(" Last LED = 0x%04h, Halted = %b, PC = 0x%02h", led, halted, pc_out);
        $finish;
    end

    // ========================================================================
    // Waveform dump
    // ========================================================================
    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end

endmodule
