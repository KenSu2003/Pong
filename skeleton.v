module skeleton(
    input         resetn, 
    inout         ps2_clock, ps2_data,
    output [31:0] debug_data_in,
    output [11:0] debug_addr,
    output [7:0]  leds,
    output [7:0]  lcd_data,
    output        lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon,
    output [6:0]  seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8,

    // VGA
    output        VGA_CLK,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_BLANK,
    output        VGA_SYNC,
    output [7:0]  VGA_R,
    output [7:0]  VGA_G,
    output [7:0]  VGA_B,

    input         CLOCK_50
);

    // ===============================================================
    // CPU CLOCK
    // ===============================================================
    wire clock = CLOCK_50;

    // ===============================================================
    // CPU <-> IMEM / DMEM wires
    // ===============================================================
    wire [11:0] proc_imem_addr;
    wire [31:0] proc_imem_q;

    wire [11:0] proc_dmem_addr;
    wire [31:0] proc_dmem_data_out;
    wire [31:0] proc_dmem_q;
    wire        proc_dmem_wren;

    // ===============================================================
    // PS2
    // ===============================================================
    wire [7:0] ps2_key_data;
    wire       ps2_key_pressed;
    wire [7:0] ps2_last_key;

    // ===============================================================
    // GAME STATE REGISTERS (MMIO)
    // ===============================================================
    reg [9:0] ball_x, ball_y;
    reg [8:0] paddle_left_y, paddle_right_y;
    reg [7:0] score_reg;

    // ===============================================================
    // IMEM
    // ===============================================================
	 imem myimem(
		  .address(proc_imem_addr),
		  .clock(clock),
		  .q(proc_imem_q)
	 );


    // ===============================================================
    // DMEM (write-protected above 2000)
    // ===============================================================
    wire actual_dmem_wren = proc_dmem_wren && (proc_dmem_addr < 12'd2000);
    wire [31:0] dmem_q;

    dmem mydmem(
        .address(proc_dmem_addr),
        .clock(clock),
        .data(proc_dmem_data_out),
        .wren(actual_dmem_wren),
        .q(dmem_q)
    );

    // ===============================================================
    // PROCESSOR
    // ===============================================================
    processor myprocessor(
        .clock(clock),
        .reset(~resetn),
        .address_imem(proc_imem_addr),
        .q_imem(proc_imem_q),
        .address_dmem(proc_dmem_addr),
        .data(proc_dmem_data_out),
        .wren(proc_dmem_wren),
        .q_dmem(proc_dmem_q),

        // Unconnected register-file debug ports
        .ctrl_writeEnable(),
        .ctrl_writeReg(),
        .ctrl_readRegA(),
        .ctrl_readRegB(),
        .data_writeReg(),
        .data_readRegA(32'b0),
        .data_readRegB(32'b0)
    );

    // Debug: show dmem writes on LEDs/debugger
    assign debug_data_in = proc_dmem_data_out;
    assign debug_addr    = proc_dmem_addr;

    // ===============================================================
    // PS2 INTERFACE
    // ===============================================================
    PS2_Interface myps2(
        .inclock(clock),
        .resetn(resetn),
        .ps2_clock(ps2_clock),
        .ps2_data(ps2_data),
        .ps2_key_pressed(ps2_key_pressed),
        .ps2_key_data(ps2_key_data),
        .last_data_received(ps2_last_key)
    );

    // ===============================================================
    // MMIO READ
    // ===============================================================
    assign proc_dmem_q =
          (proc_dmem_addr == 12'd2000) ? {24'b0, ps2_last_key} :
          (proc_dmem_addr == 12'd2010) ? {22'b0, ball_x} :
          (proc_dmem_addr == 12'd2011) ? {23'b0, ball_y} :
          (proc_dmem_addr == 12'd2012) ? {23'b0, paddle_left_y} :
          (proc_dmem_addr == 12'd2013) ? {23'b0, paddle_right_y} :
          (proc_dmem_addr == 12'd2014) ? {24'b0, score_reg} :
                                         dmem_q;

    // ===============================================================
    // MMIO WRITE
    // ===============================================================
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            ball_x        <= 10'd315;
            ball_y        <= 10'd235;
            paddle_left_y <= 9'd220;
            paddle_right_y<= 9'd220;
            score_reg     <= 8'd0;
        end
        else if (proc_dmem_wren && (proc_dmem_addr >= 12'd2000)) begin
            case (proc_dmem_addr)
                12'd2010: ball_x        <= proc_dmem_data_out[9:0];
                12'd2011: ball_y        <= proc_dmem_data_out[8:0];
                12'd2012: paddle_left_y <= proc_dmem_data_out[8:0];
                12'd2013: paddle_right_y<= proc_dmem_data_out[8:0];
                12'd2014: score_reg     <= proc_dmem_data_out[7:0];
                default: ;
            endcase
        end
    end

    // ===============================================================
    // VGA CLOCK / SYNC (NO PLL)
    // ===============================================================
    assign VGA_CLK      = CLOCK_50;
    assign VGA_SYNC     = 1'b0; // required by some monitors

    // VGA controller (NO score port)
    vga_controller vga_ins(
        .iRST_n(resetn),
        .iVGA_CLK(VGA_CLK),
        .oBLANK_n(VGA_BLANK),
        .oHS(VGA_HS),
        .oVS(VGA_VS),
        .b_data(VGA_B),
        .g_data(VGA_G),
        .r_data(VGA_R),

        .ball_x(ball_x),
        .ball_y(ball_y),
        .paddle_left_y(paddle_left_y),
        .paddle_right_y(paddle_right_y),
		  .score(score_reg)
    );

    // ===============================================================
    // LCD DISPLAY (shows last PS2 key)
    // ===============================================================
    lcd mylcd(clock, ~resetn, 1'b1, ps2_last_key,
              lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);

    // ===============================================================
    // HEX DISPLAYS
    // ===============================================================
    Hexadecimal_To_Seven_Segment hex1(ps2_last_key[3:0], seg1);
    Hexadecimal_To_Seven_Segment hex2(ps2_last_key[7:4], seg2);
    Hexadecimal_To_Seven_Segment hex3(4'b0, seg3);
    Hexadecimal_To_Seven_Segment hex4(4'b0, seg4);
    Hexadecimal_To_Seven_Segment hex5(4'b0, seg5);
    Hexadecimal_To_Seven_Segment hex6(4'b0, seg6);
    Hexadecimal_To_Seven_Segment hex7(4'b0, seg7);
    Hexadecimal_To_Seven_Segment hex8(4'b0, seg8);

    // LEDs show last PS2 key
    assign leds = ps2_last_key;

endmodule
