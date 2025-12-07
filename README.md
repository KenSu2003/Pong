================================================================================
PROJECT CHECKPOINT 6: INTERACTIVE PONG ON CUSTOM PROCESSOR
Duke University - ECE 550
================================================================================

1. OVERVIEW
--------------------------------------------------------------------------------
This project implements a fully interactive Pong game running on a custom 
32-bit RISC processor on an FPGA. The game logic runs entirely in software 
(MIPS-style Assembly) while interfacing with hardware peripherals (VGA screen 
and PS2 Keyboard) via Memory Mapped I/O (MMIO).

We chose Pong over Snake, Tetris, or Flappy Bird because:
1. It requires minimal memory management (state fits in registers).
2. It uses simple arithmetic (ADD/SUB) compatible with our ALU.
3. Collision detection relies on simple comparison logic (BLT).


2. HARDWARE ARCHITECTURE MODIFICATIONS
--------------------------------------------------------------------------------
To enable the processor to "talk" to the outside world, specific Verilog modules 
were modified. The original skeleton code disconnected the processor from I/O.

A. PS2_Interface.v
   - Original Issue: Only detected Q, W, E, R, and Space.
   - Modification: Added Scan Code 8'h1B to the case statement to detect the 
     'S' key (Down movement).
   - Result: Processor can now detect 'W' (Up) and 'S' (Down).

B. skeleton.v
   - Original Issue: Processor instantiation had PS2 ports commented out.
   - Modification: Uncommented `ps2_key_pressed` and `ps2_out` and wired them 
     into the processor module.

C. processor.v (The "Glue Logic")
   - Original Issue: Processor only connected to Data Memory (dmem).
   - Modification: Implemented an Address Decoder (Multiplexer).
     * WRITE LOGIC:
       - If Address < 2000: Write to Data Memory (RAM).
       - If Address == 3000: Write to VGA Controller (Update Ball/Paddle X/Y).
     * READ LOGIC:
       - If Address < 2000: Read from Data Memory (RAM).
       - If Address == 2000: Read from PS2 Controller (Keyboard Input).

D. vga_controller.v
   - Original Issue: Movement logic was hardcoded to hardware switches.
   - Modification: Logic altered to accept coordinates provided by the 
     processor via the MMIO link, rather than internal counters.


3. SOFTWARE IMPLEMENTATION (ASSEMBLY)
--------------------------------------------------------------------------------
The game logic is derived from the structural logic found in `game.asm` (x86), 
translated into our Custom ISA.

A. Instruction Translation Table
   Since our processor lacks complex x86 instructions, we mapped them as follows:

   | Logic Action      | x86 Instruction | Custom ISA Equivalent      |
   |-------------------|----------------------------------|----------------------------|
   | Load Variable     | mov ax, [addr]                   | lw $r1, 0($r2)             |
   | Move Object       | add ax, velocity                 | add $r1, $r1, $r2          |
   | Check Collision   | cmp ax, boundary                 | blt $r1, $r2, label        |
   | Loop (Draw)       | jle loop_start                   | blt $counter, $max, loop   |
   | Call Subroutine   | call drawBall                    | jal drawBall               |
   | Return            | ret                              | jr $r31                    |

B. Register Mapping
   To avoid slow memory access, the entire active game state is held in registers:
   - $r1: Ball X Coordinate
   - $r2: Ball Y Coordinate
   - $r3: Ball Velocity X
   - $r4: Ball Velocity Y
   - $r5: Left Paddle Y
   - $r6: Right Paddle Y
   - $r20: Score Counter

C. The Game Loop
   1. POLL INPUT: 
      Load from Address 2000. If 1 (Key Pressed), load Data.
      If Data == 'W', sub from Paddle Y. If Data == 'S', add to Paddle Y.
   
   2. UPDATE PHYSICS:
      Add Velocity X to Ball X.
      Add Velocity Y to Ball Y.
   
   3. CHECK COLLISIONS:
      Use `blt` to check if Ball Y < Top Wall or Ball Y > Bottom Wall.
      If true, `sub` Velocity from 0 to invert direction (Negate).
      Check Paddle collision using bounding box logic adapted from game.asm.
   
   4. RENDER:
      Store Color White to Address calculated from Ball X/Y.
      Store Color Black to old Ball X/Y (Erase).


4. MEMORY MAP
--------------------------------------------------------------------------------
The following addresses are reserved for Memory Mapped I/O:

0x0000 - 0x0FFF : Data Memory (RAM) for variables/stack.
0x2000          : Keyboard Status & Data (Read Only).
0x3000          : VGA Ball Control (Write Only).
0x3004          : VGA Paddle Control (Write Only).

================================================================================