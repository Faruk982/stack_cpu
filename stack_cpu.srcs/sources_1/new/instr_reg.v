// ============================================================================
// Instruction Register (IR) — 16-bit
// Latches the instruction word from ROM on the rising clock edge when
// ir_load is asserted (during S_FETCH).
//
// IR[15:9] = opcode  (7 bits)  → fed to Control Unit
// IR[8:0]  = immediate (9 bits) → fed to Stack (PUSH) / PC (JMP)
// ============================================================================

module instr_reg (
    input  wire        clk,         // System clock
    input  wire        rst,         // Active-high synchronous reset
    input  wire        ir_load,     // Load enable (asserted in S_FETCH)
    input  wire [15:0] instr_in,    // Instruction from ROM
    output reg  [15:0] instr_out    // Latched instruction
);

    always @(posedge clk) begin
        if (rst) begin
            instr_out <= 16'd0;
        end else if (ir_load) begin
            instr_out <= instr_in;
        end
        // else: hold current instruction
    end

endmodule
