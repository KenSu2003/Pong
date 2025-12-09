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
// 2. GAME LOGIC (Scores & Win Condition)
// ——————————————————————————————————————————————————
reg [9:0] paddle_l_y, paddle_r_y;
reg [9:0] ball_x, ball_y;
reg ball_dir_x, ball_dir_y;
reg last_vs;

// SCORE REGISTERS
reg [3:0] score_l; // 0-9
reg [3:0] score_r; // 0-9

parameter BALL_SIZE = 10;
parameter PADDLE_H = 40;
parameter BALL_SPEED = 3; 
parameter PADDLE_SPEED = 4;

initial begin
    paddle_l_y = 200; paddle_r_y = 200;
    ball_x = 320; ball_y = 240;
    ball_dir_x = 1; ball_dir_y = 1;
    score_l = 0; score_r = 0;
end

always @(posedge iVGA_CLK) begin
    last_vs <= cVS;
    
    // Update Game State once per frame
    if (cVS && !last_vs) begin 
        
        // Check "First to 9" Win Condition
        if (score_l >= 9 || score_r >= 9) begin
            // Reset Game
            score_l <= 0;
            score_r <= 0;
            ball_x <= 320;
            ball_y <= 240;
            paddle_l_y <= 200;
            paddle_r_y <= 200;
        end
        else begin
            // Normal Gameplay
            
            // PADDLES
            if (w_in && paddle_l_y > 10)  paddle_l_y <= paddle_l_y - PADDLE_SPEED;
            if (s_in && paddle_l_y < 430) paddle_l_y <= paddle_l_y + PADDLE_SPEED;
            if (o_in && paddle_r_y > 10)  paddle_r_y <= paddle_r_y - PADDLE_SPEED;
            if (l_in && paddle_r_y < 430) paddle_r_y <= paddle_r_y + PADDLE_SPEED;

            // BALL MOVEMENT
            if (ball_dir_x == 1) ball_x <= ball_x + BALL_SPEED;
            else                 ball_x <= ball_x - BALL_SPEED;
            if (ball_dir_y == 1) ball_y <= ball_y + BALL_SPEED;
            else                 ball_y <= ball_y - BALL_SPEED;

            // COLLISIONS
            if (ball_y <= 5) ball_dir_y <= 1; 
            if (ball_y >= 475) ball_dir_y <= 0; 

            // Left Paddle Hit
            if (ball_x <= 30 && ball_x >= 20) begin
                if (ball_y + BALL_SIZE >= paddle_l_y && ball_y <= paddle_l_y + PADDLE_H)
                    ball_dir_x <= 1;
            end
            // Right Paddle Hit
            if (ball_x + BALL_SIZE >= 610 && ball_x <= 620) begin
                if (ball_y + BALL_SIZE >= paddle_r_y && ball_y <= paddle_r_y + PADDLE_H)
                    ball_dir_x <= 0;
            end

            // SCORING (Passes Edge)
            if (ball_x <= 0) begin
                score_r <= score_r + 1; // Right scores
                ball_x <= 320; ball_y <= 240; // Reset Ball
                ball_dir_x <= 1; // Serve to winner
            end
            else if (ball_x >= 640) begin
                score_l <= score_l + 1; // Left scores
                ball_x <= 320; ball_y <= 240;
                ball_dir_x <= 0;
            end
        end
    end
end

// ——————————————————————————————————————————————————
// 3. SEVEN-SEGMENT SCORE RENDERER
// ——————————————————————————————————————————————————
// We map digits 0-9 to segments A,B,C,D,E,F,G (Standard 7-Seg)
//   A
// F   B
//   G
// E   C
//   D

// Helper Function: Decode Number to Segments
function [6:0] get_segments;
    input [3:0] num;
    begin
        case(num)
            4'd0: get_segments = 7'b1111110; // ABCDEF
            4'd1: get_segments = 7'b0110000; // BC
            4'd2: get_segments = 7'b1101101; // ABDEG
            4'd3: get_segments = 7'b1111001; // ABCDG
            4'd4: get_segments = 7'b0110011; // BCFG
            4'd5: get_segments = 7'b1011011; // ACDFG
            4'd6: get_segments = 7'b1011111; // ACDEFG
            4'd7: get_segments = 7'b1110000; // ABC
            4'd8: get_segments = 7'b1111111; // ABCDEFG
            4'd9: get_segments = 7'b1111011; // ABCDFG
            default: get_segments = 7'b0000000;
        endcase
    end
endfunction

wire [6:0] seg_l = get_segments(score_l);
wire [6:0] seg_r = get_segments(score_r);

// Function to check if current pixel (px, py) is in an active segment
// Base Position (bx, by), Scale (s)
function is_pixel_on;
    input [9:0] px, py, bx, by;
    input [6:0] seg;
    reg a,b,c,d,e,f,g;
    begin
        a = seg[6]; b = seg[5]; c = seg[4]; d = seg[3]; e = seg[2]; f = seg[1]; g = seg[0];
        is_pixel_on = 0;
        
        // Seg A (Top)
        if (a && px>=bx && px<=bx+20 && py>=by && py<=by+2) is_pixel_on=1;
        // Seg B (Top Right)
        if (b && px>=bx+18 && px<=bx+20 && py>=by && py<=by+20) is_pixel_on=1;
        // Seg C (Bot Right)
        if (c && px>=bx+18 && px<=bx+20 && py>=by+20 && py<=by+40) is_pixel_on=1;
        // Seg D (Bot)
        if (d && px>=bx && px<=bx+20 && py>=by+38 && py<=by+40) is_pixel_on=1;
        // Seg E (Bot Left)
        if (e && px>=bx && px<=bx+2 && py>=by+20 && py<=by+40) is_pixel_on=1;
        // Seg F (Top Left)
        if (f && px>=bx && px<=bx+2 && py>=by && py<=by+20) is_pixel_on=1;
        // Seg G (Mid)
        if (g && px>=bx && px<=bx+20 && py>=by+19 && py<=by+21) is_pixel_on=1;
    end
endfunction

// ——————————————————————————————————————————————————
// 4. DRAWING PIPELINE
// ——————————————————————————————————————————————————
assign VGA_CLK_n = ~iVGA_CLK;
img_data img_data_inst (.address(ADDR), .clock(VGA_CLK_n), .q(index));
img_index img_index_inst (.address(index), .clock(iVGA_CLK), .q(bgr_data_raw));

always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

// Hitbox Checkers
wire in_left_paddle  = (x_pos >= 20 && x_pos < 30) && (y_pos >= paddle_l_y && y_pos < paddle_l_y + PADDLE_H);
wire in_right_paddle = (x_pos >= 610 && x_pos < 620) && (y_pos >= paddle_r_y && y_pos < paddle_r_y + PADDLE_H);
wire in_ball         = (x_pos >= ball_x && x_pos < ball_x + BALL_SIZE) && (y_pos >= ball_y && y_pos < ball_y + BALL_SIZE);

// Score Pixels
// Left Score Pos: (280, 50), Right Score Pos: (340, 50)
wire score_pixel = is_pixel_on(x_pos, y_pos, 280, 50, seg_l) || 
                   is_pixel_on(x_pos, y_pos, 340, 50, seg_r);

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
  else begin
      b_data <= bgr_data[23:16]; g_data <= bgr_data[15:8]; r_data <= bgr_data[7:0];
  end
end

endmodule