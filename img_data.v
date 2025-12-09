module img_data(
    input  [18:0] address,
    input         clock,
    output reg [7:0] q
);
    always @(posedge clock) begin
        q <= 8'd0; // black background
    end
endmodule
