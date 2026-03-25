// ============================================================
//  mem_stage.sv  –  Memory Access (MEM) Stage
//  32-bit data memory (byte-addressed, word-aligned accesses)
//
//  FIX: Restructured from partial bit-slice writes to a proper
//  4-bank byte-enable template that Vivado can infer cleanly.
//  The previous pattern (dmem[addr][7:0] <= ...) triggered a
//  known Vivado 2024.x defect where partial byte-wide write
//  enable RAM inference produces invalid routethru arcs in the
//  post-route netlist, causing 50 DRC PDIL-1 errors that block
//  write_bitstream.
// ============================================================
module mem_stage #(
    parameter MEM_DEPTH = 256
)(
    input  logic        clk, rst,
    input  logic        mem_read_m,
    input  logic        mem_write_m,
    input  logic [2:0]  funct3_m,
    input  logic [31:0] alu_result_m,
    input  logic [31:0] write_data_m,
    output logic [31:0] read_data_m
);

    // -------------------------------------------------------
    //  Four independent byte-banks.
    //  Bank 0 = bits [7:0], bank 1 = bits [15:8], etc.
    //  Vivado infers each as a proper byte-enable RAM and maps
    //  them without partial-write routethru issues.
    // -------------------------------------------------------
    logic [7:0] dmem_b0 [0:MEM_DEPTH-1];
    logic [7:0] dmem_b1 [0:MEM_DEPTH-1];
    logic [7:0] dmem_b2 [0:MEM_DEPTH-1];
    logic [7:0] dmem_b3 [0:MEM_DEPTH-1];

    // Word address
    logic [$clog2(MEM_DEPTH)-1:0] waddr;
    assign waddr = alu_result_m[$clog2(MEM_DEPTH)+1:2];

    // Byte enables derived from funct3 and byte offset
    logic [3:0] byte_en;
    always_comb begin
        case (funct3_m)
            3'b000: begin // SB - byte
                case (alu_result_m[1:0])
                    2'b00: byte_en = 4'b0001;
                    2'b01: byte_en = 4'b0010;
                    2'b10: byte_en = 4'b0100;
                    2'b11: byte_en = 4'b1000;
                    default: byte_en = 4'b0000;
                endcase
            end
            3'b001: begin // SH - halfword
                byte_en = alu_result_m[1] ? 4'b1100 : 4'b0011;
            end
            default: byte_en = 4'b1111; // SW - word
        endcase
    end

    // Synchronous write: each bank driven independently
    always_ff @(posedge clk) begin
        if (mem_write_m) begin
            if (byte_en[0]) dmem_b0[waddr] <= write_data_m[7:0];
            if (byte_en[1]) dmem_b1[waddr] <= write_data_m[15:8];
            if (byte_en[2]) dmem_b2[waddr] <= write_data_m[23:16];
            if (byte_en[3]) dmem_b3[waddr] <= write_data_m[31:24];
        end
    end

    // Asynchronous read with sign/zero extension
    logic [31:0] word_raw;
    assign word_raw = {dmem_b3[waddr], dmem_b2[waddr],
                       dmem_b1[waddr], dmem_b0[waddr]};

    always_comb begin
        if (mem_read_m) begin
            unique case (funct3_m)
                3'b010: read_data_m = word_raw;                          // LW
                3'b001: read_data_m = alu_result_m[1]                   // LH
                            ? {{16{word_raw[31]}}, word_raw[31:16]}
                            : {{16{word_raw[15]}}, word_raw[15:0]};
                3'b000: begin                                            // LB
                    case (alu_result_m[1:0])
                        2'b00: read_data_m = {{24{word_raw[7]}},  word_raw[7:0]};
                        2'b01: read_data_m = {{24{word_raw[15]}}, word_raw[15:8]};
                        2'b10: read_data_m = {{24{word_raw[23]}}, word_raw[23:16]};
                        2'b11: read_data_m = {{24{word_raw[31]}}, word_raw[31:24]};
                        default: read_data_m = 32'bx;
                    endcase
                end
                3'b101: read_data_m = alu_result_m[1]                   // LHU
                            ? {16'b0, word_raw[31:16]}
                            : {16'b0, word_raw[15:0]};
                3'b100: begin                                            // LBU
                    case (alu_result_m[1:0])
                        2'b00: read_data_m = {24'b0, word_raw[7:0]};
                        2'b01: read_data_m = {24'b0, word_raw[15:8]};
                        2'b10: read_data_m = {24'b0, word_raw[23:16]};
                        2'b11: read_data_m = {24'b0, word_raw[31:24]};
                        default: read_data_m = 32'bx;
                    endcase
                end
                default: read_data_m = word_raw;
            endcase
        end else begin
            read_data_m = 32'bx;
        end
    end

endmodule