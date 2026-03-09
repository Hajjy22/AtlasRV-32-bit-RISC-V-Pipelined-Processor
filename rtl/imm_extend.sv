// ============================================================
//  imm_extend.sv  –  Immediate sign-extension for RV32I
// ============================================================
module imm_extend (
    input  logic [31:7] instr,    // instruction bits [31:7]
    input  logic [2:0]  imm_sel,  // format select from control unit
    output logic [31:0] imm_ext
);

    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    always_comb begin
        unique case (imm_sel)
            IMM_I : imm_ext = {{20{instr[31]}}, instr[31:20]};
            IMM_S : imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_B : imm_ext = {{19{instr[31]}}, instr[31], instr[7],
                                instr[30:25], instr[11:8], 1'b0};
            IMM_U : imm_ext = {instr[31:12], 12'b0};
            IMM_J : imm_ext = {{11{instr[31]}}, instr[31], instr[19:12],
                                instr[20], instr[30:21], 1'b0};
            default: imm_ext = 32'bx;
        endcase
    end

endmodule
