module vga_controller(iRST_n,
                      iVGA_CLK,
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,
                      // Control Inputs
                      w_in,
                      s_in,
                      o_in,
                      k_in);

input iRST_n;
input iVGA_CLK;
input w_in, s_in, o_in, k_in;

output reg oBLANK_n;
output reg oHS;
output reg oVS;
output reg [7:0] b_data;
output reg [7:0] g_data;  
output reg [7:0] r_data;
                     
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire VGA_CLK_n;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;

assign rst = ~iRST_n;

// Sync Generator
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS));

// ——————————————————————————————————————————————————
// 1. ADDRESS & COORDINATE GENERATOR
// ——————————————————————————————————————————————————
// We need X and Y coordinates to know where to draw the paddles.
reg [9:0] x_pos; // 0-639
reg [9:0] y_pos; // 0-479

always@(posedge iVGA_CLK, negedge iRST_n)
begin
  if (!iRST_n) begin
     ADDR  <= 19'd0;
     x_pos <= 10'd0;
     y_pos <= 10'd0;
  end
  else if (cHS==1'b0 && cVS==1'b0) begin
     ADDR  <= 19'd0;
     x_pos <= 10'd0;
     y_pos <= 10'd0;
  end
  else if (cBLANK_n==1'b1) begin
     ADDR <= ADDR + 1;
     
     // Update X and Y trackers
     if (x_pos < 639) begin
        x_pos <= x_pos + 1;
     end else begin
        x_pos <= 0;
        y_pos <= y_pos + 1;
     end
  end
end

// ——————————————————————————————————————————————————
// 2. IMAGE LOOKUP (Background)
// ——————————————————————————————————————————————————
assign VGA_CLK_n = ~iVGA_CLK;
img_data	img_data_inst (
	.address ( ADDR ),
	.clock ( VGA_CLK_n ),
	.q ( index )
	);

img_index	img_index_inst (
	.address ( index ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);

// ——————————————————————————————————————————————————
// 3. PADDLE MOVEMENT LOGIC
// ——————————————————————————————————————————————————
reg [9:0] paddle_l_y;
reg [9:0] paddle_r_y;
reg [19:0] move_counter; // Slow down movement

// Initialize positions
initial begin
    paddle_l_y = 200;
    paddle_r_y = 200;
end

// Update position only at the start of a frame (Vertical Sync)
// This makes it run at 60 FPS automatically.
reg last_vs;
always @(posedge iVGA_CLK) begin
    last_vs <= cVS;
    
    // Detect rising edge of VS (Start of new frame)
    if (cVS && !last_vs) begin 
        
        // LEFT PADDLE (W / S)
        if (w_in && paddle_l_y > 10) 
            paddle_l_y <= paddle_l_y - 3; // Move Up
            
        if (s_in && paddle_l_y < 430) 
            paddle_l_y <= paddle_l_y + 3; // Move Down
            
        // RIGHT PADDLE (O / K)
        if (o_in && paddle_r_y > 10) 
            paddle_r_y <= paddle_r_y - 3; // Move Up
            
        if (k_in && paddle_r_y < 430) 
            paddle_r_y <= paddle_r_y + 3; // Move Down
    end
end


// ——————————————————————————————————————————————————
// 4. DRAWING LAYERS
// ——————————————————————————————————————————————————
always@(posedge VGA_CLK_n) begin
    // Latch Background Data
    bgr_data <= bgr_data_raw; 
end

// Check if current pixel (x_pos, y_pos) is inside a paddle
wire in_left_paddle;
wire in_right_paddle;

assign in_left_paddle = (x_pos >= 20 && x_pos <= 30) && 
                        (y_pos >= paddle_l_y && y_pos <= paddle_l_y + 40);

assign in_right_paddle = (x_pos >= 610 && x_pos <= 620) && 
                         (y_pos >= paddle_r_y && y_pos <= paddle_r_y + 40);

always@(negedge iVGA_CLK)
begin
  oHS<=cHS;
  oVS<=cVS;
  oBLANK_n<=cBLANK_n;
  
  // LAYER 1: PADDLES (Green)
  if (in_left_paddle || in_right_paddle) begin
      r_data <= 8'h00;
      g_data <= 8'hFF; // Green
      b_data <= 8'h00;
  end
  // LAYER 2: BACKGROUND IMAGE
  else begin
      b_data <= bgr_data[23:16];
      g_data <= bgr_data[15:8];
      r_data <= bgr_data[7:0]; 
  end
end

endmodule