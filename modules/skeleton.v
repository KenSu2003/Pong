module skeleton(resetn, 
    ps2_clock, ps2_data,                                        
    debug_data_in, debug_addr, leds,                        
    lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon,
    seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8,     
    VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK, VGA_SYNC, VGA_R, VGA_G, VGA_B, CLOCK_50);
        
    // ——————————————— PORTS ———————————————
    output VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK, VGA_SYNC;
    output [7:0] VGA_R, VGA_G, VGA_B;
    input CLOCK_50, resetn;
    inout ps2_data, ps2_clock;
    
    output lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon;
    output [7:0] leds, lcd_data;
    output [6:0] seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8;
    output [31:0] debug_data_in;
    output [11:0] debug_addr;
    
    // ——————————————— CLOCKS ———————————————
    wire clock;
    
    // BYPASS PLL: Use 50MHz directly to fix Reset issues
    assign clock = CLOCK_50;
    
    // ——————————————— PROCESSOR WIRES ———————————————
    wire [11:0] address_imem;
    wire [31:0] q_imem;
    wire [11:0] address_dmem;
    wire [31:0] data;
    wire wren;
    wire [31:0] q_dmem;
    wire ctrl_writeEnable;
    
    // ——————————————— REGFILE WIRES (NEW) ———————————————
    wire [4:0]  ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
    wire [31:0] data_writeReg, data_readRegA, data_readRegB;

    // ——————————————— MMIO REGISTERS ———————————————
    // Initialize to 200 so paddles appear in middle on reset
    reg [31:0] r_ball_x   = 320;
    reg [31:0] r_ball_y   = 240;
    reg [31:0] r_paddle_l = 200; 
    reg [31:0] r_paddle_r = 200;

    // ——————————————— MMIO LOGIC ———————————————
    wire [31:0] dmem_out_actual;
    assign q_dmem = (address_dmem == 12'd2000) ? {24'b0, ps2_out} : dmem_out_actual;

    always @(posedge clock) begin
        if (resetn == 1'b0) begin
            r_ball_x   <= 320;
            r_ball_y   <= 240;
            r_paddle_l <= 200;
            r_paddle_r <= 200;
        end
        else if (wren) begin
            case (address_dmem)
                12'd3000: r_ball_x   <= data;
                12'd3001: r_ball_y   <= data;
                12'd3002: r_paddle_l <= data;
                12'd3003: r_paddle_r <= data;
            endcase
        end
    end

    wire actual_dmem_wren;
    assign actual_dmem_wren = wren && (address_dmem < 12'd2000);

    // ——————————————— MODULE INSTANTIATIONS ———————————————

    imem my_imem(
        .address    (address_imem),
        .clock      (clock),
        .q          (q_imem)
    );

    dmem my_dmem(
        .address    (address_dmem),
        .clock      (clock),
        .data       (data),
        .wren       (actual_dmem_wren),
        .q          (dmem_out_actual)
    );

    // 1. YOUR REGFILE (This was missing!)
    // Inside skeleton.v
    regfile my_regfile(
        .clock(clock),
        .ctrl_writeEnable(ctrl_writeEnable),
        .ctrl_reset(~resetn),              // <— Must match "reset" in your regfile.v
        .ctrl_writeReg(ctrl_writeReg),
        .ctrl_readRegA(ctrl_readRegA),
        .ctrl_readRegB(ctrl_readRegB),
        .data_writeReg(data_writeReg),
        .data_readRegA(data_readRegA),
        .data_readRegB(data_readRegB)
    );

    // 2. YOUR PROCESSOR (Now connected to Regfile)
    processor myprocessor(
        .clock(clock), 
        .reset(~resetn), 
        .address_imem(address_imem), 
        .q_imem(q_imem), 
        .address_dmem(address_dmem), 
        .data(data), 
        .wren(wren), 
        .q_dmem(q_dmem), 
        .ctrl_writeEnable(ctrl_writeEnable),
        // Connect these ports to the Regfile wires above
        .ctrl_writeReg(ctrl_writeReg), 
        .ctrl_readRegA(ctrl_readRegA), 
        .ctrl_readRegB(ctrl_readRegB), 
        .data_writeReg(data_writeReg), 
        .data_readRegA(data_readRegA), 
        .data_readRegB(data_readRegB)
    );

    PS2_Interface myps2(clock, resetn, ps2_clock, ps2_data, ps2_key_data, ps2_key_pressed, ps2_out);
    
    lcd mylcd(clock, ~resetn, 1'b1, ps2_out, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);
//    assign leds = ps2_out;

	 assign leds[0] = wren; 
    assign leds[1] = clock;
    assign leds[7:2] = address_dmem[5:0];


    Reset_Delay r0 (.iCLK(CLOCK_50), .oRESET(DLY_RST));
    VGA_Audio_PLL p1 (.areset(~DLY_RST), .inclk0(CLOCK_50), .c0(VGA_CTRL_CLK), .c1(AUD_CTRL_CLK), .c2(VGA_CLK));
    
    vga_controller vga_ins(
        .iRST_n(DLY_RST),
        .iVGA_CLK(VGA_CLK),
        .oBLANK_n(VGA_BLANK),
        .oHS(VGA_HS),
        .oVS(VGA_VS),
        .b_data(VGA_B),
        .g_data(VGA_G),
        .r_data(VGA_R),
        .ball_x(r_ball_x[9:0]),
        .ball_y(r_ball_y[8:0]),
        .paddle_left_y(r_paddle_l[8:0]),
        .paddle_right_y(r_paddle_r[8:0])
    );
    
endmodule