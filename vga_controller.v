module vga_controller(iRST_n,
                      iVGA_CLK,
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,
							 UP,
							 DOWN,
							 LEFT,
							 RIGHT);

	
input iRST_n;
input iVGA_CLK;
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output [7:0] b_data;
output [7:0] g_data;  
output [7:0] r_data;                        
///////// ////                     
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire VGA_CLK_n;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;

input UP;
input DOWN;
input LEFT;
input RIGHT;

reg [7:0] b_data;
reg [7:0] g_data;
reg [7:0] r_data;


wire [9:0] pixel_x;
wire [8:0] pixel_y;

assign pixel_x = ADDR % 640;
assign pixel_y = ADDR / 640;

////
assign rst = ~iRST_n;
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS));
////
////Addresss generator
always@(posedge iVGA_CLK,negedge iRST_n)
begin
  if (!iRST_n)
     ADDR<=19'd0;
  else if (cHS==1'b0 && cVS==1'b0)
     ADDR<=19'd0;
  else if (cBLANK_n==1'b1)
     ADDR<=ADDR+1;
end
//////////////////////////
//////INDEX addr.
assign VGA_CLK_n = ~iVGA_CLK;
img_data	img_data_inst (
	.address ( ADDR ),
	.clock ( VGA_CLK_n ),
	.q ( index )
	);
	
/////////////////////////
//////Add switch-input logic here
	
//////Color table output
img_index	img_index_inst (
	.address ( index ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);	
//////
//////latch valid data at falling edge;
always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;



//assign b_data = bgr_data[23:16];
//assign g_data = bgr_data[15:8];
//assign r_data = bgr_data[7:0]; 
///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
//always@(negedge iVGA_CLK)
//begin
//  oHS<=cHS;
//  oVS<=cVS;
//  oBLANK_n<=cBLANK_n;
//end

//// Moving square logic
parameter SQUARE_SIZE = 32;
reg [9:0] square_x;
reg [8:0] square_y;
reg [15:0] move_counter;
parameter MOVE_SPEED = 16'd5000000; // adjust for speed

wire UP_pressed    = ~UP;
wire DOWN_pressed  = ~DOWN;
wire LEFT_pressed  = ~LEFT;
wire RIGHT_pressed = ~RIGHT;

//always @(posedge iVGA_CLK or negedge iRST_n) begin
//    if (!iRST_n) begin
//        square_x <= 10'd100;
//        square_y <= 9'd100;
//        move_counter <= 16'd0;
//    end else begin
//        move_counter <= move_counter + 1;
//        if (move_counter >= MOVE_SPEED) begin
//            move_counter <= 0;
//            // Move square
//            if (UP    && square_y > 0) square_y <= square_y - 1;
//            if (DOWN  && square_y < 480 - SQUARE_SIZE) square_y <= square_y + 1;
//            if (LEFT  && square_x > 0) square_x <= square_x - 1;
//            if (RIGHT && square_x < 640 - SQUARE_SIZE) square_x <= square_x + 1;
//        end
//    end
//end
always @(posedge iVGA_CLK or negedge iRST_n) begin
    if (!iRST_n) begin
        square_x <= 10'd100;
        square_y <= 9'd100;
        move_counter <= 0;
    end else begin
        move_counter <= move_counter + 1;

        if (move_counter >= MOVE_SPEED) begin
            move_counter <= 0;
            // Only move if a button is pressed
            if (UP_pressed    && square_y > 0)               square_y <= square_y - 1;
            if (DOWN_pressed  && square_y < 480 - SQUARE_SIZE) square_y <= square_y + 1;
            if (LEFT_pressed  && square_x > 0)               square_x <= square_x - 1;
            if (RIGHT_pressed && square_x < 640 - SQUARE_SIZE) square_x <= square_x + 1;
        end
    end
end

//// Determine if pixel is inside square
wire in_square;
assign in_square = (pixel_x >= square_x) && (pixel_x < square_x + SQUARE_SIZE) &&
                   (pixel_y >= square_y) && (pixel_y < square_y + SQUARE_SIZE);

//// RGB output: square overrides background
//assign b_data = in_square ? 8'd0   : bgr_data[23:16];
//assign g_data = in_square ? 8'd0   : bgr_data[15:8];
//assign r_data = in_square ? 8'd255 : bgr_data[7:0];
always @(posedge iVGA_CLK or negedge iRST_n) begin
    if (!iRST_n) begin
        b_data <= 8'd0;
        g_data <= 8'd0;
        r_data <= 8'd0;
    end else begin
        if (in_square) begin
            b_data <= 8'd0;
            g_data <= 8'd0;
            r_data <= 8'd255; // red square
        end else begin
            b_data <= bgr_data[23:16];
            g_data <= bgr_data[15:8];
            r_data <= bgr_data[7:0];
        end
    end
end


//// Delay sync signals for one clock
always @(negedge iVGA_CLK) begin
    oHS <= cHS;
    oVS <= cVS;
    oBLANK_n <= cBLANK_n;
end


endmodule
 	















