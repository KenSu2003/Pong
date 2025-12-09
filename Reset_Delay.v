module Reset_Delay(iCLK, oRESET);
    input  iCLK;
    output oRESET;

    reg [19:0] counter;
    assign oRESET = counter[19];

    always @(posedge iCLK) begin
        if (!oRESET)
            counter <= counter + 1'b1;
    end
endmodule
