// ============================================================
//  hazard_detection.sv  –  Hazard Detection Unit
//
//  Detects load-use data hazards and inserts a stall bubble.
//  Also asserts flush when a branch/jump is taken.
// ============================================================
module hazard_detection (
    // Inputs from pipeline registers
    input  logic [4:0]  rs1_d, rs2_d,      // ID stage source regs
    input  logic [4:0]  rd_e,              // EX stage dest reg
    input  logic        mem_read_e,        // EX is a load
    input  logic        branch_e,          // EX is a branch (taken)
    input  logic        jump_e,            // EX is a jump
    input  logic        pc_src,            // actual branch/jump decision
    // Outputs
    output logic        stall_f,           // stall Fetch stage
    output logic        stall_d,           // stall Decode stage
    output logic        flush_e,           // flush Execute stage (insert NOP)
    output logic        flush_d            // flush Decode stage (branch flush)
);

    // Load-use hazard: stall for one cycle
    logic load_use_hazard;
    assign load_use_hazard = mem_read_e &&
                             ((rd_e == rs1_d) || (rd_e == rs2_d)) &&
                             (rd_e != 5'b0);

    // Control hazard: flush decode and execute when branch/jump taken
    // (we use predict-not-taken; flush on misprediction)
    assign stall_f  = load_use_hazard;
    assign stall_d  = load_use_hazard;
    assign flush_e  = load_use_hazard | pc_src;
    assign flush_d  = pc_src;

endmodule
