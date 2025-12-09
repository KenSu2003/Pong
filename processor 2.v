/**
 * READ THIS DESCRIPTION!
 *
 * The processor takes in several inputs from a skeleton file.
 *
 * Inputs
 * clock: this is the clock for your processor at 50 MHz
 * reset: we should be able to assert a reset to start your pc from 0 (sync or
 * async is fine)
 *
 * Imem: input data from imem
 * Dmem: input data from dmem
 * Regfile: input data from regfile
 *
 * Outputs
 * Imem: output control signals to interface with imem
 * Dmem: output control signals and data to interface with dmem
 * Regfile: output control signals and data to interface with regfile
 *
 * Notes
 *
 * Ultimately, your processor will be tested by subsituting a master skeleton, imem, dmem, so the
 * testbench can see which controls signal you active when. Therefore, there needs to be a way to
 * "inject" imem, dmem, and regfile interfaces from some external controller module. The skeleton
 * file acts as a small wrapper around your processor for this purpose.
 *
 * You will need to figure out how to instantiate two memory elements, called
 * "syncram," in Quartus: one for imem and one for dmem. Each should take in a
 * 12-bit address and allow for storing a 32-bit value at each address. Each
 * should have a single clock.
 *
 * Each memory element should have a corresponding .mif file that initializes
 * the memory element to certain value on start up. These should be named
 * imem.mif and dmem.mif respectively.
 *
 * Importantly, these .mif files should be placed at the top level, i.e. there
 * should be an imem.mif and a dmem.mif at the same level as process.v. You
 * should figure out how to point your generated imem.v and dmem.v files at
 * these MIF files.
 *
 * imem
 * Inputs:  12-bit address, 1-bit clock enable, and a clock
 * Outputs: 32-bit instruction
 *
 * dmem
 * Inputs:  12-bit address, 1-bit clock, 32-bit data, 1-bit write enable
 * Outputs: 32-bit data at the given address
 *
 */
 
module processor(
    clock, reset,
    address_imem, q_imem,
    address_dmem, data, wren, q_dmem,
    ctrl_writeEnable, ctrl_writeReg, ctrl_readRegA, ctrl_readRegB,
    data_writeReg, data_readRegA, data_readRegB,
    
    // —————————————————— NEW PONG PORTS ——————————————————
    ps2_key_pressed, ps2_out,
    vga_ball_x, vga_ball_y, vga_paddle_left, vga_paddle_right
);

    input  clock, reset;
    output [11:0] address_imem;
    input  [31:0] q_imem;

    output [11:0] address_dmem;
    output [31:0] data;
    output        wren;
    input  [31:0] q_dmem;
    
    output        ctrl_writeEnable;
    output [4:0]  ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
    output [31:0] data_writeReg;
    input  [31:0] data_readRegA, data_readRegB;

    // PONG I/O
    input         ps2_key_pressed;
    input  [7:0]  ps2_out;
    output reg [9:0] vga_ball_x;
    output reg [8:0] vga_ball_y;
    output reg [8:0] vga_paddle_left;
    output reg [8:0] vga_paddle_right;

    // —————————————————————————————————————————————————————————————
    // MEMORY MAPPED I/O LOGIC (GLUE LOGIC)
    // —————————————————————————————————————————————————————————————
    
    // 1. MEMORY MAP ADDRESSES
    localparam KEYBOARD_ADDR = 12'd2000;
    localparam BALL_X_ADDR   = 12'd3000;
    localparam BALL_Y_ADDR   = 12'd3001;
    localparam PADDLE_L_ADDR = 12'd3002;
    localparam PADDLE_R_ADDR = 12'd3003;

    // 2. READ MUX: Decide what data goes into the writeback
    // If address is 2000, read Keyboard. Otherwise, read RAM (q_dmem).
    wire [31:0] actual_mem_read_data;
    
    assign actual_mem_read_data = (address_dmem == KEYBOARD_ADDR) ? 
                                  {24'b0, ps2_out} :  // Pad 8-bit key to 32-bit
                                  q_dmem;             // Otherwise read RAM

    // 3. WRITE LOGIC: Update VGA Registers
    // We "snoop" on the write bus. If the processor writes to 3000+, 
    // we catch that data and put it into the VGA registers.
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            // Reset Game State (Start in Middle)
            vga_ball_x <= 10'd320;      
            vga_ball_y <= 9'd240;       
            vga_paddle_left <= 9'd200;  
            vga_paddle_right <= 9'd200; 
        end else begin
            // If Processor is writing (wren is High)
            if (wren) begin
                if (address_dmem == BALL_X_ADDR)   vga_ball_x <= data[9:0];
                if (address_dmem == BALL_Y_ADDR)   vga_ball_y <= data[8:0];
                if (address_dmem == PADDLE_L_ADDR) vga_paddle_left <= data[8:0];
                if (address_dmem == PADDLE_R_ADDR) vga_paddle_right <= data[8:0];
            end
        end
    end

    // —————————————————————————————————————————————————————————————
    // ORIGINAL CPU LOGIC (UNTOUCHED EXCEPT FOR WB MUX)
    // —————————————————————————————————————————————————————————————

    wire [31:0] pc, pc_plus1, pc_plusN1, pc_next;
    wire [31:0] instr = q_imem;
    wire [4:0]  opcode = instr[31:27]; 
    wire [4:0]  rd     = instr[26:22];
    wire [4:0]  rs     = instr[21:17];
    wire [4:0]  rt     = instr[16:12];
    wire [4:0]  shamt  = instr[11:7];
    wire [4:0]  alu_fn = instr[6:2];
    wire [16:0] imm17  = instr[16:0];
    wire [26:0] T      = instr[26:0];

    wire is_R     = ~|(opcode ^ 5'b00000);
    wire is_addi  = ~|(opcode ^ 5'b00101);
    wire is_sw    = ~|(opcode ^ 5'b00111);
    wire is_lw    = ~|(opcode ^ 5'b01000);
	 
    wire is_j     = ~|(opcode ^ 5'b00001);
    wire is_bne   = ~|(opcode ^ 5'b00010);
    wire is_jal   = ~|(opcode ^ 5'b00011);
    wire is_jr    = ~|(opcode ^ 5'b00100);
    wire is_blt   = ~|(opcode ^ 5'b00110);
    wire is_bex   = ~|(opcode ^ 5'b10110);
    wire is_setx  = ~|(opcode ^ 5'b10101);
    wire subop_add = is_R & ~|(alu_fn ^ 5'b00000);
    wire subop_sub = is_R & ~|(alu_fn ^ 5'b00001);
    wire [31:0] imm_sext = {{15{imm17[16]}}, imm17};
    wire [31:0] T_uxt = {5'b00000, T};

    RCA add_pc_plus1(.s(pc_plus1), .a(pc), .b(32'd1));
    RCA add_pc_N1(.s(pc_plusN1), .a(pc_plus1), .b(imm_sext));
    wire use_cmp   = is_bne | is_blt;
    wire [4:0] RSTATUS = 5'b11110;
    wire [4:0] readA_sel =
        is_jr   ? rd :
        is_bex  ? RSTATUS :
        use_cmp ? rd :
        rs;
    wire [4:0] readB_sel =
        use_cmp ? rs :
        (is_sw ? rd : rt);

    assign ctrl_readRegA = readA_sel;
    assign ctrl_readRegB = readB_sel;

    wire [31:0] rfA = data_readRegA;
    wire [31:0] rfB = data_readRegB;
    wire [4:0] alu_op   = is_R ? alu_fn : 5'b00000;
    wire [4:0] shamt_in = is_R ? shamt  : 5'b00000;

    wire use_immB = is_addi | is_sw | is_lw;
    wire [31:0] alu_B = use_immB ? imm_sext : rfB;

    wire [31:0] alu_out;
    wire ne, lt, ovf;
    alu UALU(
        .data_operandA(rfA),
        .data_operandB(alu_B),
        .ctrl_ALUopcode(alu_op),
        .ctrl_shiftamt(shamt_in),
        .data_result(alu_out),
        .isNotEqual(ne),
        .isLessThan(lt),
        .overflow(ovf)
    );
    wire cond_bne = is_bne & ne;
    wire cond_blt = is_blt & lt;
    wire bex_taken = is_bex & (|rfA);
    wire [31:0] pc_after_bra = (cond_bne | cond_blt) ? pc_plusN1 : pc_plus1;
    wire [31:0] pc_after_j   = (is_j | is_jal) ? T_uxt : pc_after_bra;
    wire [31:0] pc_after_bex = bex_taken ? T_uxt : pc_after_j;
    assign pc_next = is_jr ? rfA : pc_after_bex;

    assign address_imem = pc[11:0];
    assign address_dmem = alu_out[11:0];
    assign data         = rfB;
    assign wren         = is_sw;

    wire ovf_add  = ovf & subop_add;
    wire ovf_sub  = ovf & subop_sub;
    wire ovf_addi = ovf & is_addi;
    wire any_ovf  = ovf_add | ovf_sub | ovf_addi;

    wire [31:0] rstatus_code =
        (ovf_add  ? 32'd1 :
        (ovf_addi ? 32'd2 :
        (ovf_sub  ? 32'd3 : 32'd0)));
    wire wr_Rtype = is_R & ~( (subop_add | subop_sub) ? any_ovf : 1'b0 );
    wire wr_addi  = is_addi & ~any_ovf;
    wire wr_lw    = is_lw;
    wire wr_jal   = is_jal;
    wire wr_setx  = is_setx;
    wire any_wr_normal = wr_Rtype | wr_addi | wr_lw | wr_jal | wr_setx;
    wire wr_final_en   = any_wr_normal | any_ovf;

    wire [4:0] dest_normal =
        wr_jal  ? 5'b11111 :     
        wr_setx ? 5'b11110 :     
                  rd;
    wire [4:0] dest_final  = any_ovf ? 5'b11110 : dest_normal;
    
    // —————————————————————————————————————————————————————————
    // CRITICAL CHANGE: Use 'actual_mem_read_data' instead of 'q_dmem'
    // —————————————————————————————————————————————————————————
    wire [31:0] wb_normal =
        wr_jal  ? pc_plus1 :
        wr_setx ? T_uxt    :
        wr_lw   ? actual_mem_read_data : // CHANGED FROM q_dmem
                  alu_out;
                  
    wire [31:0] wb_final  = any_ovf ? rstatus_code : wb_normal;

    assign ctrl_writeEnable = wr_final_en;

    assign ctrl_writeReg  = dest_final;
    assign data_writeReg  = wb_final;

    wire [31:0] pc_d = pc_next;
    genvar i;
    generate
        for (i=0; i<32; i=i+1) begin: PC_BANK
            dffe_ref dff_pc(.q(pc[i]), .d(pc_d[i]), .clk(clock), .en(1'b1), .clr(reset));
        end
    endgenerate
endmodule