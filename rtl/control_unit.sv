// ============================================================
//  control_unit.sv  –  Main decoder + ALU decoder for RV32I
// ============================================================
module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    // Datapath control signals
    output logic       reg_write,
    output logic       mem_read,
    output logic       mem_write,
    output logic [1:0] mem_to_reg,   // 00=ALU, 01=MEM, 10=PC+4
    output logic       branch,
    output logic       jump,
    output logic [1:0] alu_src_a,    // 00=rs1, 01=PC, 10=0
    output logic       alu_src_b,    // 0=rs2,  1=imm
    output logic [3:0] alu_ctrl,
    output logic [2:0] imm_sel       // immediate format
);

    // Opcode definitions
    localparam OP_R      = 7'b0110011;
    localparam OP_I      = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;

    // Immediate format select
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    // ALU control (matches alu.sv)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    // -------------------------------------------------------
    //  Main decode + ALU decoder (combined into one block to
    //  avoid vlog-7033 multiple-driver error on alu_ctrl)
    // -------------------------------------------------------
    always_comb begin
        // Safe defaults
        reg_write  = 1'b0; mem_read   = 1'b0; mem_write  = 1'b0;
        mem_to_reg = 2'b00; branch    = 1'b0; jump       = 1'b0;
        alu_src_a  = 2'b00; alu_src_b = 1'b0;
        alu_ctrl   = ALU_ADD; imm_sel = IMM_I;

        unique case (opcode)
            OP_R : begin
                reg_write = 1'b1;
                unique case (funct3)
                    3'b000 : alu_ctrl = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b001 : alu_ctrl = ALU_SLL;
                    3'b010 : alu_ctrl = ALU_SLT;
                    3'b011 : alu_ctrl = ALU_SLTU;
                    3'b100 : alu_ctrl = ALU_XOR;
                    3'b101 : alu_ctrl = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110 : alu_ctrl = ALU_OR;
                    3'b111 : alu_ctrl = ALU_AND;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end
            OP_I : begin
                reg_write = 1'b1; alu_src_b = 1'b1; imm_sel = IMM_I;
                unique case (funct3)
                    3'b000 : alu_ctrl = ALU_ADD;
                    3'b001 : alu_ctrl = ALU_SLL;
                    3'b010 : alu_ctrl = ALU_SLT;
                    3'b011 : alu_ctrl = ALU_SLTU;
                    3'b100 : alu_ctrl = ALU_XOR;
                    3'b101 : alu_ctrl = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110 : alu_ctrl = ALU_OR;
                    3'b111 : alu_ctrl = ALU_AND;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end
            OP_LOAD : begin
                reg_write = 1'b1; mem_read  = 1'b1;
                alu_src_b = 1'b1; mem_to_reg = 2'b01; imm_sel = IMM_I;
            end
            OP_STORE : begin
                mem_write = 1'b1; alu_src_b = 1'b1; imm_sel = IMM_S;
            end
            OP_BRANCH : begin
                branch = 1'b1; imm_sel = IMM_B;
                unique case (funct3)
                    3'b000, 3'b001 : alu_ctrl = ALU_SUB;  // BEQ, BNE
                    3'b100, 3'b101 : alu_ctrl = ALU_SLT;  // BLT, BGE
                    3'b110, 3'b111 : alu_ctrl = ALU_SLTU; // BLTU, BGEU
                    default:         alu_ctrl = ALU_SUB;
                endcase
            end
            OP_JAL : begin
                jump = 1'b1; reg_write = 1'b1;
                mem_to_reg = 2'b10; alu_src_a = 2'b01; alu_src_b = 1'b1;
                imm_sel = IMM_J;
            end
            OP_JALR : begin
                jump = 1'b1; reg_write = 1'b1;
                mem_to_reg = 2'b10; alu_src_b = 1'b1; imm_sel = IMM_I;
            end
            OP_LUI : begin
                reg_write = 1'b1; alu_src_a = 2'b10; alu_src_b = 1'b1;
                imm_sel = IMM_U;
            end
            OP_AUIPC : begin
                reg_write = 1'b1; alu_src_a = 2'b01; alu_src_b = 1'b1;
                imm_sel = IMM_U;
            end
            default: ;
        endcase
    end

endmodule