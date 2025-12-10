module vga_controller(iRST_n, iVGA_CLK, oBLANK_n, oHS, oVS, b_data, g_data, r_data, 
                      w_in, s_in, o_in, l_in);

input iRST_n, iVGA_CLK;
input w_in, s_in, o_in, l_in; 

output reg oBLANK_n, oHS, oVS;
output reg [7:0] b_data, g_data, r_data;
                      
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire VGA_CLK_n, cBLANK_n, cHS, cVS, rst;
wire [7:0] index;
wire [23:0] bgr_data_raw;

assign rst = ~iRST_n;

video_sync_generator LTM_ins (.vga_clk(iVGA_CLK), .reset(rst), .blank_n(cBLANK_n), .HS(cHS), .VS(cVS));

// ——————————————————————————————————————————————————
// 1. COORDINATE TRACKING
// ——————————————————————————————————————————————————
reg [9:0] x_pos, y_pos;

always@(posedge iVGA_CLK, negedge iRST_n) begin
  if (!iRST_n) begin
     ADDR <= 19'd0; x_pos <= 0; y_pos <= 0;
  end
  else if (cHS==0 && cVS==0) begin
     ADDR <= 19'd0; x_pos <= 0; y_pos <= 0;
  end
  else if (cBLANK_n==1) begin
     ADDR <= ADDR + 1;
     if (x_pos < 639) x_pos <= x_pos + 1;
     else begin x_pos <= 0; y_pos <= y_pos + 1; end
  end
end

// ——————————————————————————————————————————————————
// 2. GAME LOGIC
// ——————————————————————————————————————————————————
reg [9:0] paddle_l_y, paddle_r_y;
reg [9:0] ball_x, ball_y;
reg ball_dir_x, ball_dir_y;
reg last_vs;
reg game_over; 

// SCORE REGISTERS
reg [3:0] score_l; 
reg [3:0] score_r; 

parameter BALL_SIZE = 10;
parameter PADDLE_H = 40;
parameter BALL_SPEED = 3; 
parameter PADDLE_SPEED = 4;

initial begin
    paddle_l_y = 200; paddle_r_y = 200;
    ball_x = 320; ball_y = 240;
    ball_dir_x = 1; ball_dir_y = 1;
    score_l = 0; score_r = 0;
    game_over = 0;
end

always @(posedge iVGA_CLK) begin
    // Hardware Reset (Button 0)
    if (!iRST_n) begin
        score_l <= 0; score_r <= 0;
        ball_x <= 320; ball_y <= 240;
        paddle_l_y <= 200; paddle_r_y <= 200;
        game_over <= 0;
    end
    else begin
        last_vs <= cVS;
        
        if (cVS && !last_vs) begin 
            if (game_over) begin
                // Game is frozen, waiting for Reset button
            end
            // Check Win Condition (5 Points)
            else if (score_l >= 5 || score_r >= 5) begin
                game_over <= 1; 
            end
            else begin
                // ——— PHYSICS LOOP ———
                if (w_in && paddle_l_y > 10)  paddle_l_y <= paddle_l_y - PADDLE_SPEED;
                if (s_in && paddle_l_y < 430) paddle_l_y <= paddle_l_y + PADDLE_SPEED;
                if (o_in && paddle_r_y > 10)  paddle_r_y <= paddle_r_y - PADDLE_SPEED;
                if (l_in && paddle_r_y < 430) paddle_r_y <= paddle_r_y + PADDLE_SPEED;

                if (ball_dir_x == 1) ball_x <= ball_x + BALL_SPEED;
                else                 ball_x <= ball_x - BALL_SPEED;
                if (ball_dir_y == 1) ball_y <= ball_y + BALL_SPEED;
                else                 ball_y <= ball_y - BALL_SPEED;

                // Wall Collisions
                if (ball_y <= 5 || ball_y > 1000) ball_dir_y <= 1; 
                else if (ball_y >= 475) ball_dir_y <= 0; 

                // Paddle Collisions
                if (ball_x <= 30 && ball_x >= 20) begin
                    if (ball_y + BALL_SIZE >= paddle_l_y && ball_y <= paddle_l_y + PADDLE_H)
                        ball_dir_x <= 1;
                end
                if (ball_x + BALL_SIZE >= 610 && ball_x <= 620) begin
                    if (ball_y + BALL_SIZE >= paddle_r_y && ball_y <= paddle_r_y + PADDLE_H)
                        ball_dir_x <= 0;
                end

                // Scoring
                if (ball_x > 700) begin
                    score_r <= score_r + 1; 
                    ball_x <= 320; ball_y <= 240; ball_dir_x <= 1; 
                end
                else if (ball_x >= 640) begin
                    score_l <= score_l + 1; 
                    ball_x <= 320; ball_y <= 240; ball_dir_x <= 0;
                end
            end
        end
    end
end

// ——————————————————————————————————————————————————
// 3. TEXT & SCORE RENDERERS
// ——————————————————————————————————————————————————
function [6:0] get_segments;
    input [3:0] num;
    begin
        case(num)
            4'd0: get_segments = 7'b1111110; 
            4'd1: get_segments = 7'b0110000; 
            4'd2: get_segments = 7'b1101101; 
            4'd3: get_segments = 7'b1111001; 
            4'd4: get_segments = 7'b0110011; 
            4'd5: get_segments = 7'b1011011; 
            4'd6: get_segments = 7'b1011111; 
            4'd7: get_segments = 7'b1110000; 
            4'd8: get_segments = 7'b1111111; 
            4'd9: get_segments = 7'b1111011; 
            default: get_segments = 7'b0000000;
        endcase
    end
endfunction

wire [6:0] seg_l = get_segments(score_l);
wire [6:0] seg_r = get_segments(score_r);

function is_pixel_on;
    input [9:0] px, py, bx, by;
    input [6:0] seg;
    reg a,b,c,d,e,f,g;
    begin
        a = seg[6]; b = seg[5]; c = seg[4]; d = seg[3]; e = seg[2]; f = seg[1]; g = seg[0];
        is_pixel_on = 0;
        if (a && px>=bx && px<=bx+20 && py>=by && py<=by+2) is_pixel_on=1;
        if (b && px>=bx+18 && px<=bx+20 && py>=by && py<=by+20) is_pixel_on=1;
        if (c && px>=bx+18 && px<=bx+20 && py>=by+20 && py<=by+40) is_pixel_on=1;
        if (d && px>=bx && px<=bx+20 && py>=by+38 && py<=by+40) is_pixel_on=1;
        if (e && px>=bx && px<=bx+2 && py>=by+20 && py<=by+40) is_pixel_on=1;
        if (f && px>=bx && px<=bx+2 && py>=by && py<=by+20) is_pixel_on=1;
        if (g && px>=bx && px<=bx+20 && py>=by+19 && py<=by+21) is_pixel_on=1;
    end
endfunction

// ———— NEW: GAME OVER TEXT BITMAP ————
// Defines the pixels for "GAME OVER"
function is_text_pixel;
    input [9:0] px, py;
    reg [2:0] letter_x, letter_y; // 0-4
    reg [9:0] start_x, start_y;
    reg [9:0] rel_x, rel_y;
    reg pixel_active;
    begin
        is_text_pixel = 0;
        start_x = 220; // Center-ish X
        start_y = 200; // Center-ish Y
        pixel_active = 0;

        // Check if inside the text box area (approx 200x50)
        // Scale = 4 (Each "pixel" in the letter is 4x4 real pixels)
        // Spacing = 30 (20 for letter + 10 space)
        if (py >= start_y && py < start_y + 20) begin
             rel_y = (py - start_y) / 4;
             
             // G (Offset 0)
             if (px >= start_x && px < start_x + 20) begin
                 rel_x = (px - start_x) / 4;
                 // G Bitmap: 01110, 10000, 10111, 10001, 01110
                 case(rel_y)
                    0: if(rel_x>0 && rel_x<4) pixel_active=1;
                    1: if(rel_x==0) pixel_active=1;
                    2: if(rel_x==0 || rel_x>1) pixel_active=1;
                    3: if(rel_x==0 || rel_x==4) pixel_active=1;
                    4: if(rel_x>0 && rel_x<4) pixel_active=1;
                 endcase
             end
             // A (Offset 30)
             else if (px >= start_x+30 && px < start_x + 50) begin
                 rel_x = (px - (start_x+30)) / 4;
                 // A Bitmap
                 case(rel_y)
                    0: if(rel_x>0 && rel_x<4) pixel_active=1;
                    1: if(rel_x==0 || rel_x==4) pixel_active=1;
                    2: pixel_active=1; // Middle bar
                    3: if(rel_x==0 || rel_x==4) pixel_active=1;
                    4: if(rel_x==0 || rel_x==4) pixel_active=1;
                 endcase
             end
             // M (Offset 60)
             else if (px >= start_x+60 && px < start_x + 80) begin
                 rel_x = (px - (start_x+60)) / 4;
                 // M Bitmap
                 case(rel_y)
                    0: if(rel_x==0 || rel_x==4) pixel_active=1;
                    1: if(rel_x==0 || rel_x==1 || rel_x==3 || rel_x==4) pixel_active=1;
                    2: if(rel_x==0 || rel_x==2 || rel_x==4) pixel_active=1;
                    3: if(rel_x==0 || rel_x==4) pixel_active=1;
                    4: if(rel_x==0 || rel_x==4) pixel_active=1;
                 endcase
             end
             // E (Offset 90)
             else if (px >= start_x+90 && px < start_x + 110) begin
                 rel_x = (px - (start_x+90)) / 4;
                 // E Bitmap
                 case(rel_y)
                    0: pixel_active=1;
                    1: if(rel_x==0) pixel_active=1;
                    2: if(rel_x<4) pixel_active=1;
                    3: if(rel_x==0) pixel_active=1;
                    4: pixel_active=1;
                 endcase
             end
             
             // "OVER" on the next line or same line? Let's do same line for simplicity
             // O (Offset 140)
             else if (px >= start_x+140 && px < start_x + 160) begin
                 rel_x = (px - (start_x+140)) / 4;
                 // O Bitmap
                 case(rel_y)
                    0: if(rel_x>0 && rel_x<4) pixel_active=1;
                    1: if(rel_x==0 || rel_x==4) pixel_active=1;
                    2: if(rel_x==0 || rel_x==4) pixel_active=1;
                    3: if(rel_x==0 || rel_x==4) pixel_active=1;
                    4: if(rel_x>0 && rel_x<4) pixel_active=1;
                 endcase
             end
             // V (Offset 170)
             else if (px >= start_x+170 && px < start_x + 190) begin
                 rel_x = (px - (start_x+170)) / 4;
                 // V Bitmap
                 case(rel_y)
                    0: if(rel_x==0 || rel_x==4) pixel_active=1;
                    1: if(rel_x==0 || rel_x==4) pixel_active=1;
                    2: if(rel_x==0 || rel_x==4) pixel_active=1;
                    3: if(rel_x==1 || rel_x==3) pixel_active=1;
                    4: if(rel_x==2) pixel_active=1;
                 endcase
             end
             // E (Offset 200)
             else if (px >= start_x+200 && px < start_x + 220) begin
                 rel_x = (px - (start_x+200)) / 4;
                 case(rel_y)
                    0: pixel_active=1;
                    1: if(rel_x==0) pixel_active=1;
                    2: if(rel_x<4) pixel_active=1;
                    3: if(rel_x==0) pixel_active=1;
                    4: pixel_active=1;
                 endcase
             end
             // R (Offset 230)
             else if (px >= start_x+230 && px < start_x + 250) begin
                 rel_x = (px - (start_x+230)) / 4;
                 case(rel_y)
                    0: if(rel_x<4) pixel_active=1;
                    1: if(rel_x==0 || rel_x==4) pixel_active=1;
                    2: if(rel_x<4) pixel_active=1;
                    3: if(rel_x==0 || rel_x==3) pixel_active=1;
                    4: if(rel_x==0 || rel_x==4) pixel_active=1;
                 endcase
             end
        end
        is_text_pixel = pixel_active;
    end
endfunction


// ——————————————————————————————————————————————————
// 4. DRAWING PIPELINE
// ——————————————————————————————————————————————————
assign VGA_CLK_n = ~iVGA_CLK;
img_data img_data_inst (.address(ADDR), .clock(VGA_CLK_n), .q(index));
img_index img_index_inst (.address(index), .clock(iVGA_CLK), .q(bgr_data_raw));

always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

wire in_left_paddle  = (x_pos >= 20 && x_pos < 30) && (y_pos >= paddle_l_y && y_pos < paddle_l_y + PADDLE_H);
wire in_right_paddle = (x_pos >= 610 && x_pos < 620) && (y_pos >= paddle_r_y && y_pos < paddle_r_y + PADDLE_H);
wire in_ball         = (x_pos >= ball_x && x_pos < ball_x + BALL_SIZE) && (y_pos >= ball_y && y_pos < ball_y + BALL_SIZE);

wire score_pixel = is_pixel_on(x_pos, y_pos, 280, 50, seg_l) || 
                   is_pixel_on(x_pos, y_pos, 340, 50, seg_r);
                   
wire text_pixel  = is_text_pixel(x_pos, y_pos);

always@(negedge iVGA_CLK) begin
  oHS<=cHS; oVS<=cVS; oBLANK_n<=cBLANK_n;
  
  if (in_ball) begin
      r_data <= 8'hFF; g_data <= 8'h00; b_data <= 8'h00; // Red Ball
  end
  else if (in_left_paddle || in_right_paddle) begin
      r_data <= 8'h00; g_data <= 8'hFF; b_data <= 8'h00; // Green Paddles
  end 
  else if (score_pixel) begin
      r_data <= 8'hFF; g_data <= 8'hFF; b_data <= 8'hFF; // White Score
  end
  // ———— NEW: GAME OVER DISPLAY ————
  else if (game_over && text_pixel) begin
      r_data <= 8'hFF; g_data <= 8'h00; b_data <= 8'h00; // RED TEXT
  end
  else begin
      if (game_over) begin
          // Dim background if game is over
          b_data <= {1'b0, bgr_data[23:17]}; 
          g_data <= {1'b0, bgr_data[15:9]}; 
          r_data <= {1'b0, bgr_data[7:1]}; 
      end else begin
          b_data <= bgr_data[23:16]; g_data <= bgr_data[15:8]; r_data <= bgr_data[7:0];
      end
  end
end

endmodule