module skeleton(
    resetn, 
    // PS2
    ps2_clock, ps2_data,                     // ps2 related I/O

    // Debug
    debug_data_in, debug_addr, leds,         // extra debugging ports

    // LCD
    lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon,

    // Seven segments
    seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8,

    // VGA
    VGA_CLK,                                 // VGA Clock
    VGA_HS,                                  // VGA H_SYNC
    VGA_VS,                                  // VGA V_SYNC
    VGA_BLANK,                               // VGA BLANK
    VGA_SYNC,                                // VGA SYNC
    VGA_R,                                   // VGA Red
    VGA_G,                                   // VGA Green
    VGA_B,                                   // VGA Blue

    // Base clock
    CLOCK_50                                 // 50 MHz clock
);

    ////////////////////////  PORT DECLARATIONS  ////////////////////////////

    // VGA
    output          VGA_CLK;    
    output          VGA_HS;     
    output          VGA_VS;     
    output          VGA_BLANK;  
    output          VGA_SYNC;   
    output  [7:0]   VGA_R;      
    output  [7:0]   VGA_G;      
    output  [7:0]   VGA_B;      
    input           CLOCK_50;

    // PS2
    input           resetn;
    inout           ps2_data, ps2_clock;
    
    // LCD and Seven Segment
    output              lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon;
    output  [7:0]       leds, lcd_data;
    output  [6:0]       seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8;

    // Debug ports
    output  [31:0]      debug_data_in;
    output  [11:0]      debug_addr;

    ////////////////////////  INTERNAL SIGNALS  ////////////////////////////

    wire        clock;          // CPU clock (from PLL divider)
    wire        inclock;        // PLL output

    // PS2
    wire [7:0]  ps2_key_data;
    wire        ps2_key_pressed;
    wire [7:0]  ps2_out;        // last mapped key (W/S/O/K or space)

    // VGA game coordinates from processor
    wire [9:0]  w_ball_x;
    wire [8:0]  w_ball_y;
    wire [8:0]  w_paddle_left;
    wire [8:0]  w_paddle_right;

    // IMEM / DMEM interface with processor
    wire [11:0] proc_imem_addr;
    wire [31:0] proc_imem_q;

    wire [11:0] proc_dmem_addr;
    wire [31:0] proc_dmem_data_out;
    wire [31:0] proc_dmem_q;
    wire        proc_dmem_wren;

    // DMEM write safety
    wire        actual_dmem_wren;

    // VGA PLL helpers
    wire        DLY_RST;
    wire        VGA_CTRL_CLK;
    wire        AUD_CTRL_CLK;

    ////////////////////////  CLOCK GENERATION  ////////////////////////////
    // Project PLL: 50 MHz -> slower CPU clock (e.g. 10 MHz)
    // NOTE: This uses positional ports as in your original:
    //       pll div ( .inclk0(CLOCK_50), .c0(inclock) );
    pll div (CLOCK_50, inclock);
    assign clock = inclock;   // CPU clock

    ////////////////////////  MEMORY INSTANTIATION  ////////////////////////

    // Instruction Memory (imem)
    // Your current imem.v has ports: address, clock, q
    imem myimem(
        .address (proc_imem_addr),
        .clock   (clock),
        .q       (proc_imem_q)
    );

    // Data Memory (dmem)
    // SAFETY: only write to RAM when address < 2000.
    // Writes to 3000–3003 are still visible to the processor (via wren/address)
    // and used for VGA MMIO inside processor.v, but won’t go into RAM.
    assign actual_dmem_wren = proc_dmem_wren && (proc_dmem_addr < 12'd2000);

    dmem mydmem(
        .address (proc_dmem_addr),
        .clock   (clock),
        .data    (proc_dmem_data_out),
        .wren    (actual_dmem_wren),
        .q       (proc_dmem_q)
    );

    ////////////////////////  PROCESSOR  ///////////////////////////////////

    processor myprocessor(
        .clock          (clock), 
        .reset          (~resetn), 
        
        // IMEM
        .address_imem   (proc_imem_addr),
        .q_imem         (proc_imem_q),
        
        // DMEM
        .address_dmem   (proc_dmem_addr),
        .data           (proc_dmem_data_out),
        .wren           (proc_dmem_wren),
        .q_dmem         (proc_dmem_q),
        
        // PONG I/O
        .ps2_key_pressed(ps2_key_pressed),
        .ps2_out        (ps2_out),
        .vga_ball_x     (w_ball_x),
        .vga_ball_y     (w_ball_y),
        .vga_paddle_left(w_paddle_left),
        .vga_paddle_right(w_paddle_right),
        
        // Grader / debug ports
        .ctrl_writeEnable(),
        .ctrl_writeReg (),
        .ctrl_readRegA(),
        .ctrl_readRegB(),
        .data_writeReg(),
        .data_readRegA (32'b0),
        .data_readRegB (32'b0)
    );

    // Debug outputs: show last DMEM write from CPU
    assign debug_data_in = proc_dmem_data_out;
    assign debug_addr    = proc_dmem_addr;

    ////////////////////////  PS2 INTERFACE  ///////////////////////////////

    PS2_Interface myps2(
        .inclock           (clock), 
        .resetn            (resetn), 
        .ps2_clock         (ps2_clock), 
        .ps2_data          (ps2_data), 
        .ps2_key_data      (ps2_key_data), 
        .ps2_key_pressed   (ps2_key_pressed), 
        .last_data_received(ps2_out)
    );

    ////////////////////////  VGA CONTROLLER  //////////////////////////////

    // Reset delay and VGA PLL (from DE2 reference)
    Reset_Delay r0 (
        .iCLK   (CLOCK_50),
        .oRESET (DLY_RST)
    );

    VGA_Audio_PLL p1 (
        .areset (~DLY_RST),
        .inclk0 (CLOCK_50),
        .c0     (VGA_CTRL_CLK),
        .c1     (AUD_CTRL_CLK),
        .c2     (VGA_CLK)
    );

    // Some designs use VGA_SYNC tied low
    assign VGA_SYNC = 1'b0;

    vga_controller vga_ins(
        .iRST_n        (DLY_RST),
        .iVGA_CLK      (VGA_CLK),
        .oBLANK_n      (VGA_BLANK),
        .oHS           (VGA_HS),
        .oVS           (VGA_VS),
        .b_data        (VGA_B),
        .g_data        (VGA_G),
        .r_data        (VGA_R),

        // Coordinates from processor
        .ball_x        (w_ball_x),
        .ball_y        (w_ball_y),
        .paddle_left_y (w_paddle_left),
        .paddle_right_y(w_paddle_right)
    );

    ////////////////////////  LCD & HEX DISPLAY  ///////////////////////////

    // LCD shows last PS2 key (ASCII) from ps2_out
    lcd mylcd(
        clock,
        ~resetn,
        1'b1,
        ps2_out,
        lcd_data,
        lcd_rw,
        lcd_en,
        lcd_rs,
        lcd_on,
        lcd_blon
    );

    // HEX0–HEX1 show last key (lower and upper nibble)
    Hexadecimal_To_Seven_Segment hex1(ps2_out[3:0], seg1);
    Hexadecimal_To_Seven_Segment hex2(ps2_out[7:4], seg2);

    // Remaining HEX are 0
    Hexadecimal_To_Seven_Segment hex3(4'b0000, seg3);
    Hexadecimal_To_Seven_Segment hex4(4'b0000, seg4);
    Hexadecimal_To_Seven_Segment hex5(4'b0000, seg5);
    Hexadecimal_To_Seven_Segment hex6(4'b0000, seg6);
    Hexadecimal_To_Seven_Segment hex7(4'b0000, seg7);
    Hexadecimal_To_Seven_Segment hex8(4'b0000, seg8);

    // LEDs show last PS2 key
    assign leds = ps2_out;

endmodule
