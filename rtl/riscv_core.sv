// ============================================================
//  riscv_core.sv  –  32-bit 5-Stage Pipelined RISC-V Core
//
//  Pipeline stages:  IF -> ID -> EX -> MEM -> WB
//  Hazard handling:  Hazard Detection Unit + Forwarding Unit
//  ISA:              RV32I base integer instruction set
//
//  Author:  Ismail Hajjy
//  Date:    Jul. – Oct. 2024
// ============================================================
module riscv_core (
    input  logic clk,
    input  logic rst,
    output logic [31:0] debug_pc
);

    // =========================================================
    //  IF stage wires
    // =========================================================
    logic [31:0] pc_f, instr_f;
    logic        stall_f;
    logic        pc_src_e;
    logic [31:0] pc_target_e;

    // =========================================================
    //  IF/ID pipeline register
    // =========================================================
    logic [31:0] pc_d, pc_plus4_d, instr_d;
    logic        stall_d, flush_d;

    // =========================================================
    //  ID stage wires
    // =========================================================
    logic        reg_write_d, mem_read_d, mem_write_d;
    logic [1:0]  mem_to_reg_d;
    logic        branch_d, jump_d;
    logic [1:0]  alu_src_a_d;
    logic        alu_src_b_d;
    logic [3:0]  alu_ctrl_d;
    logic [31:0] rd1_d, rd2_d, imm_ext_d;
    logic [4:0]  rs1_d, rs2_d, rd_d;
    // WB writeback wires (forward-declared)
    logic        reg_write_w;
    logic [4:0]  rd_w;
    logic [31:0] result_w;

    // =========================================================
    //  ID/EX pipeline register
    // =========================================================
    logic        reg_write_e, mem_read_e, mem_write_e;
    logic [1:0]  mem_to_reg_e;
    logic        branch_e, jump_e, jalr_e;
    logic [1:0]  alu_src_a_e;
    logic        alu_src_b_e;
    logic [3:0]  alu_ctrl_e;
    logic [31:0] rd1_e, rd2_e, imm_ext_e, pc_e, pc_plus4_e;
    logic [4:0]  rs1_e, rs2_e, rd_e;
    logic [2:0]  funct3_e;
    logic        flush_e;

    // =========================================================
    //  EX stage wires
    // =========================================================
    logic [31:0] alu_result_e_wire;
    logic        zero_e;
    logic [31:0] write_data_e;
    logic [1:0]  forward_a_e, forward_b_e;

    // =========================================================
    //  EX/MEM pipeline register
    // =========================================================
    logic        reg_write_m, mem_read_m, mem_write_m;
    logic [1:0]  mem_to_reg_m;
    logic [31:0] alu_result_m, write_data_m, pc_plus4_m;
    logic [4:0]  rd_m;
    logic [2:0]  funct3_m;

    // =========================================================
    //  MEM stage wires
    // =========================================================
    logic [31:0] read_data_m;

    // =========================================================
    //  MEM/WB pipeline register
    // =========================================================
    logic [1:0]  mem_to_reg_w_reg;
    logic [31:0] alu_result_w, read_data_w, pc_plus4_w;

    // =========================================================
    //  Branch/jump decision
    // =========================================================
    // Resolved in EX stage using funct3 to distinguish all 6 types:
    //   BEQ  funct3=000: take if ALU(SUB) == 0  -> zero_e
    //   BNE  funct3=001: take if ALU(SUB) != 0  -> ~zero_e
    //   BLT  funct3=100: take if ALU(SLT) == 1  -> alu_result_e_wire[0]
    //   BGE  funct3=101: take if ALU(SLT) == 0  -> ~alu_result_e_wire[0]
    //   BLTU funct3=110: take if ALU(SLTU)== 1  -> alu_result_e_wire[0]
    //   BGEU funct3=111: take if ALU(SLTU)== 0  -> ~alu_result_e_wire[0]
    logic branch_taken_e;
    always_comb begin
        case (funct3_e)
            3'b000:  branch_taken_e = zero_e;
            3'b001:  branch_taken_e = ~zero_e;
            3'b100:  branch_taken_e = alu_result_e_wire[0];
            3'b101:  branch_taken_e = ~alu_result_e_wire[0];
            3'b110:  branch_taken_e = alu_result_e_wire[0];
            3'b111:  branch_taken_e = ~alu_result_e_wire[0];
            default: branch_taken_e = 1'b0;
        endcase
    end
    assign pc_src_e = (branch_e & branch_taken_e) | jump_e;

    // =========================================================
    //  Stage instantiations
    // =========================================================

    if_stage #(.MEM_DEPTH(256)) u_if (
        .clk       (clk),
        .rst       (rst),
        .stall     (stall_f),
        .pc_src    (pc_src_e),
        .pc_branch (pc_target_e),
        .pc_f      (pc_f),
        .instr_f   (instr_f)
    );

    id_stage u_id (
        .clk         (clk),
        .rst         (rst),
        .instr_d     (instr_d),
        .pc_d        (pc_d),
        .reg_write_w (reg_write_w),
        .rd_w        (rd_w),
        .result_w    (result_w),
        .reg_write_d (reg_write_d),
        .mem_read_d  (mem_read_d),
        .mem_write_d (mem_write_d),
        .mem_to_reg_d(mem_to_reg_d),
        .branch_d    (branch_d),
        .jump_d      (jump_d),
        .alu_src_a_d (alu_src_a_d),
        .alu_src_b_d (alu_src_b_d),
        .alu_ctrl_d  (alu_ctrl_d),
        .rd1_d       (rd1_d),
        .rd2_d       (rd2_d),
        .imm_ext_d   (imm_ext_d),
        .rs1_d       (rs1_d),
        .rs2_d       (rs2_d),
        .rd_d        (rd_d)
    );

    ex_stage u_ex (
        .rd1_e        (rd1_e),
        .rd2_e        (rd2_e),
        .imm_ext_e    (imm_ext_e),
        .pc_e         (pc_e),
        .alu_ctrl_e   (alu_ctrl_e),
        .alu_src_a_e  (alu_src_a_e),
        .alu_src_b_e  (alu_src_b_e),
        .jalr_e       (jalr_e),
        .forward_a_e  (forward_a_e),
        .forward_b_e  (forward_b_e),
        .alu_result_m (alu_result_m),
        .result_w     (result_w),
        .alu_result_e (alu_result_e_wire),
        .zero_e       (zero_e),
        .pc_target_e  (pc_target_e),
        .write_data_e (write_data_e)
    );

    mem_stage #(.MEM_DEPTH(256)) u_mem (
        .clk          (clk),
        .rst          (rst),
        .mem_read_m   (mem_read_m),
        .mem_write_m  (mem_write_m),
        .funct3_m     (funct3_m),
        .alu_result_m (alu_result_m),
        .write_data_m (write_data_m),
        .read_data_m  (read_data_m)
    );

    wb_stage u_wb (
        .mem_to_reg_w  (mem_to_reg_w_reg),
        .alu_result_w  (alu_result_w),
        .read_data_w   (read_data_w),
        .pc_plus4_w    (pc_plus4_w),
        .result_w      (result_w)
    );

    // =========================================================
    //  Hazard Detection Unit
    // =========================================================
    hazard_detection u_hazard (
        .rs1_d       (rs1_d),
        .rs2_d       (rs2_d),
        .rd_e        (rd_e),
        .mem_read_e  (mem_read_e),
        .branch_e    (branch_e),
        .jump_e      (jump_e),
        .pc_src      (pc_src_e),
        .stall_f     (stall_f),
        .stall_d     (stall_d),
        .flush_e     (flush_e),
        .flush_d     (flush_d)
    );

    // =========================================================
    //  Forwarding Unit
    // =========================================================
    forwarding_unit u_fwd (
        .rs1_e       (rs1_e),
        .rs2_e       (rs2_e),
        .rd_m        (rd_m),
        .reg_write_m (reg_write_m),
        .rd_w        (rd_w),
        .reg_write_w (reg_write_w),
        .forward_a_e (forward_a_e),
        .forward_b_e (forward_b_e)
    );

    // =========================================================
    //  Pipeline Registers
    // =========================================================

    // --- IF/ID ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush_d) begin
            instr_d    <= 32'h00000013; // NOP
            pc_d       <= 32'b0;
            pc_plus4_d <= 32'b0;
        end else if (!stall_d) begin
            instr_d    <= instr_f;
            pc_d       <= pc_f;
            pc_plus4_d <= pc_f + 4;
        end
    end

    // --- ID/EX ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush_e) begin
            reg_write_e  <= 1'b0; mem_read_e   <= 1'b0;
            mem_write_e  <= 1'b0; mem_to_reg_e <= 2'b0;
            branch_e     <= 1'b0; jump_e        <= 1'b0; jalr_e <= 1'b0;
            alu_src_a_e  <= 2'b0; alu_src_b_e  <= 1'b0;
            alu_ctrl_e   <= 4'b0;
            rd1_e        <= 32'b0; rd2_e        <= 32'b0;
            imm_ext_e    <= 32'b0; pc_e         <= 32'b0;
            pc_plus4_e   <= 32'b0;
            rs1_e        <= 5'b0; rs2_e         <= 5'b0;
            rd_e         <= 5'b0; funct3_e      <= 3'b0;
        end else begin
            reg_write_e  <= reg_write_d; mem_read_e   <= mem_read_d;
            mem_write_e  <= mem_write_d; mem_to_reg_e <= mem_to_reg_d;
            branch_e     <= branch_d;    jump_e        <= jump_d;
            jalr_e       <= (instr_d[6:0] == 7'b1100111); // OP_JALR
            alu_src_a_e  <= alu_src_a_d; alu_src_b_e  <= alu_src_b_d;
            alu_ctrl_e   <= alu_ctrl_d;
            rd1_e        <= rd1_d;       rd2_e         <= rd2_d;
            imm_ext_e    <= imm_ext_d;   pc_e          <= pc_d;
            pc_plus4_e   <= pc_plus4_d;
            rs1_e        <= rs1_d;       rs2_e         <= rs2_d;
            rd_e         <= rd_d;        funct3_e      <= instr_d[14:12];
        end
    end

    // --- EX/MEM ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_m  <= 1'b0; mem_read_m   <= 1'b0;
            mem_write_m  <= 1'b0; mem_to_reg_m <= 2'b0;
            alu_result_m <= 32'b0; write_data_m <= 32'b0;
            pc_plus4_m   <= 32'b0;
            rd_m         <= 5'b0; funct3_m     <= 3'b0;
        end else begin
            reg_write_m  <= reg_write_e; mem_read_m   <= mem_read_e;
            mem_write_m  <= mem_write_e; mem_to_reg_m <= mem_to_reg_e;
            alu_result_m <= alu_result_e_wire;
            write_data_m <= write_data_e;
            pc_plus4_m   <= pc_plus4_e;
            rd_m         <= rd_e;        funct3_m     <= funct3_e;
        end
    end

    // --- MEM/WB ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_w    <= 1'b0;
            mem_to_reg_w_reg <= 2'b0;
            alu_result_w   <= 32'b0;
            read_data_w    <= 32'b0;
            pc_plus4_w     <= 32'b0;
            rd_w           <= 5'b0;
        end else begin
            reg_write_w    <= reg_write_m;
            mem_to_reg_w_reg <= mem_to_reg_m;
            alu_result_w   <= alu_result_m;
            read_data_w    <= read_data_m;
            pc_plus4_w     <= pc_plus4_m;
            rd_w           <= rd_m;
        end
    end

assign debug_pc = pc_f;

endmodule