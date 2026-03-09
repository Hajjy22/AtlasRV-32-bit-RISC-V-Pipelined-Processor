// ============================================================
//  forwarding_unit.sv  –  Data Forwarding Unit
//
//  Resolves RAW data hazards by forwarding results from
//  EX/MEM and MEM/WB pipeline registers to the EX stage.
//
//  Forward encoding:
//    2'b00 = no forwarding (use register file value)
//    2'b01 = forward from WB (MEM/WB.ALUresult)
//    2'b10 = forward from MEM (EX/MEM.ALUresult)
// ============================================================
module forwarding_unit (
    // EX stage source registers
    input  logic [4:0]  rs1_e, rs2_e,
    // EX/MEM pipeline register
    input  logic [4:0]  rd_m,
    input  logic        reg_write_m,
    // MEM/WB pipeline register
    input  logic [4:0]  rd_w,
    input  logic        reg_write_w,
    // Forwarding select outputs
    output logic [1:0]  forward_a_e,
    output logic [1:0]  forward_b_e
);

    // Forward A (rs1)
    always_comb begin
        if (reg_write_m && (rd_m != 5'b0) && (rd_m == rs1_e))
            forward_a_e = 2'b10;          // EX/MEM forward
        else if (reg_write_w && (rd_w != 5'b0) && (rd_w == rs1_e))
            forward_a_e = 2'b01;          // MEM/WB forward
        else
            forward_a_e = 2'b00;          // no forwarding
    end

    // Forward B (rs2)
    always_comb begin
        if (reg_write_m && (rd_m != 5'b0) && (rd_m == rs2_e))
            forward_b_e = 2'b10;
        else if (reg_write_w && (rd_w != 5'b0) && (rd_w == rs2_e))
            forward_b_e = 2'b01;
        else
            forward_b_e = 2'b00;
    end

endmodule
