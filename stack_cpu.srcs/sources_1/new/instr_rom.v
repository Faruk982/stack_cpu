// ============================================================================
// Instruction ROM — 256 × 16-bit
// Read-only program memory, addressed by Program Counter.
// Synchronous read: output updates on rising clock edge.
//
// Instruction format:  [15:9] = opcode (7 bits)
//                      [8:0]  = immediate (9 bits)
//
// Opcode encoding:
//   PUSH  = 7'h01    POP  = 7'h02    DUP  = 7'h03    SWAP = 7'h04
//   ADD   = 7'h10    SUB  = 7'h11    AND  = 7'h12    OR   = 7'h13
//   XOR   = 7'h14    NOT  = 7'h15    SHL  = 7'h16    SHR  = 7'h17
//   JMP   = 7'h20    JZ   = 7'h21    JNZ  = 7'h22
//   OUT   = 7'h30    IN   = 7'h31
//   HALT  = 7'h3F
// ============================================================================

module instr_rom (
    input  wire       clk,           // System clock
    input  wire [7:0] addr,          // Address from PC
    output reg [15:0] instr_out      // 16-bit instruction word
);

    // Internal ROM storage
    reg [15:0] rom [0:255];

    // Synchronous read
    always @(posedge clk) begin
        instr_out <= rom[addr];
    end

    // ========================================================================
    // Helper macros for instruction encoding
    // Instruction = {opcode[6:0], immediate[8:0]}
    // ========================================================================
    // PUSH imm  : {7'h01, imm[8:0]}   = (7'h01 << 9) | imm
    // POP       : {7'h02, 9'h000}     = 16'h0400
    // DUP       : {7'h03, 9'h000}     = 16'h0600
    // SWAP      : {7'h04, 9'h000}     = 16'h0800
    // ADD       : {7'h10, 9'h000}     = 16'h2000
    // SUB       : {7'h11, 9'h000}     = 16'h2200
    // AND       : {7'h12, 9'h000}     = 16'h2400
    // OR        : {7'h13, 9'h000}     = 16'h2600
    // XOR       : {7'h14, 9'h000}     = 16'h2800
    // NOT       : {7'h15, 9'h000}     = 16'h2A00
    // SHL       : {7'h16, 9'h000}     = 16'h2C00
    // SHR       : {7'h17, 9'h000}     = 16'h2E00
    // JMP addr  : {7'h20, 1'b0, addr} = (7'h20 << 9) | addr
    // JZ  addr  : {7'h21, 1'b0, addr} = (7'h21 << 9) | addr
    // JNZ addr  : {7'h22, 1'b0, addr} = (7'h22 << 9) | addr
    // OUT       : {7'h30, 9'h000}     = 16'h6000
    // IN        : {7'h31, 9'h000}     = 16'h6200
    // HALT      : {7'h3F, 9'h000}     = 16'h7E00

    // ========================================================================
    // Program Initialization
    // ========================================================================
    initial begin : rom_init
        integer i;
        // Clear entire ROM
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 16'h7E00;  // HALT (safe default)

        // ==================================================================
        // DEFAULT PROGRAM: Program 2 — Countdown Loop (10 → 0)
        // Counts from 10 down to 0, outputs each value on LEDs.
        //
        // Stack trace per iteration (steady state):
        //   Addr 0: PUSH 10  → stack: [10]
        //   Loop start (addr 1):
        //     1: DUP     → [count, count]
        //     2: OUT     → [count, count]   LED = count (OUT reads TOS, no pop)
        //     3: POP     → [count]          discard dup'd copy
        //     4: PUSH 1  → [count, 1]
        //     5: SUB     → [count-1]        Z flag set if result==0
        //     6: JNZ 1   → loop if Z==0 (i.e. count-1 != 0)
        //   Z flag checks the SUB result, so no DUP needed before JNZ.
        //   Fall through when count reaches 0:
        //     7: OUT     → LED = 0
        //     8: HALT
        // ==================================================================
        rom[0]  = 16'h020A;   // PUSH 10       stack: [10]
        rom[1]  = 16'h0600;   // DUP           stack: [count, count]
        rom[2]  = 16'h6000;   // OUT           LED = count
        rom[3]  = 16'h0400;   // POP           stack: [count]  (discard OUT copy)
        rom[4]  = 16'h0201;   // PUSH 1        stack: [count, 1]
        rom[5]  = 16'h2200;   // SUB           stack: [count-1], Z=(count-1==0)
        rom[6]  = 16'h4401;   // JNZ 1         loop if Z==0
        rom[7]  = 16'h6000;   // OUT           LED = 0 (display final zero)
        rom[8]  = 16'h7E00;   // HALT

        // ==================================================================
        // ALTERNATIVE: Program 1 — Basic Arithmetic (5 + 3 = 8)
        // Uncomment below and comment out the default program above.
        // ==================================================================
        // rom[0] = 16'h0205;  // PUSH 5
        // rom[1] = 16'h0203;  // PUSH 3
        // rom[2] = 16'h2000;  // ADD
        // rom[3] = 16'h6000;  // OUT       LED = 0x0008
        // rom[4] = 16'h7E00;  // HALT

        // ==================================================================
        // ALTERNATIVE: Program 3 — Bit Shift Demo (1 << 4 = 16)
        // ==================================================================
        // rom[0] = 16'h0201;  // PUSH 1
        // rom[1] = 16'h2C00;  // SHL
        // rom[2] = 16'h2C00;  // SHL
        // rom[3] = 16'h2C00;  // SHL
        // rom[4] = 16'h2C00;  // SHL
        // rom[5] = 16'h6000;  // OUT       LED = 0x0010
        // rom[6] = 16'h7E00;  // HALT
    end

endmodule
