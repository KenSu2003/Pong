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

module skeleton(resetn, 
	ps2_clock, ps2_data, 											// ps2 related I/O
	debug_data_in, debug_addr, leds, 								// extra debugging ports
	lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon,				// LCD info
	seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8,					// seven segements
	VGA_CLK,   														//	VGA Clock
	VGA_HS,															//	VGA H_SYNC
	VGA_VS,															//	VGA V_SYNC
	VGA_BLANK,														//	VGA BLANK
	VGA_SYNC,														//	VGA SYNC
	VGA_R,   														//	VGA Red[9:0]
	VGA_G,	 														//	VGA Green[9:0]
	VGA_B,															//	VGA Blue[9:0]
	CLOCK_50);


	/* ******************** VGA ******************** */
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK;				//	VGA BLANK
	output			VGA_SYNC;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[9:0]
	output	[7:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[9:0]
	input				CLOCK_50;

	
	/* ********** PS2 Controller ********** */
	input 			resetn;
	inout 			ps2_data, ps2_clock;
	

	/* ******************** LCD and 7-Segment Display ******************** */
	output 			   lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon;
	output 	[7:0] 	leds, lcd_data;
	output 	[6:0] 	seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8;
	output 	[31:0] 	debug_data_in;
	output   [11:0]   debug_addr;
	
	wire			 clock;
	wire			 lcd_write_en;
	wire 	[31:0] lcd_write_data;

	
	/* ********** Wires for the Game ********** */
	wire [7:0] ps2_key_data;
	wire ps2_key_pressed;
	wire [7:0] ps2_out;	
	

	/* ********** PROCESSOR INTERFACE WIRES ********** */
	wire [11:0] proc_imem_addr;
	wire [31:0] proc_imem_q;
	
	wire [11:0] proc_dmem_addr;
	wire [31:0] proc_dmem_data_out;
	wire [31:0] proc_dmem_q;
	wire        proc_dmem_wren;
	
	// ********** Clock Divider (50MHz -> 10MHz) **********
	pll div(CLOCK_50,inclock);
	assign clock = CLOCK_50; // Use 50MHz for VGA compatibility, or 'inclock' if your processor is slow
	
	// ********** Instruction Memory **********
	imem myimem(
		.address    (proc_imem_addr),
		.clken      (1'b1),
		.clock      (clock),
		.q          (proc_imem_q)
	);

	// ********** Data Memory **********
	/* ——————————————————————————————————————————————————————————————————————
		SAFETY LOGIC: Only allow writes to DMEM if address < 2000.
		If address is >= 2000 (like 3000 for VGA), we block the write to RAM
		so we don't corrupt memory while talking to I/O.
	   —————————————————————————————————————————————————————————————————————— */
	wire actual_dmem_wren;
	assign actual_dmem_wren = proc_dmem_wren && (proc_dmem_addr < 12'd2000);

	dmem mydmem(
		.address    (proc_dmem_addr),
		.clock      (clock),
		.data       (proc_dmem_data_out),
		.wren       (actual_dmem_wren),
		.q          (proc_dmem_q)
	);

	// ********** Processor **********
	processor myprocessor(
		.clock(clock), 
		.reset(~resetn), 
		
		// IMEM Connections
		.address_imem(proc_imem_addr),
		.q_imem(proc_imem_q),
		
		// DMEM Connections
		.address_dmem(proc_dmem_addr),
		.data(proc_dmem_data_out),
		.wren(proc_dmem_wren),
		.q_dmem(proc_dmem_q),
		
		// PONG I/O Connections
		.ps2_key_pressed(ps2_key_pressed),
		.ps2_out(ps2_out),
		.vga_ball_x(w_ball_x),
		.vga_ball_y(w_ball_y),
		.vga_paddle_left(w_paddle_left),
		.vga_paddle_right(w_paddle_right),
		
		// Grader/Debug Ports (Unused inputs tied to 0, Outputs to debug ports)
		.ctrl_writeEnable(),
		.ctrl_writeReg(),
		.ctrl_readRegA(),
		.ctrl_readRegB(),
		.data_writeReg(),
		.data_readRegA(32'b0),
		.data_readRegB(32'b0)
	);

	// Output Processor signals to Debug Ports so you can see them on the board/Waveform
	assign debug_data_in = proc_dmem_data_out;
	assign debug_addr    = proc_dmem_addr;



	// ********** PS2 **********
	PS2_Interface myps2(
		.inclock(clock), 
		.resetn(resetn), 
		.ps2_clock(ps2_clock), 
		.ps2_data(ps2_data), 
		.ps2_key_data(ps2_key_data), 
		.ps2_key_pressed(ps2_key_pressed), 
		.last_data_received(ps2_out)
	);

	// ********** VGA **********
	Reset_Delay			r0	(.iCLK(CLOCK_50),.oRESET(DLY_RST)	);
	VGA_Audio_PLL 		p1	(
							.areset(~DLY_RST),
							.inclk0(CLOCK_50),
							.c0(VGA_CTRL_CLK),
							.c1(AUD_CTRL_CLK),
							.c2(VGA_CLK)	
							);
	
	vga_controller vga_ins(
						.iRST_n(DLY_RST),
						.iVGA_CLK(VGA_CLK),
						.oBLANK_n(VGA_BLANK),
						.oHS(VGA_HS),
						.oVS(VGA_VS),
						.b_data(VGA_B),
						.g_data(VGA_G),
						.r_data(VGA_R),
						
						// Coordinates from Processor
						.ball_x(w_ball_x),
						.ball_y(w_ball_y),
						.paddle_left_y(w_paddle_left),
						.paddle_right_y(w_paddle_right)
	);

	
	// lcd controller
	lcd mylcd(clock, ~resetn, 1'b1, ps2_out, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);

	// Show the last key pressed on the first two Hex displays
	Hexadecimal_To_Seven_Segment hex1(ps2_out[3:0], seg1);
	Hexadecimal_To_Seven_Segment hex2(ps2_out[7:4], seg2);
	
	// The rest are 0
	Hexadecimal_To_Seven_Segment hex3(4'b0, seg3);
	Hexadecimal_To_Seven_Segment hex4(4'b0, seg4);
	Hexadecimal_To_Seven_Segment hex5(4'b0, seg5);
	Hexadecimal_To_Seven_Segment hex6(4'b0, seg6);
	Hexadecimal_To_Seven_Segment hex7(4'b0, seg7);
	Hexadecimal_To_Seven_Segment hex8(4'b0, seg8);
	
	// Show key press on LEDs
	assign leds = ps2_out;




endmodule