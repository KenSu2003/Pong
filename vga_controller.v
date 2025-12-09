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
// 2. MOVEMENT LOGIC
// ——————————————————————————————————————————————————
reg [9:0] paddle_l_y;
reg [9:0] paddle_r_y;
reg last_vs;

initial begin
    paddle_l_y = 200;
    paddle_r_y = 200;
end

always @(posedge iVGA_CLK) begin
    last_vs <= cVS;
    // Update positions once per frame (Rising edge of V-Sync)
    if (cVS && !last_vs) begin 
        // Left Paddle (W/S)
        if (w_in && paddle_l_y > 10)  paddle_l_y <= paddle_l_y - 4;
        if (s_in && paddle_l_y < 430) paddle_l_y <= paddle_l_y + 4;
        
        // Right Paddle (O/L)
        if (o_in && paddle_r_y > 10)  paddle_r_y <= paddle_r_y - 4;
        if (l_in && paddle_r_y < 430) paddle_r_y <= paddle_r_y + 4;
    end
end

// ——————————————————————————————————————————————————
// 3. DRAWING LOGIC
// ——————————————————————————————————————————————————
assign VGA_CLK_n = ~iVGA_CLK;
img_data img_data_inst (.address(ADDR), .clock(VGA_CLK_n), .q(index));
img_index img_index_inst (.address(index), .clock(iVGA_CLK), .q(bgr_data_raw));

always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

// Check if pixel is inside paddles
wire in_left_paddle  = (x_pos >= 20 && x_pos <= 30) && (y_pos >= paddle_l_y && y_pos <= paddle_l_y + 40);
wire in_right_paddle = (x_pos >= 610 && x_pos <= 620) && (y_pos >= paddle_r_y && y_pos <= paddle_r_y + 40);

always@(negedge iVGA_CLK) begin
  oHS<=cHS; oVS<=cVS; oBLANK_n<=cBLANK_n;
  
  if (in_left_paddle || in_right_paddle) begin
      r_data <= 8'h00; g_data <= 8'hFF; b_data <= 8'h00; // Green Paddles
  end else begin
      b_data <= bgr_data[23:16]; g_data <= bgr_data[15:8]; r_data <= bgr_data[7:0]; // Background
  end
end

endmodule