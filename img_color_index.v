module img_color_index(
    input  [7:0] address,
    input         clock,
    output reg [23:0] q
);
    always @(posedge clock) begin
        q <= 24'h000000; // black
    end
endmodule
