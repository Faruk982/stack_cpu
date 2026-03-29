# 16-bit Stack-Based CPU — Artix-7 FPGA Implementation

A custom 16-bit soft-core processor built from scratch in Verilog HDL, implementing a **Stack Machine (zero-operand) architecture**. Designed for the **Basys 3** development board with the Xilinx Artix-7 FPGA (`xc7a35ticpg236-1L`).

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Instruction Set Architecture (ISA)](#instruction-set-architecture-isa)
- [Module Hierarchy](#module-hierarchy)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup & Build](#setup--build)
- [Running Simulations](#running-simulations)
- [Programming the FPGA](#programming-the-fpga)
- [Example Programs](#example-programs)
- [Hardware I/O Mapping](#hardware-io-mapping)

---

## Overview

This project implements a complete 16-bit stack-based CPU that demonstrates core digital system design concepts:

- **Register Transfer Logic (RTL)** — data paths between registers, ALU, and memory
- **Finite State Machine (FSM) Control** — 5-state Moore machine sequencing instruction execution
- **ALU Design** — combinational 16-bit arithmetic/logic unit with 8 operations
- **Instruction Set Architecture** — 20-instruction zero-operand ISA
- **On-chip Memory** — Harvard architecture with separate instruction ROM and data stack

The CPU executes at a configurable slow clock speed (~2 Hz default) for real-time hardware observation via the board's 16 LEDs and 4-digit 7-segment hex display.

---

## Architecture

```
                    ┌────────────────────────────────────-─┐
                    │            cpu_top.v                 │
                    │                                      │
    100 MHz ───────►│ clk_div ──► CPU Clock (~2 Hz)        │
                    │              │                       │
    Reset ─────────►│     ┌────────┴────────────┐          │
                    │     ▼                     │          │
                    │  ┌──────┐  ┌─────────┐    │          │
                    │  │  PC  │─►│  ROM    │    │          │
                    │  │ 8-bit│  │256×16-bit│   │          │
                    │  └──┬───┘  └────┬────┘    │          │
                    │     │           ▼         │          │
                    │     │      ┌────────┐     │          │
                    │     │      │   IR   │     │          │
                    │     │      │ 16-bit │     │          │
                    │     │      └──┬──┬──┘     │          │
                    │     │   opcode│  │imm     │          │
                    │     │         ▼  │        │          │
                    │  ┌──┴──────────┐ │        │          │
                    │  │ Control Unit│ │        │          │
                    │  │   (FSM)     │ │        │          │
                    │  └──┬──────────┘ │        │          │
                    │     │ ctrl sigs  │        │          │
                    │     ▼            ▼        │          │
                    │  ┌──────────┐ ┌──────┐    │          │
    Switches[15:0]─►│  │  Stack   │►│ ALU  │    │          │
                    │  │ 16×16-bit│◄│16-bit│    │          │
                    │  └────┬─────┘ └──────┘    │          │
                    │       │ TOS               │          │
                    │       ▼                   │          │
                    │  ┌──────────┐             │          │
                    │  │ OUT_REG  │             │          │
                    │  │  16-bit  │             │          │
                    │  └──┬───┬──-┘             │          │
                    │     │   │                 │          │
                    └─────┼───┼─────────────────┘           
                          │   │                             
                    LED[15:0] 7-Segment Display             
```

---

## Instruction Set Architecture (ISA)

16-bit instruction format: `[15:9] opcode (7b) | [8:0] immediate (9b)`

| Mnemonic | Opcode | Operation | Description |
|----------|--------|-----------|-------------|
| **Stack Operations** |
| `PUSH imm` | `01` | `SP++; stack[SP] ← imm` | Push 9-bit zero-extended value |
| `POP` | `02` | `SP--` | Discard top of stack |
| `DUP` | `03` | `SP++; stack[SP] ← TOS` | Duplicate top of stack |
| `SWAP` | `04` | `TOS ↔ NOS` | Swap top two elements |
| **Arithmetic / Logic** |
| `ADD` | `10` | `NOS + TOS → stack[SP-1]; SP--` | Addition |
| `SUB` | `11` | `NOS - TOS → stack[SP-1]; SP--` | Subtraction |
| `AND` | `12` | `NOS & TOS → stack[SP-1]; SP--` | Bitwise AND |
| `OR` | `13` | `NOS \| TOS → stack[SP-1]; SP--` | Bitwise OR |
| `XOR` | `14` | `NOS ^ TOS → stack[SP-1]; SP--` | Bitwise XOR |
| `NOT` | `15` | `~TOS → stack[SP]` | Bitwise complement |
| `SHL` | `16` | `TOS << 1 → stack[SP]` | Left shift by 1 |
| `SHR` | `17` | `TOS >> 1 → stack[SP]` | Logical right shift by 1 |
| **Control Flow** |
| `JMP addr` | `20` | `PC ← addr` | Unconditional jump |
| `JZ addr` | `21` | `if (Z) PC ← addr` | Jump if zero flag set |
| `JNZ addr` | `22` | `if (!Z) PC ← addr` | Jump if zero flag clear |
| `HALT` | `3F` | Freeze PC | Halt execution |
| **I/O** |
| `OUT` | `30` | `OUT_REG ← TOS` | Drive LEDs with TOS |
| `IN` | `31` | `SP++; stack[SP] ← switches` | Push switch state |

---

## Module Hierarchy

```
cpu_top.v                  ← Top-level wrapper (board pin mapping)
├── clk_div.v              ← 100 MHz → ~2 Hz slow clock for demo
├── pc.v                   ← 8-bit Program Counter
├── instr_rom.v            ← 256×16-bit Instruction ROM
├── instr_reg.v            ← 16-bit Instruction Register
├── control_unit.v         ← FSM: RESET/FETCH/DECODE/EXECUTE/HALT
├── alu.v                  ← 16-bit Combinational ALU
├── stack.v                ← 16×16-bit Stack Memory + SP
├── output_reg.v           ← 16-bit Output Register → LEDs
├── seg_display_controller.v  ← 4-digit hex 7-segment multiplexer
│   └── hex_to_7seg.v     ← Hex nibble to 7-segment decoder
```

---

## Project Structure

```
stack_cpu/
├── stack_cpu.xpr                          ← Vivado project file
├── report.md                              ← Design specification document
├── README.md                              ← This file
├── stack_cpu.srcs/
│   ├── sources_1/new/                     ← RTL source files
│   │   ├── cpu_top.v                      ← Top-level wrapper
│   │   ├── clk_div.v                      ← Clock divider
│   │   ├── pc.v                           ← Program Counter
│   │   ├── instr_rom.v                    ← Instruction ROM
│   │   ├── instr_reg.v                    ← Instruction Register
│   │   ├── control_unit.v                 ← FSM Control Unit
│   │   ├── alu.v                          ← Arithmetic Logic Unit
│   │   ├── stack.v                        ← Stack Memory
│   │   ├── output_reg.v                   ← Output Register
│   │   ├── seg_diaplay_controller.v       ← 7-Segment Display Controller
│   │   └── hex_to_7seg.v                  ← Hex-to-7seg Decoder
│   ├── constrs_1/new/
│   │   └── main.xdc                       ← Basys 3 pin constraints
│   └── sim_1/new/                         ← Simulation testbenches
│       ├── cpu_tb.v                       ← Full CPU integration test
│       └── alu_tb.v                       ← ALU unit test
```

---

## Prerequisites

| Requirement | Version |
|------------|---------|
| **Xilinx Vivado** | 2023.1 or later (free WebPACK edition is sufficient) |
| **FPGA Board** | Basys 3 (Artix-7 `xc7a35ticpg236-1L`) |
| **USB Cable** | Micro-USB for programming and UART |

---

## Setup & Build

### 1. Open / Create the Vivado Project

**Option A — Open existing project:**
1. Launch Vivado
2. Open Project → navigate to `stack_cpu/stack_cpu.xpr`
3. **Important:** Change the target FPGA part:
   - Go to **Settings** → **General** → **Project Device**
   - Change from `xc7a15ticpg236-1L` to **`xc7a35ticpg236-1L`**
   - Click **OK**

**Option B — Create a fresh project:**
1. Launch Vivado → **Create Project**
2. Project name: `stack_cpu`, location: your preferred directory
3. Project type: **RTL Project**
4. Add all `.v` files from `stack_cpu.srcs/sources_1/new/`
5. Add `main.xdc` from `stack_cpu.srcs/constrs_1/new/`
6. Add testbench files from `stack_cpu.srcs/sim_1/new/` as simulation sources
7. Select part: **`xc7a35ticpg236-1L`**
8. Finish

### 2. Set the Top Module

1. In the **Sources** panel, right-click `cpu_top` → **Set as Top**
2. This ensures Vivado synthesizes the full CPU hierarchy

### 3. Add Source Files to Vivado (if needed)

If you opened the existing `.xpr` and Vivado doesn't see the new files:
1. In the **Sources** panel, click **+** → **Add or Create Design Sources**
2. Navigate to `stack_cpu.srcs/sources_1/new/` and add all `.v` files
3. Similarly, add simulation sources from `sim_1/new/`

### 4. Synthesize and Implement

1. Click **Run Synthesis** (or press `F11`)
2. After synthesis completes, click **Run Implementation**
3. After implementation, click **Generate Bitstream**
4. Wait for all steps to complete (≈ 2–5 minutes)

---

## Running Simulations

### ALU Unit Test

1. In the **Sources** panel, set `alu_tb` as the simulation top module:
   - Expand **Simulation Sources** → right-click `alu_tb` → **Set as Top**
2. Click **Run Simulation** → **Run Behavioral Simulation**
3. Check the **Tcl Console** for pass/fail results:
   ```
   [PASS] ADD    | A=0x0005 B=0x0003 | Result=0x0008 Z=0
   [PASS] SUB    | A=0x0003 B=0x0005 | Result=0x0002 Z=0
   ...
   Results: 15 PASSED, 0 FAILED out of 15 tests
   ALL TESTS PASSED
   ```

### Full CPU Integration Test

1. Set `cpu_tb` as the simulation top module
2. Run Behavioral Simulation
3. The testbench prints an execution trace:
   ```
   Time(ns)  | RST | PC   | IR     | SP | TOS    | LED    | Halted
   ----------|-----|------|--------|----|--------|--------|-------
       1000  |  0  | 0x01 | 0x020A |  1 | 0x000A | 0x0000 |   0
   ```
4. Simulation ends when the CPU halts or the 500 µs timeout triggers
5. For waveform analysis, use the **Waveform Viewer** to inspect internal signals

### Switching Programs

To test a different program, edit `instr_rom.v`:
1. Comment out the current program's ROM initialization
2. Uncomment the desired alternative program
3. Re-run the simulation

---

## Programming the FPGA

1. Connect the Basys 3 board via USB
2. Power on the board (switch in the **ON** position)
3. In Vivado, after generating the bitstream:
   - Click **Open Hardware Manager** → **Open Target** → **Auto Connect**
   - Click **Program Device** → select the `.bit` file → **Program**
4. The CPU starts executing immediately after programming
5. Press the **center button** (btnC) to reset and restart execution

---

## Example Programs

### Program 1: Basic Arithmetic (5 + 3 = 8)
Pushes 5 and 3, adds them, outputs result on LEDs.
- **Expected LED output:** `0x0008` (binary: `0000 0000 0000 1000`)
- **7-segment display:** `0008`

### Program 2: Countdown Loop (Default)
Counts from 10 down to 0, displaying each value on the LEDs at ~2 Hz.
- **Expected behavior:** LEDs show decreasing values: 10 → 9 → 8 → ... → 0
- **7-segment display:** Shows hex value of current count (`000A` → `0009` → ... → `0000`)

### Program 3: Bit Shift Demo
Pushes 1 and shifts left 4 times (1 → 2 → 4 → 8 → 16), outputs result.
- **Expected LED output:** `0x0010` (binary: `0000 0000 0001 0000`)
- **7-segment display:** `0010`

---

## Hardware I/O Mapping

| Board Element | Port | Function |
|--------------|------|----------|
| **W5** (clock) | `clk` | 100 MHz oscillator |
| **U18** (btnC) | `rst` | Active-high reset |
| **V17–R2** (SW0–SW15) | `sw[15:0]` | Input for `IN` instruction |
| **U16–L1** (LD0–LD15) | `led[15:0]` | Output register display |
| **W7–U7** (CA–CG) | `seg[6:0]` | 7-segment cathodes |
| **U2, U4, V4, W4** | `an[3:0]` | 7-segment anodes |

---

## Design Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Clock frequency | 100 MHz | Board oscillator |
| CPU clock | ~2 Hz | Adjustable via `clk_div` DIVISOR parameter |
| Instruction width | 16 bits | 7-bit opcode + 9-bit immediate |
| Data width | 16 bits | Stack entries, ALU, output register |
| ROM size | 256 words | 8-bit address space |
| Stack depth | 16 entries | 4-bit stack pointer |
| ISA size | 20 instructions | Using 20 of 128 possible encodings |

---

## License

This project is developed for educational purposes as part of the CSE4224 Digital System Design course.
