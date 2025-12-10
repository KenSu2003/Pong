module vga_controller(
    iRST_n, iVGA_CLK, oBLANK_n, oHS, oVS, b_data, g_data, r_data, 
    // COORDINATES FROM PROCESSOR
    ball_x, ball_y, paddle_left_y, paddle_right_y
);

input iRST_n, iVGA_CLK;
// Inputs are now simple wires coming from Skeleton Registers
input [9:0] ball_x;
input [8:0] ball_y;
input [8:0] paddle_left_y;
input [8:0] paddle_right_y;

output reg oBLANK_n, oHS, oVS;
output reg [7:0] b_data, g_data, r_data;
                     
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire VGA_CLK_n, cBLANK_n, cHS, cVS, rst;
wire [7:0] index;
wire [23:0] bgr_data_raw;

assign rst = ~iRST_n;
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK), .reset(rst), .blank_n(cBLANK_n), .HS(cHS), .VS(cVS));

// ————— ADDRESS GEN —————
always@(posedge iVGA_CLK, negedge iRST_n) begin
  if (!iRST_n) ADDR <= 0;
  else if (cHS==0 && cVS==0) ADDR <= 0;
  else if (cBLANK_n==1) ADDR <= ADDR + 1;
end

// ————— DRAWING LOGIC —————
wire [9:0] pixel_x = ADDR % 640;
wire [8:0] pixel_y = ADDR / 640;

assign VGA_CLK_n = ~iVGA_CLK;
img_data img_data_inst (.address(ADDR), .clock(VGA_CLK_n), .q(index));
img_index img_index_inst (.address(index), .clock(iVGA_CLK), .q(bgr_data_raw));

always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

// Check Hitboxes based on INPUTS
wire in_ball = (pixel_x >= ball_x && pixel_x < ball_x + 10) && 
               (pixel_y >= ball_y && pixel_y < ball_y + 10);
wire in_pad_l = (pixel_x >= 20 && pixel_x < 30) && 
                (pixel_y >= paddle_left_y && pixel_y < paddle_left_y + 40);
wire in_pad_r = (pixel_x >= 610 && pixel_x < 620) && 
                (pixel_y >= paddle_right_y && pixel_y < paddle_right_y + 40);

always@(negedge iVGA_CLK) begin
  oHS<=cHS; oVS<=cVS; oBLANK_n<=cBLANK_n;
  
  if (in_ball) begin r_data<=255; g_data<=0; b_data<=0; end
  else if (in_pad_l || in_pad_r) begin r_data<=0; g_data<=255; b_data<=0; end
  else begin 
      b_data <= bgr_data[23:16]; 
      g_data <= bgr_data[15:8]; 
      r_data <= bgr_data[7:0]; 
  end
end
endmodule