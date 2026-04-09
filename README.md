# 16-bit Stack CPU for Artix-7 (Basys 3)

A custom 16-bit stack-based soft CPU written in Verilog HDL and targeted to Basys 3 (`xc7a35ticpg236-1L`).

Project highlights:

- 31-instruction ISA (CMP and new branches JE/JG/JNG/JS added)
- Gate-level arithmetic foundation (half/full-adder based 16-bit adder-subtractor path)
- Latched flag architecture preserved for deterministic branch behavior
- 15-program integration testbench coverage

## Architecture Summary

- CPU style: stack machine (zero-operand ISA)
- Clocking: single 100 MHz domain with clock-enable pulse for CPU stepping
- FSM: 6 states (`RESET`, `FETCH`, `DECODE`, `EXECUTE`, `HALT`, `FAULT`)
- Widths:
  - instruction: 16 bits (`opcode[15:9]`, `immediate[8:0]`)
  - data path: 16 bits
  - PC: 9 bits (512 ROM locations)
- Memories:
  - instruction ROM: 512 x 16
  - data RAM: 256 x 16
  - data stack: parameterized depth (default 16 physical, SP=0 empty)
  - return stack: parameterized depth (default 16 physical, RSP=0 empty)

## ISA

### Stack

| Mnemonic | Opcode | Description |
| --- | --- | --- |
| `PUSH imm` | `7'h01` | Push zero-extended immediate |
| `POP` | `7'h02` | Pop TOS |
| `DUP` | `7'h03` | Duplicate TOS |
| `SWAP` | `7'h04` | Swap TOS and NOS |

### ALU / Compare

| Mnemonic | Opcode | Description |
| --- | --- | --- |
| `ADD` | `7'h10` | `NOS + TOS`, write back, pop one |
| `SUB` | `7'h11` | `NOS - TOS`, write back, pop one |
| `AND` | `7'h12` | Bitwise AND |
| `OR` | `7'h13` | Bitwise OR |
| `XOR` | `7'h14` | Bitwise XOR |
| `NOT` | `7'h15` | Unary bitwise NOT on TOS |
| `SHL` | `7'h16` | Shift-left TOS by 1 |
| `SHR` | `7'h17` | Logical shift-right TOS by 1 |
| `CMP` | `7'h18` | Compare `NOS - TOS`, update flags only, stack unchanged |

### Control Flow

| Mnemonic | Opcode | Description |
| --- | --- | --- |
| `JMP addr` | `7'h20` | Unconditional jump |
| `JZ addr` | `7'h21` | Jump if `Z=1` |
| `JNZ addr` | `7'h22` | Jump if `Z=0` |
| `CALL addr` | `7'h23` | Push return address and jump |
| `RET` | `7'h24` | Pop return address and jump |
| `JC addr` | `7'h27` | Jump if `C=1` |
| `JN addr` | `7'h28` | Jump if `N=1` |
| `JE addr` | `7'h29` | Jump if equal (`Z=1`) |
| `JG addr` | `7'h2A` | Jump if signed greater (`!Z && N==V`) |
| `JNG addr` | `7'h2B` | Jump if signed not greater (`Z=1` or `N!=V`) |
| `JS addr` | `7'h2C` | Jump if sign (`N=1`) |
| `HALT` | `7'h3F` | Enter halt state |

### Memory and I/O

| Mnemonic | Opcode | Description |
| --- | --- | --- |
| `LOAD addr` | `7'h25` | Push `RAM[addr]` |
| `STORE addr` | `7'h26` | Store TOS to `RAM[addr]` then pop |
| `OUT` | `7'h30` | Latch TOS to output register |
| `IN` | `7'h31` | Push switch value |

## Flags

Flag latches are in `control_unit.v` and are updated in `S_EXECUTE`.

- `Z`: result zero
- `C`: carry/borrow (and shift-out for SHL/SHR)
- `N`: result sign bit (`result[15]`)
- `V`: signed overflow

Branches use the **latched flags**, not transient combinational values.

## ALU Implementation Notes

`alu.v` is combinational, but now delegates operation logic to dedicated modules:

- arithmetic path: `half_adder.v`, `full_adder.v`, `ripple_adder_16.v`, `adder_subtractor_16.v`
- bitwise path: `bitwise_and_16.v`, `bitwise_or_16.v`, `bitwise_xor_16.v`, `bitwise_not_16.v`
- shift path: `shl1_16.v`, `shr1_16.v`
- compare helper: `comparator_16.v` (library/helper module)

## Module Hierarchy

```text
cpu_top.v
├── clk_div.v
├── pc.v
├── instr_rom.v
├── instr_reg.v
├── control_unit.v
├── alu.v
│   ├── adder_subtractor_16.v
│   │   └── ripple_adder_16.v
│   │       └── full_adder.v
│   │           └── half_adder.v
│   ├── bitwise_and_16.v
│   ├── bitwise_or_16.v
│   ├── bitwise_xor_16.v
│   ├── bitwise_not_16.v
│   ├── shl1_16.v
│   └── shr1_16.v
├── stack.v
├── return_stack.v
├── data_ram.v
├── output_reg.v
└── seg_display_controller.v
    └── hex_to_7seg.v
```

RTL count in `stack_cpu.srcs/sources_1/new`: 24 Verilog modules.

## Default ROM Program Behavior

In `instr_rom.v`, the active default program is a recurring subroutine-based countdown loop:

- counts `10 -> 0`
- repeats forever (`CALL` + `JMP` main loop)
- does not HALT in normal operation

## Simulation

### ALU Unit Test (`alu_tb.v`)

- Verifies ADD/SUB/AND/OR/XOR/NOT/SHL/SHR/CMP
- Checks `result`, `Z`, `C`, `N`, `V`

### CPU Integration Test (`cpu_tb.v`)

15 test programs are executed, including:

- arithmetic, shift, call/ret, load/store
- JC/JN branch checks
- CMP + JE/JG/JNG/JS branch checks
- underflow/overflow FAULT checks

Expected result target: all tests pass.

## Hardware I/O Mapping (Basys 3)

- `clk`: W5 (100 MHz)
- `rst`: U18 (btnC)
- `sw[15:0]`: slide switches
- `led[15:0]`: LEDs
- `seg[6:0]`, `an[3:0]`: 7-segment display

## Build and Program (Vivado)

1. Open `stack_cpu.xpr` in Vivado (or create new project with all `.v` files)
2. Set target device to **`xc7a35ticpg236-1L`**
3. Set `cpu_top` as top module
4. Run Synthesis → Implementation → Generate Bitstream
5. Program the Basys 3 board via Hardware Manager

---

## License

Developed for CSE4224 Digital System Design.
