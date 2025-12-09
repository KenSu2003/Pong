module vga_controller(
    input        iRST_n,
    input        iVGA_CLK,
    output reg   oBLANK_n,
    output reg   oHS,
    output reg   oVS,
    output reg [7:0] b_data,
    output reg [7:0] g_data,
    output reg [7:0] r_data,

    // Game objects from processor
    input  [9:0] ball_x,
    input  [9:0] ball_y,
    input  [8:0] paddle_left_y,
    input  [8:0] paddle_right_y,
    input  [7:0] score
);

    //------------------------------------------------------------
    // 1. VGA SYNC + PIXEL COORDINATES
    //------------------------------------------------------------
    wire rst = ~iRST_n;

    wire cBLANK_n, cHS, cVS;

    video_sync_generator sync_inst (
        .vga_clk(iVGA_CLK),
        .reset(rst),
        .blank_n(cBLANK_n),
        .HS(cHS),
        .VS(cVS)
    );

    reg [18:0] addr;

    always @(posedge iVGA_CLK or negedge iRST_n) begin
        if (!iRST_n)
            addr <= 19'd0;
        else if ((cHS == 1'b0) && (cVS == 1'b0))
            addr <= 19'd0;
        else if (cBLANK_n)
            addr <= addr + 19'd1;
    end

    wire [9:0] pixel_x = addr % 10'd640;
    wire [8:0] pixel_y = addr / 10'd640;

    //------------------------------------------------------------
    // 2. GAME OBJECTS (BALL & PADDLES)
    //------------------------------------------------------------
    localparam BALL_SIZE = 10;
    localparam PADDLE_W  = 10;
    localparam PADDLE_H  = 40;

    wire in_ball =
        (pixel_x >= ball_x) &&
        (pixel_x <  ball_x + BALL_SIZE) &&
        (pixel_y >= ball_y) &&
        (pixel_y <  ball_y + BALL_SIZE);

    wire in_paddle_left =
        (pixel_x >= 20) &&
        (pixel_x <  20 + PADDLE_W) &&
        (pixel_y >= paddle_left_y) &&
        (pixel_y <  paddle_left_y + PADDLE_H);

    wire in_paddle_right =
        (pixel_x >= 610) &&
        (pixel_x <  610 + PADDLE_W) &&
        (pixel_y >= paddle_right_y) &&
        (pixel_y <  paddle_right_y + PADDLE_H);

    //------------------------------------------------------------
    // 3. DIGIT FONT (0–9), 8×8
    //------------------------------------------------------------
    reg [7:0] digit_font [0:79];

    initial begin
        // 0
        digit_font[0] = 8'b00111100;
        digit_font[1] = 8'b01000010;
        digit_font[2] = 8'b01000010;
        digit_font[3] = 8'b01000010;
        digit_font[4] = 8'b01000010;
        digit_font[5] = 8'b01000010;
        digit_font[6] = 8'b00111100;
        digit_font[7] = 8'b00000000;

        // 1
        digit_font[8] = 8'b00001000;
        digit_font[9] = 8'b00011000;
        digit_font[10]= 8'b00001000;
        digit_font[11]= 8'b00001000;
        digit_font[12]= 8'b00001000;
        digit_font[13]= 8'b00001000;
        digit_font[14]= 8'b00111100;
        digit_font[15]= 8'b00000000;

        // 2
        digit_font[16]= 8'b00111100;
        digit_font[17]= 8'b01000010;
        digit_font[18]= 8'b00000010;
        digit_font[19]= 8'b00111100;
        digit_font[20]= 8'b01000000;
        digit_font[21]= 8'b01000010;
        digit_font[22]= 8'b01111110;
        digit_font[23]= 8'b00000000;

        // 3
        digit_font[24]= 8'b00111100;
        digit_font[25]= 8'b01000010;
        digit_font[26]= 8'b00000010;
        digit_font[27]= 8'b00011100;
        digit_font[28]= 8'b00000010;
        digit_font[29]= 8'b01000010;
        digit_font[30]= 8'b00111100;
        digit_font[31]= 8'b00000000;

        // 4
        digit_font[32]= 8'b00000100;
        digit_font[33]= 8'b00001100;
        digit_font[34]= 8'b00010100;
        digit_font[35]= 8'b00100100;
        digit_font[36]= 8'b01111110;
        digit_font[37]= 8'b00000100;
        digit_font[38]= 8'b00000100;
        digit_font[39]= 8'b00000000;

        // 5
        digit_font[40]= 8'b01111110;
        digit_font[41]= 8'b01000000;
        digit_font[42]= 8'b01000000;
        digit_font[43]= 8'b01111100;
        digit_font[44]= 8'b00000010;
        digit_font[45]= 8'b01000010;
        digit_font[46]= 8'b00111100;
        digit_font[47]= 8'b00000000;

        // 6
        digit_font[48]= 8'b00111100;
        digit_font[49]= 8'b01000010;
        digit_font[50]= 8'b01000000;
        digit_font[51]= 8'b01111100;
        digit_font[52]= 8'b01000010;
        digit_font[53]= 8'b01000010;
        digit_font[54]= 8'b00111100;
        digit_font[55]= 8'b00000000;

        // 7
        digit_font[56]= 8'b01111110;
        digit_font[57]= 8'b00000010;
        digit_font[58]= 8'b00000100;
        digit_font[59]= 8'b00001000;
        digit_font[60]= 8'b00010000;
        digit_font[61]= 8'b00100000;
        digit_font[62]= 8'b00100000;
        digit_font[63]= 8'b00000000;

        // 8
        digit_font[64]= 8'b00111100;
        digit_font[65]= 8'b01000010;
        digit_font[66]= 8'b01000010;
        digit_font[67]= 8'b00111100;
        digit_font[68]= 8'b01000010;
        digit_font[69]= 8'b01000010;
        digit_font[70]= 8'b00111100;
        digit_font[71]= 8'b00000000;

        // 9
        digit_font[72]= 8'b00111100;
        digit_font[73]= 8'b01000010;
        digit_font[74]= 8'b01000010;
        digit_font[75]= 8'b00111110;
        digit_font[76]= 8'b00000010;
        digit_font[77]= 8'b00000010;
        digit_font[78]= 8'b00111100;
        digit_font[79]= 8'b00000000;
    end

    //------------------------------------------------------------
    // SCORE DECODING (TWO DIGITS / 16x16 SCALED)
    //------------------------------------------------------------
    wire [3:0] score_ones = score % 8'd10;
    wire [3:0] score_tens = score / 8'd10;

    localparam SCORE_X       = 300;
    localparam SCORE_Y       = 20;
    localparam CHAR_W        = 16;
    localparam CHAR_H        = 16;
    localparam SCORE_SPACING = 20;

    wire in_tens =
        (pixel_x >= SCORE_X) &&
        (pixel_x <  SCORE_X + CHAR_W) &&
        (pixel_y >= SCORE_Y) &&
        (pixel_y <  SCORE_Y + CHAR_H);

    wire in_ones =
        (pixel_x >= SCORE_X + SCORE_SPACING) &&
        (pixel_x <  SCORE_X + SCORE_SPACING + CHAR_W) &&
        (pixel_y >= SCORE_Y) &&
        (pixel_y <  SCORE_Y + CHAR_H);

    wire [3:0] tens_px   = pixel_x - SCORE_X;
    wire [3:0] ones_px   = pixel_x - (SCORE_X + SCORE_SPACING);
    wire [3:0] digit_py  = pixel_y - SCORE_Y;

    wire [2:0] fx_tens = tens_px[3:1];
    wire [2:0] fx_ones = ones_px[3:1];
    wire [2:0] fy      = digit_py[3:1];

    wire [6:0] tens_index = {score_tens, 3'b000} + fy;
    wire [6:0] ones_index = {score_ones, 3'b000} + fy;

    wire [7:0] tens_row = digit_font[tens_index];
    wire [7:0] ones_row = digit_font[ones_index];

    wire tens_on = in_tens && tens_row[7 - fx_tens];
    wire ones_on = in_ones && ones_row[7 - fx_ones];

    wire draw_score_pixel = tens_on | ones_on;

    //------------------------------------------------------------
    // TITLE LOGIC – P O N G (16×16 LETTERS)
    //------------------------------------------------------------
    reg [7:0] letter_font [0:31];
    initial begin
        // P
        letter_font[0]=8'b01111100;
        letter_font[1]=8'b01000010;
        letter_font[2]=8'b01000010;
        letter_font[3]=8'b01111100;
        letter_font[4]=8'b01000000;
        letter_font[5]=8'b01000000;
        letter_font[6]=8'b01000000;
        letter_font[7]=8'b00000000;

        // O
        letter_font[8]=8'b00111100;
        letter_font[9]=8'b01000010;
        letter_font[10]=8'b01000010;
        letter_font[11]=8'b01000010;
        letter_font[12]=8'b01000010;
        letter_font[13]=8'b01000010;
        letter_font[14]=8'b00111100;
        letter_font[15]=8'b00000000;

        // N
        letter_font[16]=8'b01000010;
        letter_font[17]=8'b01100010;
        letter_font[18]=8'b01010010;
        letter_font[19]=8'b01001010;
        letter_font[20]=8'b01000110;
        letter_font[21]=8'b01000010;
        letter_font[22]=8'b01000010;
        letter_font[23]=8'b00000000;

        // G
        letter_font[24]=8'b00111100;
        letter_font[25]=8'b01000010;
        letter_font[26]=8'b01000000;
        letter_font[27]=8'b01001110;
        letter_font[28]=8'b01000010;
        letter_font[29]=8'b01000010;
        letter_font[30]=8'b00111100;
        letter_font[31]=8'b00000000;
    end

    localparam TITLE_X      = 200;
    localparam TITLE_Y      = 200;
    localparam T_W          = 16;
    localparam T_H          = 16;
    localparam T_SPACING    = 20;

    reg draw_title_pixel;

    // Temporary variables (declared here for ModelSim compatibility)
    reg [3:0] ty;
    reg [3:0] tx;
    reg [2:0] fy_title;
    reg [2:0] fx_title;
    reg [6:0] t_index;
    reg [7:0] t_row;

    // TITLE DISPLAY TIME
    reg last_vs;
    reg [9:0] title_counter;
    localparam TITLE_MAX = 10'd180;

    wire vs_rise = (~last_vs) & cVS;

    always @(posedge iVGA_CLK or negedge iRST_n) begin
        if (!iRST_n) begin
            last_vs <= 0;
            title_counter <= 0;
        end else begin
            last_vs <= cVS;
            if (vs_rise && title_counter < TITLE_MAX)
                title_counter <= title_counter + 10'd1;
        end
    end

    wire title_active = (title_counter < TITLE_MAX);

    // TITLE DRAWING
    always @(*) begin
        draw_title_pixel = 1'b0;

        if (title_active &&
            pixel_y >= TITLE_Y &&
            pixel_y <  TITLE_Y + T_H) begin

            ty       = pixel_y - TITLE_Y;
            fy_title = ty[3:1];

            // P
            if (pixel_x >= TITLE_X &&
                pixel_x < TITLE_X + T_W) begin
                tx       = pixel_x - TITLE_X;
                fx_title = tx[3:1];
                t_index  = 7'd0 + fy_title;
                t_row    = letter_font[t_index];
                if (t_row[7 - fx_title])
                    draw_title_pixel = 1'b1;
            end

            // O
            if (pixel_x >= TITLE_X + T_SPACING &&
                pixel_x < TITLE_X + T_SPACING + T_W) begin
                tx       = pixel_x - (TITLE_X + T_SPACING);
                fx_title = tx[3:1];
                t_index  = 7'd8 + fy_title;
                t_row    = letter_font[t_index];
                if (t_row[7 - fx_title])
                    draw_title_pixel = 1'b1;
            end

            // N
            if (pixel_x >= TITLE_X + 2*T_SPACING &&
                pixel_x < TITLE_X + 2*T_SPACING + T_W) begin
                tx       = pixel_x - (TITLE_X + 2*T_SPACING);
                fx_title = tx[3:1];
                t_index  = 7'd16 + fy_title;
                t_row    = letter_font[t_index];
                if (t_row[7 - fx_title])
                    draw_title_pixel = 1'b1;
            end

            // G
            if (pixel_x >= TITLE_X + 3*T_SPACING &&
                pixel_x < TITLE_X + 3*T_SPACING + T_W) begin
                tx       = pixel_x - (TITLE_X + 3*T_SPACING);
                fx_title = tx[3:1];
                t_index  = 7'd24 + fy_title;
                t_row    = letter_font[t_index];
                if (t_row[7 - fx_title])
                    draw_title_pixel = 1'b1;
            end
        end
    end

    //------------------------------------------------------------
    // 7. FINAL COLOR OUTPUT
    //------------------------------------------------------------
    always @(posedge iVGA_CLK or negedge iRST_n) begin
        if (!iRST_n) begin
            r_data <= 0;
            g_data <= 0;
            b_data <= 0;
            oHS    <= 0;
            oVS    <= 0;
            oBLANK_n <= 0;
        end else begin

            oHS      <= cHS;
            oVS      <= cVS;
            oBLANK_n <= cBLANK_n;

            if (!cBLANK_n) begin
                r_data <= 0;
                g_data <= 0;
                b_data <= 0;
            end else if (title_active && draw_title_pixel) begin
                // Cyan title
                r_data <= 0;
                g_data <= 255;
                b_data <= 255;
            end else if (in_ball) begin
                r_data <= 255;
                g_data <= 0;
                b_data <= 0;
            end else if (in_paddle_left || in_paddle_right) begin
                r_data <= 0;
                g_data <= 255;
                b_data <= 0;
            end else if (draw_score_pixel) begin
                r_data <= 255;
                g_data <= 255;
                b_data <= 255;
            end else begin
                r_data <= 0;
                g_data <= 0;
                b_data <= 0;
            end
        end
    end

endmodule
