// ============================================================================
// CPU Top-Level Wrapper
//
// Instantiates all CPU modules and wires them together.
// Includes: 9-bit PC, 512-word ROM, return stack, data RAM,
//           extended ALU with C/N/V flags, 7-segment display.
//
// Targeting: Basys 3 / Artix-7 (xc7a35ticpg236-1L)
// ============================================================================

module cpu_top (
    input  wire        clk,        // 100 MHz board oscillator (W5)
    input  wire        rst,        // Active-high reset — center button (U18)
    input  wire [15:0] sw,         // 16 slide switches (IN instruction)
    output wire [15:0] led,        // 16 LEDs — output register display
    output wire [6:0]  seg,        // 7-segment cathode signals
    output wire [3:0]  an          // 7-segment anode signals
);

    // ========================================================================
    // Internal wires
    // ========================================================================

    // Clock enable
    wire cpu_clk_en;

    // Program Counter ↔ ROM / Control Unit
    wire [8:0] pc_out;             // 9-bit PC
    wire       pc_inc;
    wire       pc_load;

    // ROM → IR
    wire [15:0] rom_data;

    // IR output
    wire [15:0] ir_out;
    wire        ir_load;
    wire [6:0]  opcode;
    wire [8:0]  immediate;

    assign opcode    = ir_out[15:9];
    assign immediate = ir_out[8:0];

    // Stack ↔ ALU
    wire [15:0] tos, nos;
    wire [3:0]  sp;
    wire        stack_full, stack_empty, stack_has_two;

    // ALU signals
    wire [15:0] alu_result;
    wire        alu_zero, alu_carry, alu_neg, alu_overflow;
    wire [3:0]  alu_op;

    // Control signals
    wire push_en, pop_en, dup_en, swap_en;
    wire alu_wr_en, alu_unary_en;
    wire in_en, load_en, out_en;
    wire call_en, ret_en, ram_wr_en;
    wire halted, fault;

    // Return stack
    wire [8:0] ret_addr;
    wire       rs_full, rs_empty;

    // Data RAM
    wire [15:0] ram_data_out;

    // Output register
    wire [15:0] out_data;
    wire [15:0] display_value;

    // PC input mux: RET uses return stack address, everything else uses immediate
    wire [8:0] pc_in_mux = ret_en ? ret_addr : immediate;

    // ========================================================================
    // Module Instantiations
    // ========================================================================

    // --- Clock Divider ---
    clk_div #(
        .DIVISOR(25_000_000)
    ) u_clk_div (
        .clk    (clk),
        .rst    (rst),
        .clk_en (cpu_clk_en)
    );

    // --- Program Counter (9-bit) ---
    pc u_pc (
        .clk    (clk),
        .clk_en (cpu_clk_en),
        .rst    (rst),
        .pc_inc (pc_inc),
        .pc_load(pc_load),
        .pc_in  (pc_in_mux),
        .pc_out (pc_out)
    );

    // --- Instruction ROM (512 × 16-bit) ---
    instr_rom u_rom (
        .clk      (clk),
        .clk_en   (cpu_clk_en),
        .addr     (pc_out),
        .instr_out(rom_data)
    );

    // --- Instruction Register (16-bit) ---
    instr_reg u_ir (
        .clk      (clk),
        .clk_en   (cpu_clk_en),
        .rst      (rst),
        .ir_load  (ir_load),
        .instr_in (rom_data),
        .instr_out(ir_out)
    );

    // --- Control Unit (6-state FSM) ---
    control_unit u_ctrl (
        .clk          (clk),
        .clk_en       (cpu_clk_en),
        .rst          (rst),
        .opcode       (opcode),
        .immediate    (immediate),
        .zero_flag    (alu_zero),
        .carry_flag   (alu_carry),
        .neg_flag     (alu_neg),
        .overflow_flag(alu_overflow),
        .stack_full   (stack_full),
        .stack_empty  (stack_empty),
        .stack_has_two(stack_has_two),
        .tos          (tos),
        .nos          (nos),
        .in_value     (sw),
        .rs_full      (rs_full),
        .rs_empty     (rs_empty),
        .ram_data     (ram_data_out),
        .ir_load      (ir_load),
        .pc_inc       (pc_inc),
        .pc_load      (pc_load),
        .push_en      (push_en),
        .pop_en       (pop_en),
        .dup_en       (dup_en),
        .swap_en      (swap_en),
        .alu_wr_en    (alu_wr_en),
        .alu_unary_en (alu_unary_en),
        .in_en        (in_en),
        .load_en      (load_en),
        .alu_op       (alu_op),
        .out_en       (out_en),
        .call_en      (call_en),
        .ret_en       (ret_en),
        .ram_wr_en    (ram_wr_en),
        .halted       (halted),
        .fault        (fault)
    );

    // --- ALU (16-bit, combinational) ---
    alu u_alu (
        .a            (tos),
        .b            (nos),
        .alu_op       (alu_op),
        .result       (alu_result),
        .zero_flag    (alu_zero),
        .carry_flag   (alu_carry),
        .neg_flag     (alu_neg),
        .overflow_flag(alu_overflow)
    );

    // --- Stack Memory ---
    stack u_stack (
        .clk         (clk),
        .clk_en      (cpu_clk_en),
        .rst         (rst),
        .push_en     (push_en),
        .pop_en      (pop_en),
        .dup_en      (dup_en),
        .swap_en     (swap_en),
        .alu_wr_en   (alu_wr_en),
        .alu_unary_en(alu_unary_en),
        .in_en       (in_en),
        .load_en     (load_en),
        .imm_value   ({7'b0, immediate}),
        .alu_result  (alu_result),
        .sw_value    (sw),
        .ram_data    (ram_data_out),
        .tos         (tos),
        .nos         (nos),
        .sp          (sp),
        .stack_full  (stack_full),
        .stack_empty (stack_empty),
        .stack_has_two(stack_has_two)
    );

    // --- Return-Address Stack ---
    return_stack u_ret_stack (
        .clk       (clk),
        .clk_en    (cpu_clk_en),
        .rst       (rst),
        .push_en   (call_en),
        .pop_en    (ret_en),
        .push_addr (pc_out),          // Save current PC (already points past CALL)
        .top_addr  (ret_addr),
        .rs_full   (rs_full),
        .rs_empty  (rs_empty)
    );

    // --- Data RAM (256 × 16-bit) ---
    data_ram u_data_ram (
        .clk     (clk),
        .clk_en  (cpu_clk_en),
        .rst     (rst),
        .wr_en   (ram_wr_en),
        .addr    (immediate[7:0]),    // Lower 8 bits of immediate
        .data_in (tos),               // TOS value for STORE
        .data_out(ram_data_out)
    );

    // --- Output Register (16-bit) ---
    output_reg u_out_reg (
        .clk     (clk),
        .clk_en  (cpu_clk_en),
        .rst     (rst),
        .out_en  (out_en),
        .data_in (tos),
        .data_out(out_data)
    );

    // --- LED Output ---
    assign display_value = fault ? 16'hF17E : out_data;
    assign led = display_value;

    // --- 7-Segment Display Controller ---
    seg_display_controller u_seg_ctrl (
        .clk  (clk),
        .rst  (rst),
        .value(display_value),
        .seg  (seg),
        .an   (an)
    );

endmodule