
module alu(data_operandA, data_operandB, ctrl_ALUopcode,
			ctrl_shiftamt, data_result, isNotEqual, isLessThan, overflow);

	input [31:0] data_operandA, data_operandB;
	input [4:0] ctrl_ALUopcode, ctrl_shiftamt;
	output [31:0] data_result;
	output isNotEqual, isLessThan, overflow;
	
	wire signed[31:0] inner_A, inner_B;
	reg  signed[31:0] inner_result;
	reg  inner_cout;
	
	assign inner_A = data_operandA;
	assign inner_B = data_operandB;
	assign data_result = inner_result;
	
	assign isNotEqual = inner_A != inner_B;
	assign isLessThan = inner_A < inner_B;
	assign overflow = inner_cout != inner_result[31];
	
	always @(*) begin
		{inner_cout, inner_result} = inner_A + inner_B; 
		case (ctrl_ALUopcode)
			5'd0 : {inner_cout, inner_result} = inner_A + inner_B;  
			5'd1 : {inner_cout, inner_result} = inner_A - inner_B;	
			5'd2 : inner_result = inner_A & inner_B;  				
			5'd3 : inner_result = inner_A | inner_B;  				
			5'd4 : inner_result = inner_A << ctrl_shiftamt;			
			5'd5 : inner_result = inner_A >>> ctrl_shiftamt;		
			default: ;
		endcase
	end
endmodule