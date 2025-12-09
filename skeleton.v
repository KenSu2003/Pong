module skeleton(resetn, 
	ps2_clock, ps2_data, 										
	debug_data_in, debug_addr, leds, 						
	lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon,
	seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8,		
	VGA_CLK,   														
	VGA_HS,															
	VGA_VS,															
	VGA_BLANK,														
	VGA_SYNC,														
	VGA_R,   														
	VGA_G,	 														
	VGA_B,															
	CLOCK_50);
		
	////////////////////////	VGA	////////////////////////////
	output			VGA_CLK;   				
	output			VGA_HS;					
	output			VGA_VS;					
	output			VGA_BLANK;				
	output			VGA_SYNC;				
	output	[7:0]	VGA_R;   				
	output	[7:0]	VGA_G;	 				
	output	[7:0]	VGA_B;   				
	input				CLOCK_50;

	////////////////////////	PS2	////////////////////////////
	input 			resetn;
	inout 			ps2_data, ps2_clock;
	
	////////////////////////	LCD and Seven Segment	////////////////////////////
	output 			   lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon;
	output 	[7:0] 	leds, lcd_data;
	output 	[6:0] 	seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8;
	output 	[31:0] 	debug_data_in;
	output   [11:0]   debug_addr;
	
	wire			 clock;
	wire			 lcd_write_en;
	wire 	[31:0] lcd_write_data;
	wire	[7:0]	 ps2_key_data;
	wire			 ps2_key_pressed;
	wire	[7:0]	 ps2_out;
	
	// Clock divider
	pll div(CLOCK_50,inclock);
	assign clock = CLOCK_50;
	
	// your processor
	processor myprocessor(clock, ~resetn, /*ps2_key_pressed, ps2_out, lcd_write_en, lcd_write_data,*/ debug_data_in, debug_addr);

	// keyboard controller
	PS2_Interface myps2(clock, resetn, ps2_clock, ps2_data, ps2_key_data, ps2_key_pressed, ps2_out);
	
	// lcd controller
	lcd mylcd(clock, ~resetn, 1'b1, ps2_out, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);

	// ——————————————————————————————————————————————————
	// KEYBOARD LOGIC: Map Hex Codes to Boolean Wires
	// ——————————————————————————————————————————————————
	wire w_on, s_on, o_on, k_on;

	// Note: PS2_Interface holds the LAST key pressed. 
	// To stop moving, you'd usually press a specific "stop" key or modify PS2 logic.
	// For now, we assume simple state holding.
	assign w_on = (ps2_out == 8'h57); // 'W'
	assign s_on = (ps2_out == 8'h53); // 'S'
	assign o_on = (ps2_out == 8'h4F); // 'O'
	assign k_on = (ps2_out == 8'h4B); // 'K'

	// VGA Controller
	Reset_Delay			r0	(.iCLK(CLOCK_50),.oRESET(DLY_RST)	);
	VGA_Audio_PLL 		p1	(.areset(~DLY_RST),.inclk0(CLOCK_50),.c0(VGA_CTRL_CLK),.c1(AUD_CTRL_CLK),.c2(VGA_CLK)	);
	
	vga_controller vga_ins(.iRST_n(DLY_RST),
								 .iVGA_CLK(VGA_CLK),
								 .oBLANK_n(VGA_BLANK),
								 .oHS(VGA_HS),
								 .oVS(VGA_VS),
								 .b_data(VGA_B),
								 .g_data(VGA_G),
								 .r_data(VGA_R),
								 // Connect Control Wires
								 .w_in(w_on),
								 .s_in(s_on),
								 .o_in(o_on),
								 .k_in(k_on)
								 );
	
endmodule