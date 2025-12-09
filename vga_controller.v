module vga_controller(iRST_n, iVGA_CLK, oBLANK_n, oHS, oVS, b_data, g_data, r_data, 
                      w_in, s_in, o_in, l_in);

input iRST_n, iVGA_CLK;
input w_in, s_in, o_in, l_in; // Control Inputs

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
// 2. GAME LOGIC (Paddles & Ball)
// ——————————————————————————————————————————————————
reg [9:0] paddle_l_y;
reg [9:0] paddle_r_y;
reg [9:0] ball_x;
reg [9:0] ball_y;
reg ball_dir_x; // 0 = Left, 1 = Right
reg ball_dir_y; // 0 = Up, 1 = Down

reg last_vs;

// Constants
parameter BALL_SIZE = 10;
parameter PADDLE_H = 40;
parameter PADDLE_W = 10;
parameter BALL_SPEED = 2; // Pixels per frame
parameter PADDLE_SPEED = 4;

initial begin
    paddle_l_y = 200;
    paddle_r_y = 200;
    ball_x = 320;
    ball_y = 240;
    ball_dir_x = 1; // Start moving Right
    ball_dir_y = 1; // Start moving Down
end

always @(posedge iVGA_CLK) begin
    last_vs <= cVS;
    
    // Update Game State once per frame (Rising edge of V-Sync)
    if (cVS && !last_vs) begin 
        
        // ——— PADDLE MOVEMENT ———
        // Left Paddle (W/S)
        if (w_in && paddle_l_y > 10)  paddle_l_y <= paddle_l_y - PADDLE_SPEED;
        if (s_in && paddle_l_y < 430) paddle_l_y <= paddle_l_y + PADDLE_SPEED;
        
        // Right Paddle (O/L)
        if (o_in && paddle_r_y > 10)  paddle_r_y <= paddle_r_y - PADDLE_SPEED;
        if (l_in && paddle_r_y < 430) paddle_r_y <= paddle_r_y + PADDLE_SPEED;

        // ——— BALL MOVEMENT ———
        if (ball_dir_x == 1) ball_x <= ball_x + BALL_SPEED;
        else                 ball_x <= ball_x - BALL_SPEED;

        if (ball_dir_y == 1) ball_y <= ball_y + BALL_SPEED;
        else                 ball_y <= ball_y - BALL_SPEED;

        // ——— BALL COLLISIONS ———
        
        // 1. Wall Collision (Top/Bottom)
        if (ball_y <= 5) ball_dir_y <= 1; // Hit Top, go Down
        if (ball_y >= 475) ball_dir_y <= 0; // Hit Bottom, go Up

        // 2. Paddle Collision (Left)
        // Check X range (20-30) AND Y overlap
        if (ball_x <= 30 && ball_x >= 20) begin
            if (ball_y + BALL_SIZE >= paddle_l_y && ball_y <= paddle_l_y + PADDLE_H) begin
                ball_dir_x <= 1; // Bounce Right
            end
        end

        // 3. Paddle Collision (Right)
        // Check X range (610-620) AND Y overlap
        if (ball_x + BALL_SIZE >= 610 && ball_x <= 620) begin
            if (ball_y + BALL_SIZE >= paddle_r_y && ball_y <= paddle_r_y + PADDLE_H) begin
                ball_dir_x <= 0; // Bounce Left
            end
        end

        // 4. Scoring (Reset)
        // If ball goes off left or right edge
        if (ball_x <= 0 || ball_x >= 640) begin
            ball_x <= 320;
            ball_y <= 240;
            // Toggle direction on reset?
            // ball_dir_x <= ~ball_dir_x; 
        end
    end
end

// ——————————————————————————————————————————————————
// 3. DRAWING LOGIC
// ——————————————————————————————————————————————————
assign VGA_CLK_n = ~iVGA_CLK;
img_data img_data_inst (.address(ADDR), .clock(VGA_CLK_n), .q(index));
img_index img_index_inst (.address(index), .clock(iVGA_CLK), .q(bgr_data_raw));

always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

// Hitbox Checkers
wire in_left_paddle  = (x_pos >= 20 && x_pos < 30) && (y_pos >= paddle_l_y && y_pos < paddle_l_y + PADDLE_H);
wire in_right_paddle = (x_pos >= 610 && x_pos < 620) && (y_pos >= paddle_r_y && y_pos < paddle_r_y + PADDLE_H);
wire in_ball         = (x_pos >= ball_x && x_pos < ball_x + BALL_SIZE) && (y_pos >= ball_y && y_pos < ball_y + BALL_SIZE);

always@(negedge iVGA_CLK) begin
  oHS<=cHS; oVS<=cVS; oBLANK_n<=cBLANK_n;
  
  // LAYER 1: BALL (Red)
  if (in_ball) begin
      r_data <= 8'hFF; g_data <= 8'h00; b_data <= 8'h00;
  end
  // LAYER 2: PADDLES (Green)
  else if (in_left_paddle || in_right_paddle) begin
      r_data <= 8'h00; g_data <= 8'hFF; b_data <= 8'h00; 
  end 
  // LAYER 3: BACKGROUND IMAGE
  else begin
      b_data <= bgr_data[23:16]; g_data <= bgr_data[15:8]; r_data <= bgr_data[7:0];
  end
end

endmodule