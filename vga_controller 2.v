module vga_controller(
    iRST_n,
    iVGA_CLK,
    oBLANK_n,
    oHS,
    oVS,
    b_data,
    g_data,
    r_data,
    // coordinates from processor
    ball_x,
    ball_y,
    paddle_left_y,
    paddle_right_y
);

// —————————————————————————————— 1. INPUTS & OUTPUTS ——————————————————————————————
input iRST_n;
input iVGA_CLK;
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output reg [7:0] b_data;
output reg [7:0] g_data;  
output reg [7:0] r_data;                        

// Object coordinates from the processor
input [9:0] ball_x;
input [8:0] ball_y;
input [8:0] paddle_left_y;
input [8:0] paddle_right_y;

// —————————————————————————————— 2. INTERNAL REGISTERS & WIRES ——————————————————————————————
reg [18:0] ADDR;
reg [23:0] bgr_data;        // Color data 
wire [23:0] bgr_data_raw;   // Raw Color data 
wire cBLANK_n, cHS, cVS, rst;

// ******** Sync Generation ********
assign rst = ~iRST_n;
video_sync_generator LTM_ins (
    .vga_clk(iVGA_CLK),
    .reset(rst),
    .blank_n(cBLANK_n),
    .HS(cHS),
    .VS(cVS)
);

// ******** Address Generator ********
always@(posedge iVGA_CLK, negedge iRST_n)
begin
  if (!iRST_n)
     ADDR <= 19'd0;
  else if (cHS==1'b0 && cVS==1'b0)
     ADDR <= 19'd0;
  else if (cBLANK_n==1'b1)
     ADDR <= ADDR+1;
end

// ******** Background Image Logic ********
wire [7:0] color_index;
wire VGA_CLK_n;
assign VGA_CLK_n = ~iVGA_CLK;

img_data img_data_inst (
    .address ( ADDR ),
    .clock ( VGA_CLK_n ),
    .q ( color_index )
);

img_color_index img_color_index_inst (
    .address ( color_index ),
    .clock ( iVGA_CLK ),
    .q ( bgr_data_raw)
);  

always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

// —————————————————————————————— 3. DRAWING LOGIC ——————————————————————————————

// ******** Define Pixel Coordinates ********
wire [9:0] pixel_x;
wire [8:0] pixel_y;
assign pixel_x = ADDR % 640;
assign pixel_y = ADDR / 640;

// ******** Define Object Sizes ********
parameter BALL_SIZE = 10;
parameter PADDLE_W  = 10;
parameter PADDLE_H  = 40;

// ******** CHECK BALL ********
wire in_ball; // Renamed to match usage below
assign in_ball = (pixel_x >= ball_x) && (pixel_x < ball_x + BALL_SIZE) &&
                 (pixel_y >= ball_y) && (pixel_y < ball_y + BALL_SIZE);

// ******** CHECK LEFT PADDLE (Fixed X at 20) ********
wire in_paddle_left;
assign in_paddle_left = (pixel_x >= 20) && (pixel_x < 20 + PADDLE_W) &&
                        (pixel_y >= paddle_left_y) && (pixel_y < paddle_left_y + PADDLE_H);

// ******** CHECK RIGHT PADDLE (Fixed X at 610) ********
wire in_paddle_right;
assign in_paddle_right = (pixel_x >= 610) && (pixel_x < 610 + PADDLE_W) &&
                         (pixel_y >= paddle_right_y) && (pixel_y < paddle_right_y + PADDLE_H);


// ******** COLOR DECISION BLOCK ******** 
always @(posedge iVGA_CLK or negedge iRST_n) begin
    if (!iRST_n) begin
        b_data <= 8'd0;
        g_data <= 8'd0;
        r_data <= 8'd0;
    end else begin
        if (in_ball) begin
            // Draw Ball (Red)
            r_data <= 8'd255;
            g_data <= 8'd0; 
            b_data <= 8'd0;
        end 
        else if (in_paddle_left || in_paddle_right) begin
            // Draw Paddles (Green)
            r_data <= 8'd0;
            g_data <= 8'd255; 
            b_data <= 8'd0;
        end 
        else begin
            // Draw Background Image
            b_data <= bgr_data[23:16];
            g_data <= bgr_data[15:8];
            r_data <= bgr_data[7:0];
        end
    end
end

// —————————————————————————————— 4. Output Latching ——————————————————————————————
always @(negedge iVGA_CLK) begin
    oHS <= cHS;
    oVS <= cVS;
    oBLANK_n <= cBLANK_n;
end

endmodule