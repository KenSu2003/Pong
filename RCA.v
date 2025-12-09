module RCA(s,a,b);
	input [31:0] a, b;
	output [31:0] s;
	wire [31:0] c;
	fa fa0 (a[0],  b[0],  1'b0,  s[0],  c[0]);
	genvar i;
	generate
		for (i=1; i<32; i=i+1) begin: FA
			fa fai (a[i], b[i], c[i-1], s[i], c[i]);
		end
	endgenerate
endmodule