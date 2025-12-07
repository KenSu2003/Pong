/**
 * NOTE: While this file is intended to remain unchanged, you might need 
 * to make essential edits to ensure compatibility with your processor design. 
 * This file will be swapped out for a grading
 * "skeleton" for testing. We will also remove your imem and dmem file.
 *
 * NOTE: skeleton should be your top-level module!
 *
 * This skeleton file serves as a wrapper around the processor to provide certain control signals
 * and interfaces to memory elements. This structure allows for easier testing, as it is easier to
 * inspect which signals the processor tries to assert when.
 */

module skeleton(clock, reset, imem_clock, dmem_clock, processor_clock, regfile_clock);
    input clock, reset;
    output imem_clock, dmem_clock, processor_clock, regfile_clock;

    clk_div4 u_div4 (.clk(clock), .reset(reset), .clk_out(processor_clock));
    clk_div2 u_div2 (.clk(clock), .reset(reset), .clk_out(dmem_clock));
    assign imem_clock   = clock;
    assign regfile_clock = processor_clock;

    wire [11:0] address_imem;
    wire [31:0] q_imem;
    imem my_imem(
        .address    (address_imem),
        .clock      (imem_clock),
        .q          (q_imem)
    );

    wire [11:0] address_dmem;
    wire [31:0] data;
    wire        wren;
    wire [31:0] q_dmem;
    dmem my_dmem(
        .address    (address_dmem),
        .clock      (dmem_clock),
        .data       (data),
        .wren       (wren),
        .q          (q_dmem)
    );

    wire        ctrl_writeEnable;
    wire [4:0]  ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
    wire [31:0] data_writeReg;
    wire [31:0] data_readRegA, data_readRegB;
    regfile my_regfile(
        regfile_clock,
        ctrl_writeEnable,
        reset,
        ctrl_writeReg,
        ctrl_readRegA,
        ctrl_readRegB,
        data_writeReg,
        data_readRegA,
        data_readRegB
    );

    processor my_processor(
        processor_clock,
        reset,
        address_imem,
        q_imem,
        address_dmem,
        data,
        wren,
        q_dmem,
        ctrl_writeEnable,
        ctrl_writeReg,
        ctrl_readRegA,
        ctrl_readRegB,
        data_writeReg,
        data_readRegA,
        data_readRegB
    );
endmodule
