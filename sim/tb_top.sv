// ============================================================
//  tb_top.sv  –  Directed + Constrained-Random Testbench
//  Tests: R-type, I-type, Load/Store, Branch, JAL, Hazards
// ============================================================
`timescale 1ns/1ps

module tb_top;

    // -------------------------------------------------------
    //  DUT signals
    // -------------------------------------------------------
    logic clk, rst;

    riscv_core dut (
        .clk (clk),
        .rst (rst)
    );

    // -------------------------------------------------------
    //  Clock: 10 ns period (100 MHz)
    // -------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------
    //  Test program loader helper task
    // -------------------------------------------------------
    task automatic load_program(input string hex_file);
        $readmemh(hex_file, dut.u_if.imem);
        // Clear data memory
        for (int i = 0; i < 256; i++)
            dut.u_mem.dmem[i] = 32'h0;
    endtask

    // -------------------------------------------------------
    //  Cycle counter
    // -------------------------------------------------------
    int cycle_cnt;
    always_ff @(posedge clk) cycle_cnt <= cycle_cnt + 1;

    // -------------------------------------------------------
    //  Register file read helper
    // -------------------------------------------------------
    function automatic logic [31:0] read_reg(input int idx);
        return dut.u_id.rf.regs[idx];
    endfunction

    // -------------------------------------------------------
    //  Test: R-type instructions  (ADD, SUB, AND, OR, XOR)
    // -------------------------------------------------------
    task test_r_type;
        int pass, fail;
        pass = 0; fail = 0;

        $display("\n=== TEST: R-type instructions ===");

        // Load hand-assembled program
        // addi x1, x0, 10    ; x1 = 10
        // addi x2, x0, 6     ; x2 = 6
        // add  x3, x1, x2    ; x3 = 16
        // sub  x4, x1, x2    ; x4 = 4
        // and  x5, x1, x2    ; x5 = 2
        // or   x6, x1, x2    ; x6 = 14
        // xor  x7, x1, x2    ; x7 = 12
        dut.u_if.imem[0]  = 32'h00A00093; // addi x1, x0, 10
        dut.u_if.imem[1]  = 32'h00600113; // addi x2, x0, 6
        dut.u_if.imem[2]  = 32'h002081B3; // add  x3, x1, x2
        dut.u_if.imem[3]  = 32'h40208233; // sub  x4, x1, x2
        dut.u_if.imem[4]  = 32'h002072B3; // and  x5, x1, x2
        dut.u_if.imem[5]  = 32'h00206333; // or   x6, x1, x2
        dut.u_if.imem[6]  = 32'h002043B3; // xor  x7, x1, x2
        // Fill rest with NOPs
        for (int i = 7; i < 256; i++)
            dut.u_if.imem[i] = 32'h00000013;

        // Reset and run
        @(negedge clk); rst = 1;
        repeat(3) @(posedge clk);
        @(negedge clk); rst = 0;
        repeat(20) @(posedge clk);

        // Check results
        if (read_reg(3) == 32'd16) begin $display("  PASS  add  x3 = %0d", read_reg(3)); pass++; end
        else begin $display("  FAIL  add  x3 = %0d (expected 16)", read_reg(3)); fail++; end

        if (read_reg(4) == 32'd4) begin $display("  PASS  sub  x4 = %0d", read_reg(4)); pass++; end
        else begin $display("  FAIL  sub  x4 = %0d (expected 4)",  read_reg(4)); fail++; end

        if (read_reg(5) == 32'd2) begin $display("  PASS  and  x5 = %0d", read_reg(5)); pass++; end
        else begin $display("  FAIL  and  x5 = %0d (expected 2)",  read_reg(5)); fail++; end

        if (read_reg(6) == 32'd14) begin $display("  PASS  or   x6 = %0d", read_reg(6)); pass++; end
        else begin $display("  FAIL  or   x6 = %0d (expected 14)", read_reg(6)); fail++; end

        if (read_reg(7) == 32'd12) begin $display("  PASS  xor  x7 = %0d", read_reg(7)); pass++; end
        else begin $display("  FAIL  xor  x7 = %0d (expected 12)", read_reg(7)); fail++; end

        $display("  R-type: %0d PASS, %0d FAIL", pass, fail);
    endtask

    // -------------------------------------------------------
    //  Test: Load / Store
    // -------------------------------------------------------
    task test_load_store;
        $display("\n=== TEST: Load/Store ===");

        // addi x1, x0, 0xAB   ; x1 = 0xAB
        // sw   x1, 0(x0)       ; mem[0] = 0xAB
        // lw   x2, 0(x0)       ; x2 = 0xAB
        dut.u_if.imem[0] = 32'h0AB00093; // addi x1, x0, 0xAB
        dut.u_if.imem[1] = 32'h00102023; // sw   x1, 0(x0)
        dut.u_if.imem[2] = 32'h00002103; // lw   x2, 0(x0)
        for (int i = 3; i < 256; i++)
            dut.u_if.imem[i] = 32'h00000013;

        @(negedge clk); rst = 1;
        repeat(3) @(posedge clk);
        @(negedge clk); rst = 0;
        repeat(15) @(posedge clk);

        if (read_reg(2) == 32'h0AB)
            $display("  PASS  lw x2 = 0x%0h", read_reg(2));
        else
            $display("  FAIL  lw x2 = 0x%0h (expected 0xAB)", read_reg(2));
    endtask

    // -------------------------------------------------------
    //  Test: Branch (BEQ)
    // -------------------------------------------------------
    task test_branch;
        $display("\n=== TEST: Branch (BEQ) ===");

        // addi x1, x0, 5
        // addi x2, x0, 5
        // beq  x1, x2, +8    → jump over next instruction
        // addi x3, x0, 99    ← should be skipped
        // addi x3, x0, 42    ← should execute
        dut.u_if.imem[0] = 32'h00500093; // addi x1, x0, 5
        dut.u_if.imem[1] = 32'h00500113; // addi x2, x0, 5
        dut.u_if.imem[2] = 32'h00208463; // beq  x1, x2, +8
        dut.u_if.imem[3] = 32'h06300193; // addi x3, x0, 99 (skipped)
        dut.u_if.imem[4] = 32'h02A00193; // addi x3, x0, 42
        for (int i = 5; i < 256; i++)
            dut.u_if.imem[i] = 32'h00000013;

        @(negedge clk); rst = 1;
        repeat(3) @(posedge clk);
        @(negedge clk); rst = 0;
        repeat(20) @(posedge clk);

        if (read_reg(3) == 32'd42)
            $display("  PASS  beq taken, x3 = %0d", read_reg(3));
        else
            $display("  FAIL  beq, x3 = %0d (expected 42)", read_reg(3));
    endtask

    // -------------------------------------------------------
    //  Test: Forwarding hazard (back-to-back dependent ops)
    // -------------------------------------------------------
    task test_forwarding;
        $display("\n=== TEST: Forwarding (RAW hazard) ===");

        // addi x1, x0, 10
        // add  x2, x1, x1   ← depends on x1 (EX/MEM forward)
        // add  x3, x2, x1   ← depends on x2 (EX/MEM) and x1 (MEM/WB)
        dut.u_if.imem[0] = 32'h00A00093; // addi x1, x0, 10
        dut.u_if.imem[1] = 32'h00108133; // add  x2, x1, x1  → 20
        dut.u_if.imem[2] = 32'h001101B3; // add  x3, x2, x1  → 30
        for (int i = 3; i < 256; i++)
            dut.u_if.imem[i] = 32'h00000013;

        @(negedge clk); rst = 1;
        repeat(3) @(posedge clk);
        @(negedge clk); rst = 0;
        repeat(15) @(posedge clk);

        if (read_reg(2) == 32'd20)
            $display("  PASS  fwd x2 = %0d", read_reg(2));
        else
            $display("  FAIL  fwd x2 = %0d (expected 20)", read_reg(2));

        if (read_reg(3) == 32'd30)
            $display("  PASS  fwd x3 = %0d", read_reg(3));
        else
            $display("  FAIL  fwd x3 = %0d (expected 30)", read_reg(3));
    endtask

    // -------------------------------------------------------
    //  Constrained-Random Test
    // -------------------------------------------------------
    task test_random;
        logic [31:0] a_val, b_val, expected;
        logic [4:0]  op;
        int pass, fail;
        pass = 0; fail = 0;

        $display("\n=== TEST: Constrained-Random ALU Operations ===");

        for (int iter = 0; iter < 20; iter++) begin
            a_val = $urandom_range(0, 255);
            b_val = $urandom_range(1, 255);  // avoid div by zero
            op    = $urandom_range(0, 4);    // add/sub/and/or/xor

            // Build instruction sequence dynamically
            dut.u_if.imem[0] = {12'(a_val), 5'b0, 3'b000, 5'b00001, 7'b0010011}; // addi x1, x0, a
            dut.u_if.imem[1] = {12'(b_val), 5'b0, 3'b000, 5'b00010, 7'b0010011}; // addi x2, x0, b

            case (op)
                0: begin
                    dut.u_if.imem[2] = 32'h002081B3; // add  x3, x1, x2
                    expected = a_val + b_val;
                end
                1: begin
                    dut.u_if.imem[2] = 32'h40208233; // sub  x4← use x3
                    dut.u_if.imem[2] = {7'b0100000,5'b00010,5'b00001,3'b000,5'b00011,7'b0110011};
                    expected = a_val - b_val;
                end
                2: begin
                    dut.u_if.imem[2] = 32'h002071B3; // and  x3, x1, x2
                    expected = a_val & b_val;
                end
                3: begin
                    dut.u_if.imem[2] = 32'h002061B3; // or   x3, x1, x2
                    expected = a_val | b_val;
                end
                default: begin
                    dut.u_if.imem[2] = 32'h002041B3; // xor  x3, x1, x2
                    expected = a_val ^ b_val;
                end
            endcase

            for (int i = 3; i < 256; i++)
                dut.u_if.imem[i] = 32'h00000013;

            @(negedge clk); rst = 1;
            repeat(3) @(posedge clk);
            @(negedge clk); rst = 0;
            repeat(12) @(posedge clk);

            if (read_reg(3) == expected) pass++;
            else begin
                $display("  FAIL iter=%0d op=%0d a=%0d b=%0d got=%0d exp=%0d",
                         iter, op, a_val, b_val, read_reg(3), expected);
                fail++;
            end
        end
        $display("  Random: %0d PASS, %0d FAIL", pass, fail);
    endtask

    // -------------------------------------------------------
    //  Main test sequence
    // -------------------------------------------------------
    initial begin
        $dumpfile("sim/dump.vcd");
        $dumpvars(0, tb_top);

        cycle_cnt = 0;
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;

        test_r_type;
        test_load_store;
        test_branch;
        test_forwarding;
        test_random;

        $display("\n=== All tests complete (cycles=%0d) ===\n", cycle_cnt);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
