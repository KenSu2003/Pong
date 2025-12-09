module PS2_Interface(inclock, resetn, ps2_clock, 
					ps2_data, ps2_key_data, ps2_key_pressed, 
					last_data_received);

	input 			inclock, resetn;
	inout 			ps2_clock, ps2_data;
	output 			ps2_key_pressed;
	output 	reg [7:0] 	ps2_key_data;
	output 	[7:0] 	last_data_received;

	// Internal Registers
	reg			[7:0]	last_data_received;	
	
	always @(posedge inclock)
	begin
		if (resetn == 1'b0)
			last_data_received <= 8'h00;
		else if (ps2_key_pressed == 1'b1)
			case (ps2_key_data)
				8'h15: last_data_received <= 8'h51; // Q
				8'h1d: last_data_received <= 8'h57; // W
				8'h24: last_data_received <= 8'h45; // E
				8'h2d: last_data_received <= 8'h52; // R
				default: last_data_received <= 8'h20; // space
			endcase
	end


    // --- PS/2 controller instance ---
    PS2_Controller PS2 (
        .CLOCK_50           (inclock),
        .reset              (~resetn),
        .PS2_CLK            (ps2_clock),
        .PS2_DAT            (ps2_data),
        .received_data      (raw_scancode),
        .received_data_en   (ps2_key_pressed)
    );

endmodule
