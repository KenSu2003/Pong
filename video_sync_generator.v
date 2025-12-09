module video_sync_generator(
    input  vga_clk,
    input  reset,
    output reg blank_n,
    output reg HS,
    output reg VS
);

    // VGA 640x480 @ 60Hz timing parameters
    parameter H_VISIBLE = 640;
    parameter H_FRONT   = 16;
    parameter H_SYNC    = 96;
    parameter H_BACK    = 48;
    parameter H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    parameter V_VISIBLE = 480;
    parameter V_FRONT   = 10;
    parameter V_SYNC    = 2;
    parameter V_BACK    = 33;
    parameter V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL-1) begin
                h_count <= 0;
                if (v_count == V_TOTAL-1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // Horizontal Sync
    always @(*) begin
        HS = ~((h_count >= H_VISIBLE + H_FRONT) &&
               (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
    end

    // Vertical Sync
    always @(*) begin
        VS = ~((v_count >= V_VISIBLE + V_FRONT) &&
               (v_count <  V_VISIBLE + V_FRONT + V_SYNC));
    end

    // Blank signal
    always @(*) begin
        blank_n = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    end

endmodule
