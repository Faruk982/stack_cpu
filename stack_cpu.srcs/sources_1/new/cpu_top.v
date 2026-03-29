// ============================================================================
// CPU Top-Level Wrapper
//
// Instantiates all CPU modules and wires them together.
// Integrates with the 7-segment display controller for hex output.
//
// Targeting: Basys 3 / Artix-7 (xc7a35ticpg236-1L)
// ============================================================================

module cpu_top (
    input  wire        clk,        // 100 MHz board oscillator (W5)
    input  wire        rst,        // Active-high reset — center button (U18)
    input  wire [15:0] sw,         // 16 slide switches (optional IN instruction)
    output wire [15:0] led,        // 16 LEDs — output register display
    output wire [6:0]  seg,        // 7-segment cathode signals
    output wire [3:0]  an          // 7-segment anode signals
);

    // ========================================================================
    // Internal wires
    // ========================================================================

    // Clock divider → slow CPU clock
    wire cpu_clk;

    // Program Counter ↔ ROM / Control Unit
    wire [7:0] pc_out;
    wire       pc_inc;
    wire       pc_load;

    // ROM → IR
    wire [15:0] rom_data;

    // IR output (latched instruction)
    wire [15:0] ir_out;
    wire        ir_load;
    wire [6:0]  opcode;
    wire [8:0]  immediate;
    wire [7:0]  jump_addr;

    // Decode IR fields
    assign opcode    = ir_out[15:9];
    assign immediate = ir_out[8:0];
    assign jump_addr = ir_out[7:0];

    // Stack ↔ ALU
    wire [15:0] tos, nos;
    wire [3:0]  sp;
    wire        stack_full, stack_empty;

    // ALU signals
    wire [15:0] alu_result;
    wire        alu_zero;
    wire [3:0]  alu_op;

    // Control signals
    wire push_en, pop_en, dup_en, swap_en;
    wire alu_wr_en, alu_unary_en;
    wire in_en, out_en;
    wire halted;

    // Output register
    wire [15:0] out_data;

    // ========================================================================
    // Module Instantiations
    // ========================================================================

    // --- Clock Divider (100 MHz → ~2 Hz) ---
    clk_div #(
        .DIVISOR(25_000_000)        // 100M / (2*25M) = 2 Hz
    ) u_clk_div (
        .clk    (clk),
        .rst    (rst),
        .clk_out(cpu_clk)
    );

    // --- Program Counter (8-bit) ---
    pc u_pc (
        .clk    (cpu_clk),
        .rst    (rst),
        .pc_inc (pc_inc),
        .pc_load(pc_load),
        .pc_in  (jump_addr),
        .pc_out (pc_out)
    );

    // --- Instruction ROM (256 × 16-bit) ---
    instr_rom u_rom (
        .clk      (cpu_clk),
        .addr     (pc_out),
        .instr_out(rom_data)
    );

    // --- Instruction Register (16-bit) ---
    instr_reg u_ir (
        .clk      (cpu_clk),
        .rst      (rst),
        .ir_load  (ir_load),
        .instr_in (rom_data),
        .instr_out(ir_out)
    );

    // --- Control Unit (FSM) ---
    control_unit u_ctrl (
        .clk        (cpu_clk),
        .rst        (rst),
        .opcode     (opcode),
        .zero_flag  (alu_zero),
        .ir_load    (ir_load),
        .pc_inc     (pc_inc),
        .pc_load    (pc_load),
        .push_en    (push_en),
        .pop_en     (pop_en),
        .dup_en     (dup_en),
        .swap_en    (swap_en),
        .alu_wr_en  (alu_wr_en),
        .alu_unary_en(alu_unary_en),
        .in_en      (in_en),
        .alu_op     (alu_op),
        .out_en     (out_en),
        .halted     (halted)
    );

    // --- ALU (16-bit, combinational) ---
    alu u_alu (
        .a        (tos),
        .b        (nos),
        .alu_op   (alu_op),
        .result   (alu_result),
        .zero_flag(alu_zero)
    );

    // --- Stack Memory (16 × 16-bit) ---
    stack u_stack (
        .clk        (cpu_clk),
        .rst        (rst),
        .push_en    (push_en),
        .pop_en     (pop_en),
        .dup_en     (dup_en),
        .swap_en    (swap_en),
        .alu_wr_en  (alu_wr_en),
        .alu_unary_en(alu_unary_en),
        .in_en      (in_en),
        .imm_value  ({7'b0, immediate}),   // Zero-extend 9-bit immediate to 16-bit
        .alu_result (alu_result),
        .sw_value   (sw),
        .tos        (tos),
        .nos        (nos),
        .sp         (sp),
        .stack_full (stack_full),
        .stack_empty(stack_empty)
    );

    // --- Output Register (16-bit) ---
    output_reg u_out_reg (
        .clk     (cpu_clk),
        .rst     (rst),
        .out_en  (out_en),
        .data_in (tos),
        .data_out(out_data)
    );

    // --- LED Output ---
    assign led = out_data;

    // --- 7-Segment Display Controller (4-digit hexadecimal) ---
    // Runs on the fast 100 MHz clock for proper multiplexing refresh rate
    seg_display_controller u_seg_ctrl (
        .clk  (clk),              // 100 MHz for display refresh
        .value(out_data),         // 16-bit value from output register
        .seg  (seg),
        .an   (an)
    );

endmodule
