// ============================================================================
// Instruction ROM — 512 × 16-bit
// Read-only program memory, addressed by 9-bit Program Counter.
// Synchronous read: output updates on rising clock edge when clk_en is high.
//
// Instruction format:  [15:9] = opcode (7 bits)
//                      [8:0]  = immediate (9 bits)
//
// Opcode encoding:
//   PUSH  = 7'h01    POP   = 7'h02    DUP   = 7'h03    SWAP  = 7'h04
//   ADD   = 7'h10    SUB   = 7'h11    AND   = 7'h12    OR    = 7'h13
//   XOR   = 7'h14    NOT   = 7'h15    SHL   = 7'h16    SHR   = 7'h17    CMP   = 7'h18
//   JMP   = 7'h20    JZ    = 7'h21    JNZ   = 7'h22
//   CALL  = 7'h23    RET   = 7'h24
//   LOAD  = 7'h25    STORE = 7'h26
//   JC    = 7'h27    JN    = 7'h28    JE    = 7'h29    JG    = 7'h2A
//   JNG   = 7'h2B    JS    = 7'h2C
//   OUT   = 7'h30    IN    = 7'h31
//   HALT  = 7'h3F
// ============================================================================

module instr_rom (
    input  wire       clk,
    input  wire       clk_en,
    input  wire [8:0] addr,
    output reg [15:0] instr_out
);

    reg [15:0] rom [0:511];

    always @(posedge clk) begin
        if (clk_en)
            instr_out <= rom[addr];
    end

    // ========================================================================
    // Instruction encoding helper:
    //   Encoding = (opcode << 9) | immediate
    //
    //   PUSH imm  : 16'h0200 | imm      POP      : 16'h0400
    //   DUP       : 16'h0600            SWAP     : 16'h0800
    //   ADD       : 16'h2000            SUB      : 16'h2200
    //   AND       : 16'h2400            OR       : 16'h2600
    //   XOR       : 16'h2800            NOT      : 16'h2A00
    //   SHL       : 16'h2C00            SHR      : 16'h2E00            CMP      : 16'h3000
    //   JMP addr  : 16'h4000 | addr     JZ addr  : 16'h4200 | addr
    //   JNZ addr  : 16'h4400 | addr
    //   CALL addr : 16'h4600 | addr     RET      : 16'h4800
    //   LOAD addr : 16'h4A00 | addr     STORE adr: 16'h4C00 | addr
    //   JC addr   : 16'h4E00 | addr     JN addr  : 16'h5000 | addr
    //   JE addr   : 16'h5200 | addr     JG addr  : 16'h5400 | addr
    //   JNG addr  : 16'h5600 | addr     JS addr  : 16'h5800 | addr
    //   OUT       : 16'h6000            IN       : 16'h6200
    //   HALT      : 16'h7E00
    // ========================================================================

    initial begin : rom_init
        integer i;
        for (i = 0; i < 512; i = i + 1)
            rom[i] = 16'h7E00;  // HALT (safe default)

        // ===================================================================
        // ACTIVE PROGRAM: Recurring Countdown Loop via Subroutine
        // ===================================================================

        // Main loop
        rom[0]  = 16'h4604;  // CALL 4
        rom[1]  = 16'h4000;  // JMP 0

        // Subroutine: countdown_10_to_0 at addr 4
        // rom[4]  = 16'h020A;  // PUSH 10
        // rom[5]  = 16'h0600;  // DUP
        // rom[6]  = 16'h6000;  // OUT
        // rom[7]  = 16'h0400;  // POP
        // rom[8]  = 16'h0201;  // PUSH 1
        // rom[9]  = 16'h2200;  // SUB
        // rom[10] = 16'h4405;  // JNZ 5   (loop back to DUP/OUT path)
        // rom[11] = 16'h6000;  // OUT      (show 0)
        // rom[12] = 16'h0400;  // POP      (clean final 0 from stack)
        // rom[13] = 16'h4800;  // RET

        // ==================================================================
        // ALTERNATIVE: Two-Input Add from Slide Switches (IN demo)
        // ==================================================================
        // rom[0] = 16'h6200;   // IN
        // rom[1] = 16'h6200;   // IN
        // rom[2] = 16'h2000;   // ADD
        // rom[3] = 16'h6000;   // OUT
        // rom[4] = 16'h7E00;   // HALT

        // ==================================================================
        // ALTERNATIVE: Three-Input Add from Slide Switches
        //   Read three values via IN and display sum = in1 + in2 + in3
        // ==================================================================
        rom[0] = 16'h6200;   // IN   (in1)
        rom[1] = 16'h6200;   // IN   (in2)
        rom[2] = 16'h2000;   // ADD  -> (in1 + in2)
        rom[3] = 16'h6200;   // IN   (in3)
        rom[4] = 16'h2000;   // ADD  -> (in1 + in2 + in3)
        rom[5] = 16'h6000;   // OUT
        rom[6] = 16'h7E00;   // HALT

        // ==================================================================
        // ALTERNATIVE: Program 1 — Basic Arithmetic (5 + 3 = 8)
        // ==================================================================
        // rom[0] = 16'h0205;  // PUSH 5
        // rom[1] = 16'h0203;  // PUSH 3
        // rom[2] = 16'h2000;  // ADD
        // rom[3] = 16'h6000;  // OUT
        // rom[4] = 16'h7E00;  // HALT

        // ==================================================================
        // ALTERNATIVE: Program 3 — Bit Shift Demo (1 << 4 = 16 = 0x0010)
        // ==================================================================
        // rom[0] = 16'h0201;  // PUSH 1
        // rom[1] = 16'h2C00;  // SHL
        // rom[2] = 16'h2C00;  // SHL
        // rom[3] = 16'h2C00;  // SHL
        // rom[4] = 16'h2C00;  // SHL
        // rom[5] = 16'h6000;  // OUT
        // rom[6] = 16'h7E00;  // HALT

        // ==================================================================
        // ALTERNATIVE: Program 4 — CALL/RET Demo (double via subroutine)
        //   Main calls "double" subroutine to compute 5*2 = 10
        // ==================================================================
        // rom[0] = 16'h0205;  // PUSH 5
        // rom[1] = 16'h4604;  // CALL 4     (subroutine at addr 4)
        // rom[2] = 16'h6000;  // OUT        LED = 10
        // rom[3] = 16'h7E00;  // HALT
        // // subroutine "double" at address 4:
        // rom[4] = 16'h0600;  // DUP
        // rom[5] = 16'h2000;  // ADD
        // rom[6] = 16'h4800;  // RET

        // ==================================================================
        // ALTERNATIVE: Program 5 — LOAD/STORE Demo
        //   Store 42 and 58, load back and add → 100 (0x0064)
        // ==================================================================
        // rom[0] = 16'h022A;  // PUSH 42
        // rom[1] = 16'h4C00;  // STORE 0
        // rom[2] = 16'h023A;  // PUSH 58
        // rom[3] = 16'h4C01;  // STORE 1
        // rom[4] = 16'h4A00;  // LOAD 0
        // rom[5] = 16'h4A01;  // LOAD 1
        // rom[6] = 16'h2000;  // ADD
        // rom[7] = 16'h6000;  // OUT        LED = 0x0064
        // rom[8] = 16'h7E00;  // HALT
    end

endmodule