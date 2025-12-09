module PS2_Interface(inclock, resetn, ps2_clock, ps2_data, ps2_key_data, ps2_key_pressed, last_data_received);

	/* ———————————————————————– Inputs / Outputs ———————————————————————– */
    input           inclock, resetn;
    inout           ps2_clock, ps2_data;
    output          ps2_key_pressed;
    output  [7:0]   ps2_key_data;     
    output  reg [7:0] last_data_received;

    // Wire to connect Controller output to Logic input
    wire [7:0] scan_code_wire;

    // Internal wire to the Output port
    assign ps2_key_data = scan_code_wire; 
    
    always @(posedge inclock)
    begin
        if (resetn == 1'b0)
            last_data_received <= 8'h00;
        else if (ps2_key_pressed == 1'b1)
            case (scan_code_wire) 			            // Check the wire coming from the controller

                /* Player 1 Keys */
                8'h1d: last_data_received <= 8'h57; 	// W
                8'h1b: last_data_received <= 8'h53; 	// S

                /* Player 2 Keys (O and K) */
                8'h44: last_data_received <= 8'h4F; 	// O
                8'h75: last_data_received <= 8'h4F; 	// Up Arrow -> O
                
                8'h42: last_data_received <= 8'h4B; 	// K 
                8'h72: last_data_received <= 8'h4B; 	// Down Arrow -> K
                
                default: last_data_received <= 8'h20; 	// space
            endcase
    end

    PS2_Controller PS2 (
        .CLOCK_50           (inclock),
        .reset              (~resetn),
        .PS2_CLK            (ps2_clock),
        .PS2_DAT            (ps2_data),
        .received_data      (scan_code_wire),
        .received_data_en   (ps2_key_pressed)
    );

endmodule