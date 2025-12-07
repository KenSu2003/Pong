Project Checkpoint 5
Author: Tianji Li; Austin Gregory
Netid: tl396; ag869
Overview
In this final checkpoint, I took everything I built in the earlier stages of the project—my ALU, register file, PC logic, memory modules, and skeleton wiring—and integrated them into a complete, functioning processor that can actually run real MIPS-like programs. Instead of manually forcing signals in ModelSim like before, I now had to execute full assembly test sequences through .mif-initialized instruction memory, observe their behavior, and verify that every component worked together as a cohesive system. This checkpoint pushed me to think about my design not just as separate modules, but as a unified processor that has to meet timing, handle hazards implicitly through well-structured logic, and produce verifiably correct results under a realistic clock. By the end of the checkpoint, I was able to load and run multiple custom assembly programs, observe correct register and memory updates, and demonstrate that my processor remains stable at a 10 ns clock period.


Design Implementation
Program Counter & Instruction Fetch
I designed my PC as a simple 12-bit register built from structural D flip-flops (dffe_custom). During reset, I force the PC to 0 so the program starts cleanly. On each rising edge of the processor clock, I increment the PC by 1 using my ripple-carry adder. Even though this seems trivial, I found that PC timing is closely tied to the rest of the processor because any delay here directly affects instruction fetch. My imem.v module loads instructions from .mif files, so once the PC increments, the next instruction immediately becomes available for decoding. Seeing my PC count up correctly in the waveform gave me a strong indication early on that my processor was “alive” and functioning as a system.

Instruction Decode & Register File
Once instructions were fetching properly, I implemented the decoding logic to extract opcode, register fields, function bits, and immediates. I kept the decoder simple and explicit so I could easily debug control-signal issues. My register file supports two asynchronous reads and one synchronous write, and I ensured that $r0 always remains 0, regardless of writes. One small detail that became important later was handling $r30 for overflow reporting; wiring this correctly helped me avoid debugging headaches during ALU overflow testing. Overall, the decode and register file stage felt very satisfying to get right—when I saw register values updating in perfectly timed cycles, I could tell the pipeline of my single-cycle design was consistent.

ALU & Arithmetic/Logical Execution
My ALU ended up being one of the most timing-critical pieces of the entire processor. I used my structural ripple-carry adder for addition and subtraction, and extended the ALU to handle shifts (sll, sra), bitwise operations, comparisons, and overflow detection. Since everything is structural, I had to carefully manage signed vs. unsigned interpretation. The ripple-carry adder is particularly slow because the carry must propagate through all 32 bits, and this ended up heavily influencing my maximum clock speed later. Still, once I saw my ALU handling sequences like addi, add, sub, and, and or in the waveform—especially in the more intense halfTestCases.s program—I gained a lot of confidence in the correctness of my datapath.

Memory Access (dmem)
My memory access logic uses the ALU result as an effective address, which I mask to the lower 12 bits since both IMem and DMem are 4 KB deep. Stores (sw) write data directly into DMem, while loads (lw) fetch memory contents on the next cycle. I found memory operations particularly interesting to debug because they made the processor feel “real”—once I saw data being stored into address 1, 2, and 456 in halfTestCases.s, and then successfully loaded back, I knew IMem and DMem were interacting correctly with the rest of the datapath. Since DMem initializes to zero, I didn’t have to worry about unwanted values unless I loaded from uninitialized areas.

Writeback Logic
For R-type and immediate arithmetic operations, I routed the ALU output back to the register file’s write port. For loads, I selected the DMem output instead. Handling writeback felt straightforward, but one thing I had to be careful about was avoiding glitches when the register file clock toggled. Getting the writeback timing to align perfectly with the register file clock was something I verified heavily in ModelSim. When I saw clean, correct writeback values for every instruction in my test programs, I knew this stage was fully reliable.

Top-Level Integration (skeleton.v)
Bringing everything together in skeleton.v was easily the most challenging part. Every submodule—my ALU, regfile, PC logic, memory modules, and control units—needed to be wired in the exact way the course specification required. The multiple clock inputs in the skeleton forced me to think carefully about which modules needed synchronous updates. After fixing several wiring mistakes and missing connections, I finally got a clean compile in ModelSim with Quartus libraries included. Once that happened, everything began to fall into place: the processor ran full programs, updated registers, accessed memory, and produced exactly the results I expected.

Testing Methodology
Assembly Programs to MIF Conversion

To test the processor realistically, I translated basic_test.s and halfTestCases.s into .mif files using a Python script. These files were placed in mif_outputs/, and IMem loads them at simulation start. This workflow made the processor feel much closer to an actual MIPS CPU since the instruction stream came from real machine code instead of manually forced signals.

Testbench Simulation
I wrote processor_tb.v to drive the system clock, reset, and simulation runtime. I set the clock to 10 ns (100 MHz), which later became my chosen maximum safe clock speed. I ran 2 microseconds of simulation to give my programs enough time to complete. The waveform clearly showed the PC incrementing every cycle, instructions decoding properly, register values updating, and DMem storing and loading data as expected. One thing I enjoyed about this part was watching the processor behave “organically”—each cycle had a purpose, and the datapath transitions looked smooth and predictable.

Waveform-Based Verification
I zoomed in on various parts of the simulation to ensure correct timing. For example:

ALU results changed before writeback clock edges.
Memory writes occurred exactly on rising edges.
Load values appeared in the register file one cycle later.
The PC updated consistently at the start of each cycle.
These little confirmations helped me trust that my CPU adhered to the single-cycle semantics we were required to implement.

Timing & Maximum Clock Speed Proof
One of the final requirements was to estimate and justify the fastest safe clock speed for the entire processor. After synthesizing in Quartus, the timing report indicated an Fmax of roughly 100–120 MHz, corresponding to an 8–10 ns period. This matched my intuition because the slowest part of the processor is clearly the 32-bit ripple-carry adder, which requires sequential carry propagation across all bits.
To prove experimentally that my processor can run at this speed, I ran ModelSim using a 10 ns clock (5 ns high, 5 ns low). I verified that even under this tight timing constraint, every instruction—from adds to loads to shifts—executed correctly. The waveform showed no register corruption, no misfetches, and no timing hazards. Because the waveform validated correct operation at 10 ns, I concluded that 10 ns is a safe and justifiable maximum clock period for my design.


File Descriptions
processor.v

This file contains the core datapath logic for my processor. Inside this module, I connect the ALU, register file, immediate extender, PC logic, DMem, IMem, and writeback muxes. I wrote this file in a very explicit wiring style so I could track every signal as it moved from stage to stage. All of my control signals—ALU opcode, register write enable, memory read/write enables, shift amounts, and mux selects—are generated here based on the decoded instruction fields. This file is essentially the "brain" of the whole design. When debugging, this was the file I looked at the most, because a single miswired line here affected the entire processor. Getting processor.v correct is what ultimately made my simulation waveforms clean and predictable.

skeleton.v

This is the official top-level wrapper for the entire processor system. It exposes the clocks and reset inputs that I later connect in my testbench. Inside this file, I instantiate processor.v, IMem, DMem, and all the clock dividers. Although my processor only relies on a single primary clock, the skeleton definition requires me to pass clock signals to IMem, DMem, the register file, and the processor core. Structuring this file properly ensured that ModelSim saw my entire design as one hierarchical unit. When I run simulation waves, all meaningful signals come from inside this skeleton instance (/processor_tb/UUT/...). This file is what ties the discrete modules together into a "real" processor system.

alu.v

This file implements the ALU that performs addition, subtraction, shifts, comparisons, OR/AND, and overflow detection. I wrote the ALU structurally around my ripple-carry adder (RCA) and full-adder cells. This means my ALU isn’t using behavioral Verilog shortcuts—it literally propagates carries bit-by-bit, just like physical hardware. This became the primary factor limiting my maximum clock speed. The ALU also produces flags: isLessThan, isNotEqual, and overflow. I spent a lot of time verifying that signed comparisons behave exactly as intended, especially for large positive/negative values in halfTestCases.s. Seeing correct overflow behavior in the waveform gave me confidence that my structural ALU worked as designed.

RCA.v (Ripple-Carry Adder)

This file contains the 32-bit ripple-carry adder used inside the ALU and PC increment logic. It chains together 32 copies of my full-adder module (fa.v). Because each bit depends on the previous bit’s carry-out, this module defines the critical path in my entire processor. I heavily relied on this implementation when determining my final clock speed estimate. Structurally building this adder taught me a lot about how timing propagates in hardware.

fa.v (Full Adder)

This is the basic 1-bit full-adder building block used in RCA.v. Although simple, this module appears dozens of times through the processor. I had to ensure its Boolean logic for sum and carry-out matched exactly with the course specification. A single mistake here would cause dozens of incorrect ALU outputs, so I made sure to test it early on in isolation.

regfile.v

My register file holds the 32 general-purpose registers. It supports two asynchronous read ports and one synchronous write port. This module also enforces $r0 = 0, meaning that all reads from register zero always produce zero, and writes to $r0 are ignored. I also wired in $r30 to receive overflow status when appropriate. I tested this module separately before integrating it, but I also inspected register changes in the full-processor waveform to ensure all timing lined up correctly.

dmem.v

This is the data memory module that stores and loads values using the ALU’s output as an address. It is implemented using the Quartus altsyncram primitive, which required me to compile using the Intel FPGA simulation libraries. This module uses synchronous writes and allows asynchronous reads. In my test programs, I store and load values into addresses such as 1, 2, and 456, which allowed me to verify correct behavior in the waveform. I carefully watched the DMem access signals to ensure alignment with write-enable timing.

imem.v

This file implements the instruction memory using altsyncram and loads .mif files produced from my assembly programs. It is directly indexed by the PC. Early on, I encountered errors where the .mif file was not being found because ModelSim was running from the wrong working directory. Once fixed, IMem became the backbone of program execution. Being able to swap out MIF files instantly allowed me to test multiple assembly programs without changing any Verilog code.

dffe.v
This file contains my D flip-flop with enable, used across multiple modules including the PC register and register file. My processor depends on this custom DFFE to maintain predictable synchronous behavior. I checked that every sequential module receives the correct clock and enable signals so the system behaves as expected.

basic_test.s and halfTestCases.s

These are the two assembly programs I wrote to thoroughly test all aspects of my processor.

basic_test.s validates add, sub, shifts, load/store, bitwise operations, and immediate arithmetic.

halfTestCases.s pushes the processor harder with large immediate values, overflow scenarios, deep memory accesses, and back-to-back ALU operations.

clk_div2.v

This module divides the incoming clock by 2. Although my processor only required a single primary clock, the course skeleton uses multiple derived clocks for IMem, DMem, the register file, and the processor core. clk_div2 acts as the first stage of the chain, toggling its output every other cycle. I verified that its output waveform cleanly alternated at exactly half the input frequency. This was especially important in simulation because incorrectly divided clocks can cause asynchronous behavior in IMem or DMem.

clk_div4.v

This module divides the clock further by taking the output of clk_div2 and dividing it again. It produces a clock that is one-fourth the frequency of the base clock. Even though my processor datapath itself does not require multiple clock domains, the skeleton wiring uses clk_div4 as part of the provided architecture. Ensuring that clk_div4 toggled cleanly in the waveform helped me confirm that all modules relying on slower clocks (such as memory components) received stable and predictable edges.