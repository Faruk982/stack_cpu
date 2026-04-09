# Stack CPU — Architecture Update Report

## Executive Summary

The CPU was upgraded from a minimal 20-instruction proof-of-concept to a **26-instruction architecture** with subroutine support, general-purpose data memory, and extended condition flags. Two new hardware modules were added, five existing modules were modified, and all documentation and testbenches were updated.

---

## Before vs After

| Feature                             | Before                | After                                                                             |
| ----------------------------------- | --------------------- | --------------------------------------------------------------------------------- |
| **ISA size**                        | 20 instructions       | **26 instructions** (+6)                                                          |
| **Program Counter**                 | 8-bit (256 locations) | **9-bit** (512 locations)                                                         |
| **Instruction ROM**                 | 256 × 16-bit          | **512 × 16-bit**                                                                  |
| **ALU flags**                       | Z (zero) only         | **Z, C, N, V** (zero, carry, negative, overflow)                                  |
| **Conditional branches**            | JZ, JNZ               | JZ, JNZ, **JC, JN**                                                               |
| **Subroutine support**              | None                  | **CALL/RET** with dedicated return stack                                          |
| **Data memory**                     | Stack only            | Stack + **256×16 Data RAM** (LOAD/STORE)                                          |
| **Module count (RTL source files)** | 11 source modules     | **13 source modules** (+2 new)                                                    |
| **Testbench programs**              | 1 (countdown)         | **5** (arithmetic, countdown, shift, CALL/RET, LOAD/STORE)                        |
| **Jump address width**              | 8-bit (bit 8 wasted)  | **9-bit** (full immediate used)                                                   |
| **Stack depth**                     | Fixed 16              | **Parameterised** (default 16 physical, 15 usable with empty-sentinel convention) |

---

## New Instructions Added

| Instruction  | Opcode  | Encoding   | Operation                          | Purpose                     |
| ------------ | ------- | ---------- | ---------------------------------- | --------------------------- |
| `CALL addr`  | `7'h23` | `16'h46xx` | Push PC to return stack; PC ← addr | Subroutine call             |
| `RET`        | `7'h24` | `16'h4800` | Pop return stack; PC ← saved addr  | Subroutine return           |
| `LOAD addr`  | `7'h25` | `16'h4Axx` | Push RAM[addr] onto data stack     | Read from data memory       |
| `STORE addr` | `7'h26` | `16'h4Cxx` | Pop TOS into RAM[addr]             | Write to data memory        |
| `JC addr`    | `7'h27` | `16'h4Exx` | If carry flag set, PC ← addr       | Branch on unsigned overflow |
| `JN addr`    | `7'h28` | `16'h50xx` | If negative flag set, PC ← addr    | Branch on signed negative   |

---

## New Hardware Modules

### 1. Return-Address Stack ([return_stack.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/return_stack.v))

```
Purpose:     Dedicated LIFO for subroutine return addresses
Depth:       16 physical entries (15 usable), parameterised
Data width:  9-bit (matches PC width)
Convention:  RSP=0 means empty (same as data stack)
Interface:   push_en (CALL), pop_en (RET), push_addr, top_addr
Protection:  rs_full/rs_empty flags → S_FAULT on violation
```

**Design rationale**: A separate return stack (Forth dual-stack convention) keeps return addresses off the data stack. This means subroutine calls don't consume data stack entries and can't be accidentally corrupted by stack operations.

### 2. Data RAM ([data_ram.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/data_ram.v))

```
Purpose:     General-purpose read/write data memory
Size:        256 × 16-bit (parameterised)
Address:     8-bit from IR[7:0]
Read:        Combinational (always available)
Write:       Synchronous, gated by clk_en && wr_en
Reset:       Clears all entries to zero
```

**Design rationale**: The data stack is LIFO-only — you can't random-access an entry at an arbitrary position. Data RAM provides indexed storage for arrays, lookup tables, and persistent variables, transforming the CPU from a pure stack machine into a stack-plus-memory architecture.

---

## Modified Modules

### 3. Program Counter ([pc.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/pc.v))

| Change        | Detail                          |
| ------------- | ------------------------------- |
| Width         | `8-bit → 9-bit`                 |
| `pc_in` port  | `[7:0] → [8:0]`                 |
| `pc_out` port | `[7:0] → [8:0]`                 |
| Increment     | `pc_out + 8'd1 → pc_out + 9'd1` |

**Impact**: Doubles the addressable instruction space from 256 to 512 words. The full 9-bit immediate field is now used for jump/call targets (previously bit 8 was wasted).

---

### 4. ALU ([alu.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/alu.v))

| Change         | Detail                                                      |
| -------------- | ----------------------------------------------------------- |
| New outputs    | `carry_flag`, `neg_flag`, `overflow_flag`                   |
| Carry (ADD)    | 17th bit: `{carry, result} = {1'b0, b} + {1'b0, a}`         |
| Carry (SUB)    | Borrow bit: `{carry, result} = {1'b0, b} - {1'b0, a}`       |
| Carry (SHL)    | Old MSB shifted out: `{carry, result} = {a, 1'b0}`          |
| Carry (SHR)    | Old LSB shifted out: `carry = a[0]`                         |
| Negative       | `result[15]` — sign bit of 16-bit result                    |
| Overflow (ADD) | `(~b[15] & ~a[15] & res[15]) \| (b[15] & a[15] & ~res[15])` |
| Overflow (SUB) | `(~b[15] & a[15] & res[15]) \| (b[15] & ~a[15] & ~res[15])` |

**Key design decision**: Carry, negative, and overflow are standard definitions matching ARM/x86 conventions. Overflow is only meaningful for ADD/SUB (set to 0 for logic/shift ops).

---

### 5. Instruction ROM ([instr_rom.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/instr_rom.v))

| Change       | Detail                                                            |
| ------------ | ----------------------------------------------------------------- |
| Size         | `256 → 512 entries`                                               |
| Address      | `[7:0] → [8:0]`                                                   |
| Default fill | `512 × HALT` (safe runaway protection)                            |
| New programs | CALL/RET demo and LOAD/STORE demo added as commented alternatives |

---

### 6. Stack Memory ([stack.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/stack.v))

| Change        | Detail                                                             |
| ------------- | ------------------------------------------------------------------ |
| New input     | `load_en` — push data from RAM                                     |
| New input     | `ram_data [15:0]` — data value from data_ram                       |
| New operation | When `load_en` asserted: `stack_mem[sp+1] <= ram_data; sp <= sp+1` |

**Design rationale**: The stack already had separate push sources for `imm_value` (PUSH), `sw_value` (IN), and `alu_result` (ALU writeback). LOAD adds a 4th source: data from RAM. The `if/else if` chain in the always block ensures mutual exclusion.

---

### 7. Control Unit ([control_unit.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/control_unit.v))

This module had the most changes — it's the brain of the CPU.

**New inputs:**
| Signal | Source | Purpose |
|--------|--------|---------|
| `carry_flag` | ALU | Combinational carry output |
| `neg_flag` | ALU | Combinational negative output |
| `overflow_flag` | ALU | Combinational overflow output |
| `rs_full` | Return stack | Return stack overflow guard |
| `rs_empty` | Return stack | Return stack underflow guard |
| `ram_data [15:0]` | Data RAM | For updating z_flag on LOAD |

**New outputs:**
| Signal | Destination | Purpose |
|--------|-------------|---------|
| `call_en` | Return stack | CALL: push PC to return stack |
| `ret_en` | Return stack + PC mux | RET: pop return stack, select ret_addr for PC |
| `load_en` | Stack | LOAD: push RAM data onto stack |
| `ram_wr_en` | Data RAM | STORE: write TOS to RAM |

**New registered flags:**
| Flag | Updated by | Used by |
|------|-----------|---------|
| `c_flag` | ALU operations only | `JC` branch |
| `n_flag` | ALU operations only | `JN` branch |
| `v_flag` | ALU operations only | Reserved for future `JV` |

**New opcode handling (6 cases in S_EXECUTE):**

- `OP_CALL`: Guard `rs_full` → assert `call_en + pc_load` → S_FETCH
- `OP_RET`: Guard `rs_empty` → assert `ret_en + pc_load` → S_FETCH
- `OP_LOAD`: Guard `stack_full` → assert `load_en` → S_FETCH
- `OP_STORE`: Guard `stack_empty` → assert `pop_en + ram_wr_en` → S_FETCH
- `OP_JC`: Check `c_flag` → conditionally assert `pc_load` → S_FETCH
- `OP_JN`: Check `n_flag` → conditionally assert `pc_load` → S_FETCH

---

### 8. CPU Top-Level ([cpu_top.v](file:///d:/raufun/CSE4224/Project/stack_cpu/stack_cpu.srcs/sources_1/new/cpu_top.v))

**Critical new wiring:**

```verilog
// PC input mux: RET uses return stack address, everything else uses immediate
wire [8:0] pc_in_mux = ret_en ? ret_addr : immediate;
```

This 2:1 multiplexer is the key integration point. During normal jumps/calls, the PC loads `immediate` (IR[8:0]). During RET, the PC loads `ret_addr` (top of return stack). The `ret_en` signal from the control unit selects the source.

**New module instances:**

- `return_stack u_ret_stack` — push_addr wired to `pc_out` (current PC, already past CALL)
- `data_ram u_data_ram` — addr wired to `immediate[7:0]`, data_in wired to `tos`

**Wire width changes:**

- `pc_out`: `[7:0] → [8:0]`
- `ret_addr`: new `[8:0]` wire
- `ram_data_out`: new `[15:0]` wire
- ALU flag wires: `alu_carry`, `alu_neg`, `alu_overflow` added

---

## Signal Flow Diagrams for New Features

### CALL Signal Path

```
Control Unit                Return Stack              PC
    │                            │                     │
    ├─ call_en=1 ──────────────► push_en=1             │
    │                            │ push_addr ◄── pc_out│
    │                            │ (saves current PC)  │
    ├─ pc_load=1 ────────────────┼─────────────────────►│
    │  ret_en=0 ─► mux selects immediate ──────────────►│ pc_in = IR[8:0]
    │                            │                     │ (loads jump target)
```

### RET Signal Path

```
Control Unit                Return Stack              PC
    │                            │                     │
    ├─ ret_en=1 ───────────────► pop_en=1              │
    │                            │ top_addr ───► ret_addr
    ├─ pc_load=1 ────────────────┼─────────────────────►│
    │  ret_en=1 ─► mux selects ret_addr ───────────────►│ pc_in = ret_addr
    │                            │ rsp <= rsp-1         │ (loads return addr)
```

### STORE Signal Path

```
Control Unit                Stack                Data RAM
    │                         │                     │
    ├─ pop_en=1 ─────────────►│ sp <= sp-1          │
    ├─ ram_wr_en=1 ───────────┼────────────────────►│ wr_en=1
    │                         │ tos ────────────────►│ data_in = TOS
    │  immediate[7:0] ────────┼────────────────────►│ addr = IR[7:0]
    │                         │                     │ ram[addr] <= TOS
```

### LOAD Signal Path

```
Control Unit                Stack                Data RAM
    │                         │                     │
    ├─ load_en=1 ────────────►│                     │
    │  immediate[7:0] ────────┼────────────────────►│ addr = IR[7:0]
    │                         │ ram_data ◄──────────│ data_out = ram[addr]
    │                         │ stack[sp+1] <= ram_data
    │                         │ sp <= sp+1          │
```

---

## Testbench Coverage

| Program                | Tests                  | Expected LED | Exercises                           |
| ---------------------- | ---------------------- | :----------: | ----------------------------------- |
| Countdown 10→0         | Original instructions  |   `0x0000`   | PUSH, DUP, POP, SUB, JNZ, OUT, HALT |
| Arithmetic 5+3         | Basic ALU              |   `0x0008`   | PUSH, ADD, OUT                      |
| Bit Shift 1<<4         | Unary ALU              |   `0x0010`   | PUSH, SHL, OUT                      |
| **CALL/RET double(5)** | **Subroutine support** |   `0x000A`   | **CALL, DUP, ADD, RET**             |
| **LOAD/STORE 42+58**   | **Data RAM**           |   `0x0064`   | **PUSH, STORE, LOAD, ADD**          |

ALU testbench expanded from ~15 to **18 test vectors**, now checking all 4 flags (Z, C, N, V) including carry on overflow, negative result detection, and signed overflow.

---

## Files Summary

| File                       | Status       |      Lines |
| -------------------------- | ------------ | ---------: |
| `pc.v`                     | Modified     |         31 |
| `alu.v`                    | Modified     |         65 |
| `instr_rom.v`              | Modified     |        103 |
| `stack.v`                  | Modified     |        104 |
| `control_unit.v`           | Modified     |        280 |
| `cpu_top.v`                | Modified     |        241 |
| `seg_display_controller.v` | Modified     |         54 |
| `return_stack.v`           | **NEW**      |         55 |
| `data_ram.v`               | **NEW**      |         37 |
| `cpu_tb.v`                 | Modified     |        253 |
| `alu_tb.v`                 | Modified     |        136 |
| `report.md`                | Modified     |        683 |
| `README.md`                | Modified     |        184 |
| **Total**                  | **13 files** | **~2,226** |
