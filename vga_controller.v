module vga_controller(iRST_n,
                      iVGA_CLK,
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,
                      up,
                      down,
                      left,
                      right);

	
input iRST_n;
input iVGA_CLK;

// Controller
input up;
input down;
input left;
input right;

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

reg [2:0]  counter;   // needs to count at least up to 5

always @(posedge iVGA_CLK or negedge iRST_n) begin
  if (!iRST_n) begin
    // asynchronous reset (active low)
    ADDR    <= 19'd0;
    counter <= 3'd0;
  end 
  else begin
    if (counter == 3'd5) begin
      // perform address update when counter reaches 5
      if (!up)
        ADDR <= ADDR + 19'd300;
      else if (!down)
        ADDR <= ADDR - 19'd300;
      else if (!right)
        ADDR <= ADDR + 19'd3;
      else if (!left)
        ADDR <= ADDR - 19'd3;

      counter <= 3'd0;
    end
    else if (cBLANK_n == 1'b1) begin
      // increment counter only when cBLANK_n asserted (== 1)
      counter <= counter + 3'd1;
    end
    // else: hold counter and ADDR
  end
end


//////Color table output
img_index	img_index_inst (
	.address ( index ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);	
//////
//////latch valid data at falling edge;
always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;
assign b_data = bgr_data[23:16];
assign g_data = bgr_data[15:8];
assign r_data = bgr_data[7:0]; 
///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
always@(negedge iVGA_CLK)
begin
  oHS<=cHS;
  oVS<=cVS;
  oBLANK_n<=cBLANK_n;
end

endmodule
 	

