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
        
    output          VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK, VGA_SYNC;
    output  [7:0]   VGA_R, VGA_G, VGA_B;
    input           CLOCK_50;
    input           resetn;
    inout           ps2_data, ps2_clock;
    
    output             lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon;
    output  [7:0]   leds, lcd_data;
    output  [6:0]   seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8;
    output  [31:0]  debug_data_in;
    output   [11:0]   debug_addr;
    
    wire             clock;
    wire    [7:0]    ps2_key_data;
    wire             ps2_key_pressed;
    wire    [7:0]    ps2_out;
    
    pll div(CLOCK_50,inclock);
    assign clock = CLOCK_50;
    
    processor myprocessor(clock, ~resetn, debug_data_in, debug_addr);
    PS2_Interface myps2(clock, resetn, ps2_clock, ps2_data, ps2_key_data, ps2_key_pressed, ps2_out);
    lcd mylcd(clock, ~resetn, 1'b1, ps2_out, lcd_data, lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon);

    // ——————————————————————————————————————————————————
    // KEYBOARD MAPPING
    // ——————————————————————————————————————————————————
    wire w_on, s_on, o_on, l_on;

    assign w_on = (ps2_out == 8'h77); // 'w'
    assign s_on = (ps2_out == 8'h73); // 's'
    assign o_on = (ps2_out == 8'h6F); // 'o'
    assign l_on = (ps2_out == 8'h6C); // 'l'

    // Show active keys on LEDs for debugging
    assign leds = ps2_out; 

    Reset_Delay         r0  (.iCLK(CLOCK_50),.oRESET(DLY_RST)   );
    VGA_Audio_PLL       p1  (.areset(~DLY_RST),.inclk0(CLOCK_50),.c0(VGA_CTRL_CLK),.c1(AUD_CTRL_CLK),.c2(VGA_CLK)   );
    
    vga_controller vga_ins(.iRST_n(DLY_RST),
                                 .iVGA_CLK(VGA_CLK),
                                 .oBLANK_n(VGA_BLANK),
                                 .oHS(VGA_HS),
                                 .oVS(VGA_VS),
                                 .b_data(VGA_B),
                                 .g_data(VGA_G),
                                 .r_data(VGA_R),
                                 .w_in(w_on),
                                 .s_in(s_on),
                                 .o_in(o_on),
                                 .l_in(l_on)
                                 );
endmodule