module regfile (
    input clock,
    input ctrl_writeEnable,
    input ctrl_reset,
    input [4:0] ctrl_writeReg,
    input [4:0] ctrl_readRegA,
    input [4:0] ctrl_readRegB,
    input [31:0] data_writeReg,
    output [31:0] data_readRegA,
    output [31:0] data_readRegB
);

    // The actual storage: an array of 32 registers, each 32 bits wide
    reg [31:0] registers [31:0];

    integer i;

    // ——————————————————————— Write Port ———————————————————————
    always @(posedge clock or posedge ctrl_reset) begin
        if (ctrl_reset) begin
            // Reset all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end
        else begin
            // Write only if enabled AND we are not trying to write to Register 0
            // (Register 0 must always remain hardwired to 0)
            if (ctrl_writeEnable && ctrl_writeReg != 5'd0) begin
                registers[ctrl_writeReg] <= data_writeReg;
            end
        end
    end

    // ——————————————————————— Read Ports ———————————————————————
    // Combinational Logic (Async Read)
    // If reading Reg 0, force output to 0. Otherwise, read from the array.
    
    assign data_readRegA = (ctrl_readRegA == 5'd0) ? 32'd0 : registers[ctrl_readRegA];
    assign data_readRegB = (ctrl_readRegB == 5'd0) ? 32'd0 : registers[ctrl_readRegB];

endmodule