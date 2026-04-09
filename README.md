# 16-bit Stack-Based CPU — Artix-7 FPGA Implementation

A custom 16-bit soft-core processor built from scratch in Verilog HDL, implementing a **Stack Machine (zero-operand) architecture** with subroutine support, data memory, and extended condition flags. Designed for the **Basys 3** development board with the Xilinx Artix-7 FPGA (`xc7a35ticpg236-1L`).

---

## Overview

This project implements a complete 16-bit stack-based CPU demonstrating core digital system design concepts:

- **Register Transfer Logic (RTL)** — data paths between registers, ALU, and memory
- **Finite State Machine (FSM) Control** — 6-state Moore machine (RESET, FETCH, DECODE, EXECUTE, HALT, FAULT)
- **ALU Design** — combinational 16-bit ALU with 8 operations and 4 condition flags (Z, C, N, V)
- **26-Instruction ISA** — stack ops, arithmetic/logic, control flow (JMP/JZ/JNZ/JC/JN), subroutines (CALL/RET), memory (LOAD/STORE), I/O
- **Harvard Architecture** — separate 512-word instruction ROM and parameterised data stack
- **Subroutine Support** — dedicated return-address stack (16 physical entries, 15 usable with empty-sentinel convention)
- **Data Memory** — 256×16-bit RAM for general-purpose storage
- **Stack Safety** — pre-emptive overflow/underflow detection with fault state

The CPU executes at ~2 Hz for real-time observation via 16 LEDs and a 4-digit 7-segment hex display.

---

## Instruction Set Architecture (ISA)

16-bit instruction format: `[15:9] opcode (7b) | [8:0] immediate (9b)`

| Mnemonic               | Opcode | Operation                        | Description                    |
| ---------------------- | ------ | -------------------------------- | ------------------------------ |
| **Stack Operations**   |
| `PUSH imm`             | `01`   | `SP++; stack[SP] ← imm`          | Push 9-bit zero-extended value |
| `POP`                  | `02`   | `SP--`                           | Discard TOS                    |
| `DUP`                  | `03`   | `SP++; stack[SP] ← TOS`          | Duplicate TOS                  |
| `SWAP`                 | `04`   | `TOS ↔ NOS`                      | Swap top two elements          |
| **Arithmetic / Logic** |
| `ADD`                  | `10`   | `NOS + TOS → stack; SP--; ZCNV`  | Addition                       |
| `SUB`                  | `11`   | `NOS - TOS → stack; SP--; ZCNV`  | Subtraction                    |
| `AND`                  | `12`   | `NOS & TOS → stack; SP--; ZCNV`  | Bitwise AND                    |
| `OR`                   | `13`   | `NOS \| TOS → stack; SP--; ZCNV` | Bitwise OR                     |
| `XOR`                  | `14`   | `NOS ^ TOS → stack; SP--; ZCNV`  | Bitwise XOR                    |
| `NOT`                  | `15`   | `~TOS → stack[SP]; ZCNV`         | Bitwise complement             |
| `SHL`                  | `16`   | `TOS << 1; C←MSB; ZCNV`          | Left shift by 1                |
| `SHR`                  | `17`   | `TOS >> 1; C←LSB; ZCNV`          | Right shift by 1               |
| **Control Flow**       |
| `JMP addr`             | `20`   | `PC ← addr`                      | Unconditional jump             |
| `JZ addr`              | `21`   | `if (Z) PC ← addr`               | Jump if zero                   |
| `JNZ addr`             | `22`   | `if (!Z) PC ← addr`              | Jump if not zero               |
| `CALL addr`            | `23`   | `ret_push(PC); PC ← addr`        | Call subroutine                |
| `RET`                  | `24`   | `PC ← ret_pop()`                 | Return from subroutine         |
| `JC addr`              | `27`   | `if (C) PC ← addr`               | Jump if carry                  |
| `JN addr`              | `28`   | `if (N) PC ← addr`               | Jump if negative               |
| `HALT`                 | `3F`   | Freeze PC                        | Halt execution                 |
| **Memory**             |
| `LOAD addr`            | `25`   | `SP++; stack[SP] ← RAM[addr]`    | Load from data RAM             |
| `STORE addr`           | `26`   | `RAM[addr] ← TOS; SP--`          | Store TOS to data RAM          |
| **I/O**                |
| `OUT`                  | `30`   | `OUT_REG ← TOS`                  | Drive LEDs/7-seg               |
| `IN`                   | `31`   | `SP++; stack[SP] ← switches`     | Push switch state              |

---

## Module Hierarchy

```
cpu_top.v                       ← Top-level wrapper
├── clk_div.v                   ← Clock-enable generator (~2 Hz)
├── pc.v                        ← 9-bit Program Counter
├── instr_rom.v                 ← 512×16-bit Instruction ROM
├── instr_reg.v                 ← 16-bit Instruction Register
├── control_unit.v              ← 6-state FSM (26 opcodes, 4 flags)
├── alu.v                       ← 16-bit ALU with Z,C,N,V flags
├── stack.v                     ← Parameterised Data Stack (default 16×16 physical, 15 usable)
├── return_stack.v              ← Return-Address Stack (16×9 physical, 15 usable)
├── data_ram.v                  ← 256×16-bit Data RAM
├── output_reg.v                ← 16-bit Output Register → LEDs
└── seg_display_controller.v    ← 4-digit 7-segment multiplexer
    └── hex_to_7seg.v           ← Hex-to-7seg decoder
```

---

## Project Structure

```
stack_cpu/
├── stack_cpu.xpr                          ← Vivado project file
├── report.md                              ← Design specification
├── README.md                              ← This file
├── stack_cpu.srcs/
│   ├── sources_1/new/                     ← RTL source files (13 modules)
│   ├── constrs_1/new/
│   │   └── main.xdc                       ← Basys 3 pin constraints
│   └── sim_1/new/                         ← Testbenches
│       ├── cpu_tb.v                       ← 5-program integration test
│       └── alu_tb.v                       ← ALU unit test (18 vectors)
```

---

## Running Simulations

### ALU Unit Test

Tests all 8 operations with 18 vectors including carry, negative, and overflow flag checks.

### CPU Integration Test (5 Programs)

The testbench automatically tests all five example programs:

```
[PASS] Countdown 10->0      — LED=0x0000
[PASS] Arithmetic 5+3=8     — LED=0x0008
[PASS] Bit Shift 1<<4=16    — LED=0x0010
[PASS] CALL/RET double(5)   — LED=0x000A
[PASS] LOAD/STORE 42+58     — LED=0x0064
RESULTS: 5 PASSED, 0 FAILED out of 5 tests
```

---

## Example Programs

| #   | Name       | Description                   | Expected LED |
| --- | ---------- | ----------------------------- | :----------: |
| 1   | Countdown  | 10→0 loop with display        |   `0x0000`   |
| 2   | Arithmetic | 5 + 3 = 8                     |   `0x0008`   |
| 3   | Bit Shift  | 1 << 4 = 16                   |   `0x0010`   |
| 4   | CALL/RET   | Subroutine doubles 5→10       |   `0x000A`   |
| 5   | LOAD/STORE | Store 42,58; load and add→100 |   `0x0064`   |

---

## Design Parameters

| Parameter         | Value                                          |
| ----------------- | ---------------------------------------------- |
| Clock frequency   | 100 MHz                                        |
| CPU clock         | ~2 Hz (configurable)                           |
| Instruction width | 16 bits (7b opcode + 9b immediate)             |
| Data width        | 16 bits                                        |
| ROM size          | 512 words (9-bit PC)                           |
| Stack depth       | 16 physical entries (15 usable), parameterised |
| Return stack      | 16 physical entries × 9-bit (15 usable)        |
| Data RAM          | 256 × 16-bit                                   |
| ISA size          | 26 instructions                                |
| FSM states        | 6 (3-bit encoding)                             |
| ALU flags         | Z, C, N, V                                     |

---

## Hardware I/O Mapping

| Board Element      | Port        | Function                 |
| ------------------ | ----------- | ------------------------ |
| **W5**             | `clk`       | 100 MHz oscillator       |
| **U18** (btnC)     | `rst`       | Active-high reset        |
| **V17–R2**         | `sw[15:0]`  | Input for IN instruction |
| **U16–L1**         | `led[15:0]` | Output register display  |
| **W7–U7**          | `seg[6:0]`  | 7-segment cathodes       |
| **U2, U4, V4, W4** | `an[3:0]`   | 7-segment anodes         |

---

## Setup & Build

1. Open `stack_cpu.xpr` in Vivado (or create new project with all `.v` files)
2. Set target device to **`xc7a35ticpg236-1L`**
3. Set `cpu_top` as top module
4. Run Synthesis → Implementation → Generate Bitstream
5. Program the Basys 3 board via Hardware Manager

---

## License

Developed for CSE4224 Digital System Design.
