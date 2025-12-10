module lcd(
    input       clock,
    input       resetn,
    input       write_en,
    input [7:0] data_in,
    output [7:0] lcd_data,
    output      lcd_rw,
    output      lcd_en,
    output      lcd_rs,
    output      lcd_on,
    output      lcd_blon
);

    assign lcd_data = data_in;
    assign lcd_rw   = 1'b0;
    assign lcd_en   = 1'b0;
    assign lcd_rs   = 1'b0;
    assign lcd_on   = 1'b1;
    assign lcd_blon = 1'b1;

endmodule
