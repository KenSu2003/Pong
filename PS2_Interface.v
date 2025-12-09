module PS2_Interface(
    input        inclock,
    input        resetn,
    inout        ps2_clock,
    inout        ps2_data,
    output reg   ps2_key_pressed,     // 1 for one cycle when a new key is latched
    output reg [7:0] ps2_key_data,    // decoded ASCII-like key
    output reg [7:0] last_data_received
);
    wire [7:0] scan_code;
    wire       scan_ready;

    reg break_seen;
    reg scan_ready_d;

    always @(posedge inclock or negedge resetn) begin
        if (!resetn) begin
            break_seen         <= 1'b0;
            ps2_key_pressed    <= 1'b0;
            ps2_key_data       <= 8'h00;
            last_data_received <= 8'h00;
            scan_ready_d       <= 1'b0;
        end
        else begin
            scan_ready_d    <= scan_ready;
            ps2_key_pressed <= 1'b0;   // default

            // Rising edge of scan_ready = new byte
            if (scan_ready & ~scan_ready_d) begin
                if (scan_code == 8'hF0) begin
                    // break code, ignore next byte
                    break_seen <= 1'b1;
                end
                else if (break_seen) begin
                    // this is key release, ignore
                    break_seen <= 1'b0;
                end
                else begin
                    // valid make code
                    case (scan_code)
                        8'h1D: ps2_key_data <= 8'h57; // 'W'
                        8'h1B: ps2_key_data <= 8'h53; // 'S'

                        8'h44: ps2_key_data <= 8'h4F; // 'O' fallback
                        8'h75: ps2_key_data <= 8'h4F; // Arrow Up → 'O'

                        8'h42: ps2_key_data <= 8'h4B; // 'K' fallback
                        8'h72: ps2_key_data <= 8'h4B; // Arrow Down → 'K'

                        default: ps2_key_data <= 8'h00; // idle / unknown
                    endcase

                    last_data_received <= ps2_key_data;
                    ps2_key_pressed    <= 1'b1;
                end
            end
        end
    end

    PS2_Controller PS2 (
        .CLOCK_50         (inclock),
        .reset            (~resetn),
        .PS2_CLK          (ps2_clock),
        .PS2_DAT          (ps2_data),
        .received_data    (scan_code),
        .received_data_en (scan_ready)
    );

endmodule
