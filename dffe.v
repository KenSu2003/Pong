
module dffe(q, d, clk, en, clr);
   input d, clk, en, clr;
   output q;
   reg q;
   initial begin q = 1'b0; end
   always @(posedge clk or posedge clr) begin
       if (clr) q <= 1'b0;
       else if (en) q <= d;
   end
endmodule
