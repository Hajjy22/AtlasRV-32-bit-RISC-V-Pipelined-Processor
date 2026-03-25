// ============================================================
//  if_stage.sv  –  Instruction Fetch (IF) Stage
//  PC register + instruction memory read
// ============================================================
module if_stage #(
    parameter MEM_DEPTH = 256          // number of 32-bit words
)(
    input  logic        clk, rst,
    input  logic        stall,          // from hazard unit
    input  logic        pc_src,         // branch/jump taken
    input  logic [31:0] pc_branch,      // target PC from EX
    output logic [31:0] pc_f,           // current PC (to IF/ID reg)
    output logic [31:0] instr_f         // fetched instruction
);

    logic [31:0] pc_next;
    logic [31:0] imem [0:MEM_DEPTH-1];

    // Instruction memory – initialise from hex file in simulation
    initial begin
        for (int i = 0; i < MEM_DEPTH; i++)
            imem[i] = 32'h00000013; // NOP (ADDI x0, x0, 0)
        $readmemh("software/program.hex", imem);
    end

    // PC register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc_f <= 32'h0000_0000;
        else if (!stall)
            pc_f <= pc_next;
    end

    assign pc_next  = pc_src ? pc_branch : pc_f + 4;
    assign instr_f  = imem[pc_f[9:2]];   // word-addressed

endmodule
