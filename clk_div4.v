
module clk_div4(input clk, input reset, output clk_out);
    wire div2_out;
    clk_div2 u0(.clk(clk), .reset(reset), .clk_out(div2_out));
    clk_div2 u1(.clk(div2_out), .reset(reset), .clk_out(clk_out));
endmodule
