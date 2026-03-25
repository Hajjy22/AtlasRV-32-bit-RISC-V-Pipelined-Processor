// ============================================================
//  id_stage.sv  –  Instruction Decode (ID) Stage
//  Decodes instruction, reads register file, extends immediate
// ============================================================
module id_stage (
    input  logic        clk, rst,
    input  logic [31:0] pc_d,
    // From IF/ID pipeline register
    input  logic [31:0] instr_d,
    // Write-back port (from WB stage)
    input  logic        reg_write_w,
    input  logic [4:0]  rd_w,
    input  logic [31:0] result_w,
    // Control outputs
    output logic        reg_write_d,
    output logic        mem_read_d,
    output logic        mem_write_d,
    output logic [1:0]  mem_to_reg_d,
    output logic        branch_d,
    output logic        jump_d,
    output logic [1:0]  alu_src_a_d,
    output logic        alu_src_b_d,
    output logic [3:0]  alu_ctrl_d,
    // Data outputs
    output logic [31:0] rd1_d, rd2_d,
    output logic [31:0] imm_ext_d,
    output logic [4:0]  rs1_d, rs2_d, rd_d
);

    // Decode fields
    assign rs1_d = instr_d[19:15];
    assign rs2_d = instr_d[24:20];
    assign rd_d  = instr_d[11:7];

    // Control unit (single instance - imm_sel now properly connected)
    logic [2:0] imm_sel_d;
    control_unit ctrl (
        .opcode     (instr_d[6:0]),
        .funct3     (instr_d[14:12]),
        .funct7     (instr_d[31:25]),
        .reg_write  (reg_write_d),
        .mem_read   (mem_read_d),
        .mem_write  (mem_write_d),
        .mem_to_reg (mem_to_reg_d),
        .branch     (branch_d),
        .jump       (jump_d),
        .alu_src_a  (alu_src_a_d),
        .alu_src_b  (alu_src_b_d),
        .alu_ctrl   (alu_ctrl_d),
        .imm_sel    (imm_sel_d)
    );

    imm_extend imm_ext_unit (
        .instr   (instr_d[31:7]),
        .imm_sel (imm_sel_d),
        .imm_ext (imm_ext_d)
    );

    // Register file
    register_file rf (
        .clk (clk),
        .we3 (reg_write_w),
        .ra1 (rs1_d),
        .ra2 (rs2_d),
        .wa3 (rd_w),
        .wd3 (result_w),
        .rd1 (rd1_d),
        .rd2 (rd2_d)
    );

endmodule
