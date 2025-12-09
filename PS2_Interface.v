module PS2_Interface(inclock, resetn, ps2_clock, ps2_data, ps2_key_data, ps2_key_pressed, last_data_received);

    input           inclock, resetn;
    inout           ps2_clock, ps2_data;
    output          ps2_key_pressed;
    output  [7:0]   ps2_key_data;
    output  reg [7:0] last_data_received;

    wire [7:0] scan_code_wire;
    reg key_released; // Flag to track Break Code (F0)

    assign ps2_key_data = scan_code_wire;

    always @(posedge inclock) begin
        if (resetn == 1'b0) begin
            last_data_received <= 8'h00;
            key_released <= 1'b0;
        end
        else if (ps2_key_pressed == 1'b1) begin
            // 1. Detect Break Code (F0)
            if (scan_code_wire == 8'hF0) begin
                key_released <= 1'b1;
            end
            // 2. Handle Key Codes
            else begin
                if (key_released == 1'b0) begin
                    // === MAKE CODE (Key Pressed) ===
                    case (scan_code_wire)
                        8'h1D: last_data_received <= 8'h77; // W
                        8'h1B: last_data_received <= 8'h73; // S
                        8'h44: last_data_received <= 8'h6F; // O
                        8'h4B: last_data_received <= 8'h6C; // L
                        default: ; // Ignore other keys to prevent overwriting
                    endcase
                end
                else begin
                    // === BREAK CODE (Key Released) ===
                    // Only stop if the released key is the one currently active
                    case (scan_code_wire)
                        8'h1D: if (last_data_received == 8'h77) last_data_received <= 8'h00; // Release W
                        8'h1B: if (last_data_received == 8'h73) last_data_received <= 8'h00; // Release S
                        8'h44: if (last_data_received == 8'h6F) last_data_received <= 8'h00; // Release O
                        8'h4B: if (last_data_received == 8'h6C) last_data_received <= 8'h00; // Release L
                    endcase
                    key_released <= 1'b0; // Reset flag
                end
            end
        end
    end

    PS2_Controller PS2 (
        .CLOCK_50           (inclock),
        .reset              (~resetn),
        .PS2_CLK            (ps2_clock),
        .PS2_DAT            (ps2_data),
        .received_data      (scan_code_wire),
        .received_data_en   (ps2_key_pressed)
    );
endmodule