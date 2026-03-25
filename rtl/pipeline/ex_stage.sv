// ============================================================
//  ex_stage.sv  –  Execute (EX) Stage
//  ALU + forwarding muxes + branch target computation
// ============================================================
module ex_stage (
    input  logic [31:0] rd1_e, rd2_e,       // from ID/EX register
    input  logic [31:0] imm_ext_e,
    input  logic [31:0] pc_e,
    input  logic [3:0]  alu_ctrl_e,
    input  logic [1:0]  alu_src_a_e,
    input  logic        alu_src_b_e,
    input  logic        jalr_e,             // 1 = JALR (target = rs1+imm)
    // Forwarding
    input  logic [1:0]  forward_a_e,
    input  logic [1:0]  forward_b_e,
    input  logic [31:0] alu_result_m,       // EX/MEM forward
    input  logic [31:0] result_w,           // MEM/WB forward
    // Outputs
    output logic [31:0] alu_result_e,
    output logic        zero_e,
    output logic [31:0] pc_target_e,        // branch/jump target
    output logic [31:0] write_data_e        // rs2 (after forwarding)
);

    logic [31:0] src_a_raw, src_a;
    logic [31:0] src_b_raw, src_b;

    // Forwarding mux A (selects rs1 source)
    always_comb begin
        unique case (forward_a_e)
            2'b00 : src_a_raw = rd1_e;
            2'b01 : src_a_raw = result_w;
            2'b10 : src_a_raw = alu_result_m;
            default: src_a_raw = rd1_e;
        endcase
    end

    // Forwarding mux B (selects rs2 source)
    always_comb begin
        unique case (forward_b_e)
            2'b00 : src_b_raw = rd2_e;
            2'b01 : src_b_raw = result_w;
            2'b10 : src_b_raw = alu_result_m;
            default: src_b_raw = rd2_e;
        endcase
    end

    assign write_data_e = src_b_raw;

    // ALU input A mux (rs1, PC, or 0 for LUI)
    always_comb begin
        unique case (alu_src_a_e)
            2'b00 : src_a = src_a_raw;
            2'b01 : src_a = pc_e;
            2'b10 : src_a = 32'b0;
            default: src_a = src_a_raw;
        endcase
    end

    // ALU input B mux (rs2 or immediate)
    assign src_b = alu_src_b_e ? imm_ext_e : src_b_raw;

    // ALU
    alu alu_inst (
        .a        (src_a),
        .b        (src_b),
        .alu_ctrl (alu_ctrl_e),
        .result   (alu_result_e),
        .zero     (zero_e)
    );

    // Branch/JAL target: PC + imm
    // JALR target:       rs1 + imm, LSB forced to 0 (RV32I spec)
    logic [31:0] jalr_raw;
    assign jalr_raw    = src_a_raw + imm_ext_e;
    assign pc_target_e = jalr_e ? {jalr_raw[31:1], 1'b0} : pc_e + imm_ext_e;

endmodule