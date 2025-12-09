// Simple PS/2 controller: only receives scan codes.
// No Altera University IP, no command sending.
module PS2_Controller(
    input        CLOCK_50,
    input        reset,
    inout        PS2_CLK,
    inout        PS2_DAT,
    output reg [7:0] received_data,
    output reg       received_data_en
);

    // Make PS2_CLK, PS2_DAT inputs (no driving)
    wire ps2_clk_in  = PS2_CLK;
    wire ps2_dat_in  = PS2_DAT;

    reg  [10:0] shift;
    reg  [3:0]  bit_count;
    reg        prev_clk;

    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            prev_clk         <= 1'b1;
            bit_count        <= 4'd0;
            received_data    <= 8'd0;
            received_data_en <= 1'b0;
        end
        else begin
            prev_clk         <= ps2_clk_in;
            received_data_en <= 1'b0;  // default: no new data

            // Detect falling edge of PS2 clock
            if (prev_clk == 1'b1 && ps2_clk_in == 1'b0) begin
                shift[bit_count] <= ps2_dat_in;
                bit_count        <= bit_count + 1'b1;

                // After 11 bits: start(0), 8 data bits, parity, stop(1)
                if (bit_count == 4'd10) begin
                    received_data    <= shift[8:1]; // data bits [8:1]
                    received_data_en <= 1'b1;
                    bit_count        <= 4'd0;
                end
            end
        end
    end

endmodule
