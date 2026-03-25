// ============================================================
//  top.sv  -  Top-level wrapper for FPGA synthesis
//  Target: Xilinx Artix-7 (Basys3 / Nexys A7)
// ============================================================
module top (
    input  logic clk_100mhz,    // 100 MHz board clock
    input  logic btnC,          // centre button = active-high reset
    output logic [15:0] led     // status LEDs (optional debug)
);

    // Clock divider: 100 MHz -> 25 MHz for processor
    logic [1:0] clk_div;
    logic clk_cpu_raw;
    logic clk_cpu;
    logic [31:0] pc_out;

    always_ff @(posedge clk_100mhz) begin
        clk_div <= clk_div + 1;
    end
    
    assign clk_cpu_raw = clk_div[1];

    // Force the generated clock onto the FPGA's dedicated low-skew clock tree
    BUFG bufg_cpu_clk (
        .I(clk_cpu_raw),
        .O(clk_cpu)
    );

    // Synchronous reset synchroniser
    logic rst_sync_1, rst_sync;
    always_ff @(posedge clk_cpu) begin
        rst_sync_1 <= btnC;
        rst_sync   <= rst_sync_1;
    end

    // RISC-V core
    riscv_core u_core (
        .clk (clk_cpu),
        .rst (rst_sync),
        .debug_pc (pc_out)
    );

    // Display bits [17:2] of the PC on the LEDs.
    assign led = pc_out[17:2];

endmodule
