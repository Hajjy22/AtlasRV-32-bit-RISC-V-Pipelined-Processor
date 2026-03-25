// ============================================================
//  register_file.sv  –  32 × 32-bit register file (RV32I)
//  x0 is hardwired to 0.  Two async read ports, one sync write.
// ============================================================
module register_file (
    input  logic        clk,
    input  logic        we3,          // write enable (WB stage)
    input  logic [4:0]  ra1, ra2,     // read addresses
    input  logic [4:0]  wa3,          // write address
    input  logic [31:0] wd3,          // write data
    output logic [31:0] rd1, rd2      // read data (combinational)
);

    logic [31:0] regs [31:0];

    // Synchronous write, x0 always stays 0
    // (always instead of always_ff to allow the initial block below
    //  to co-drive 'regs' for simulation initialisation)
    always @(posedge clk) begin
        if (we3 && wa3 != 5'b0)
            regs[wa3] <= wd3;
    end

    // Asynchronous read with write-through bypass:
    // If WB is writing the same register we're reading this cycle,
    // return the write data directly (avoids read-before-write hazard
    // when a 3-instruction gap leaves no forwarding path in EX).
    assign rd1 = (ra1 == 5'b0)              ? 32'b0  :
                 (we3 && wa3 == ra1)        ? wd3    :
                                              regs[ra1];
    assign rd2 = (ra2 == 5'b0)              ? 32'b0  :
                 (we3 && wa3 == ra2)        ? wd3    :
                                              regs[ra2];

    // Initialise all registers to 0 for simulation
    initial begin
        for (int i = 0; i < 32; i++)
            regs[i] = 32'b0;
    end

endmodule