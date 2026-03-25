// ============================================================
//  tb_top.sv – Comprehensive RV32I Testbench
//  Coverage: R-type(10 ops), I-type(9 ops), LUI, AUIPC,
//            Loads(LW/LH/LB/LHU/LBU), Stores(SW/SH/SB),
//            Branches(BEQ/BNE/BLT/BGE/BLTU/BGEU taken+not),
//            JAL, JALR, Hazards(fwd/stall/bypass), Loop,
//            Sign-extension, Constrained-random(50 iters)
// ============================================================
`timescale 1ns/1ps

module tb_top;

    logic clk, rst;
    logic [31:0] debug_pc;
    riscv_core dut (.clk(clk), .rst(rst), .debug_pc(debug_pc));

    initial clk = 0;
    always #5 clk = ~clk;

    int total_pass, total_fail, cycle_cnt;
    always @(posedge clk) cycle_cnt <= cycle_cnt + 1;

    function automatic logic [31:0] rr(input int i);
        return dut.u_id.rf.regs[i];
    endfunction

    task automatic do_reset;
        @(negedge clk); rst=1; repeat(3) @(posedge clk);
        @(negedge clk); rst=0;
    endtask

    task automatic fill_nop(input int from);
        for (int i=from; i<256; i++) dut.u_if.imem[i]=32'h00000013;
        for (int i=0; i<256; i++) begin
	    dut.u_mem.dmem_b0[i]=8'h0;
	    dut.u_mem.dmem_b1[i]=8'h0;
	    dut.u_mem.dmem_b2[i]=8'h0;
	    dut.u_mem.dmem_b3[i]=8'h0;
	end
    endtask

    task automatic run(input int n); repeat(n) @(posedge clk); endtask

    task automatic chk(input string name, input logic [31:0] got, exp);
        if (got===exp) begin
            $display("  PASS  %-36s  got=0x%08X", name, got);
            total_pass++;
        end else begin
            $display("  FAIL  %-36s  got=0x%08X  exp=0x%08X", name, got, exp);
            total_fail++;
        end
    endtask

    // =====================================================
    //  TEST 1: R-type – all 10 ops
    // =====================================================
    task test_r_type;
        $display("\n=== TEST 1: R-type (all 10 ops) ===");
        // x1=12, x2=5
        dut.u_if.imem[0]  = 32'h00C00093; // addi x1,x0,12
        dut.u_if.imem[1]  = 32'h00500113; // addi x2,x0,5
        dut.u_if.imem[2]  = 32'h002081B3; // add  x3,x1,x2   = 17
        dut.u_if.imem[3]  = 32'h40208233; // sub  x4,x1,x2   = 7
        dut.u_if.imem[4]  = 32'h002092B3; // sll  x5,x1,x2   = 384
        dut.u_if.imem[5]  = 32'h0020A333; // slt  x6,x1,x2   = 0
        dut.u_if.imem[6]  = 32'h0020B3B3; // sltu x7,x1,x2   = 0
        dut.u_if.imem[7]  = 32'h0020C433; // xor  x8,x1,x2   = 9
        dut.u_if.imem[8]  = 32'h0020D4B3; // srl  x9,x1,x2   = 0
        dut.u_if.imem[9]  = 32'h4020D533; // sra  x10,x1,x2  = 0
        dut.u_if.imem[10] = 32'h0020E5B3; // or   x11,x1,x2  = 13
        dut.u_if.imem[11] = 32'h0020F633; // and  x12,x1,x2  = 4
        fill_nop(12); do_reset; run(28);
        chk("add  12+5=17",   rr(3),  32'd17);
        chk("sub  12-5=7",    rr(4),  32'd7);
        chk("sll  12<<5=384", rr(5),  32'd384);
        chk("slt  12>=5=0",   rr(6),  32'd0);
        chk("sltu 12>=5=0",   rr(7),  32'd0);
        chk("xor  12^5=9",    rr(8),  32'd9);
        chk("srl  12>>5=0",   rr(9),  32'd0);
        chk("sra  12>>>5=0",  rr(10), 32'd0);
        chk("or   12|5=13",   rr(11), 32'd13);
        chk("and  12&5=4",    rr(12), 32'd4);

        // SLT/SLTU signed edge: x1=-1, x2=1
        dut.u_if.imem[0]=32'hFFF00093; // addi x1,x0,-1 -> 0xFFFFFFFF
        dut.u_if.imem[1]=32'h00100113; // addi x2,x0,1
        dut.u_if.imem[2]=32'h0020A333; // slt  x6,x1,x2  = 1  (-1<1 signed)
        dut.u_if.imem[3]=32'h0020B3B3; // sltu x7,x1,x2  = 0  (big >= 1 unsigned)
        fill_nop(4); do_reset; run(18);
        chk("slt  -1<1 (signed)=1",       rr(6), 32'd1);
        chk("sltu 0xFFFFFFFF<1 (unsgn)=0",rr(7), 32'd0);

        // SRA negative: x1=-8, x2=2 -> -2
        dut.u_if.imem[0]=32'hFF800093; // addi x1,x0,-8
        dut.u_if.imem[1]=32'h00200113; // addi x2,x0,2
        dut.u_if.imem[2]=32'h4020D533; // sra  x10,x1,x2 = -2
        fill_nop(3); do_reset; run(15);
        chk("sra  -8>>>2=-2", rr(10), 32'hFFFFFFFE);
    endtask

    // =====================================================
    //  TEST 2: I-type ALU
    // =====================================================
    task test_i_type;
        $display("\n=== TEST 2: I-type ALU (ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI) ===");
        // x1=20
        dut.u_if.imem[0]=32'h01400093; // addi  x1,x0,20
        dut.u_if.imem[1]=32'h00F0A113; // slti  x2,x1,15  = 0
        dut.u_if.imem[2]=32'h00F0B193; // sltiu x3,x1,15  = 0
        dut.u_if.imem[3]=32'h00F0C213; // xori  x4,x1,15  = 27
        dut.u_if.imem[4]=32'h00F0E293; // ori   x5,x1,15  = 31
        dut.u_if.imem[5]=32'h00F0F313; // andi  x6,x1,15  = 4
        dut.u_if.imem[6]=32'h00309393; // slli  x7,x1,3   = 160
        dut.u_if.imem[7]=32'h0020D413; // srli  x8,x1,2   = 5
        dut.u_if.imem[8]=32'h4020D493; // srai  x9,x1,2   = 5
        fill_nop(9); do_reset; run(22);
        chk("addi  x1=20",   rr(1), 32'd20);
        chk("slti  20<15=0", rr(2), 32'd0);
        chk("sltiu 20<15=0", rr(3), 32'd0);
        chk("xori  20^15=27",rr(4), 32'd27);
        chk("ori   20|15=31",rr(5), 32'd31);
        chk("andi  20&15=4", rr(6), 32'd4);
        chk("slli  20<<3=160",rr(7),32'd160);
        chk("srli  20>>2=5", rr(8), 32'd5);
        chk("srai  20>>>2=5",rr(9), 32'd5);

        // Negative immediate sign extension
        dut.u_if.imem[0]=32'hFFF00093; // addi x1,x0,-1
        dut.u_if.imem[1]=32'hFD600113; // addi x2,x0,-42
        fill_nop(2); do_reset; run(12);
        chk("addi -1  =0xFFFFFFFF", rr(1), 32'hFFFFFFFF);
        chk("addi -42 =0xFFFFFFD6", rr(2), 32'hFFFFFFD6);

        // SRAI propagates sign: -16 >>> 2 = -4
        dut.u_if.imem[0]=32'hFF000093; // addi x1,x0,-16
        dut.u_if.imem[1]=32'h4020D093; // srai x1,x1,2   = -4
        fill_nop(2); do_reset; run(12);
        chk("srai -16>>>2=-4", rr(1), 32'hFFFFFFFC);
    endtask

    // =====================================================
    //  TEST 3: LUI / AUIPC
    // =====================================================
    task test_lui_auipc;
        $display("\n=== TEST 3: LUI / AUIPC ===");
        dut.u_if.imem[0]=32'h123450B7; // lui   x1,0x12345   = 0x12345000
        dut.u_if.imem[1]=32'h00001117; // auipc x2,1  (at addr 4) = 4+0x1000 = 0x1004
        fill_nop(2); do_reset; run(12);
        chk("lui   0x12345000", rr(1), 32'h12345000);
        chk("auipc pc4+0x1000", rr(2), 32'h00001004);
    endtask

    // =====================================================
    //  TEST 4: Loads and Stores
    // =====================================================
    task test_load_store;
        $display("\n=== TEST 4: Loads and Stores ===");

        // SW + LW (full word)
        dut.u_if.imem[0]=32'h12345137; // lui  x2,0x12345
        dut.u_if.imem[1]=32'h67810113; // addi x2,x2,0x678  -> x2=0x12345678
        dut.u_if.imem[2]=32'h00202023; // sw   x2,0(x0)
        dut.u_if.imem[3]=32'h00002183; // lw   x3,0(x0)
        fill_nop(4); do_reset; run(18);
        chk("sw+lw 0x12345678", rr(3), 32'h12345678);

        // SH + LH  (halfword, positive -> no sign-ext)
        dut.u_if.imem[0]=32'h23400093; // addi x1,x0,0x234 = 564
        // addi only 12-bit: 0x234 = 564 ok, fits
        dut.u_if.imem[1]=32'h00101223; // sh   x1,4(x0)
        dut.u_if.imem[2]=32'h00401183; // lh   x3,4(x0)   -> sign-ext 0x0234
        fill_nop(3); do_reset; run(18);
        chk("sh+lh  0x234", rr(3), 32'h00000234);

        // SH + LH (negative, sign-extended)
        dut.u_if.imem[0]=32'hFFF00093; // addi x1,x0,-1  -> 0xFFFFFFFF
        dut.u_if.imem[1]=32'h00101223; // sh   x1,4(x0)  -> stores 0xFFFF
        dut.u_if.imem[2]=32'h00401183; // lh   x3,4(x0)  -> sign-ext -> 0xFFFFFFFF
        dut.u_if.imem[3]=32'h00405283; // lhu  x5,4(x0)  -> zero-ext -> 0x0000FFFF
        fill_nop(4); do_reset; run(20);
        chk("lh  sign-ext 0xFFFFFFFF", rr(3), 32'hFFFFFFFF);
        chk("lhu zero-ext 0x0000FFFF", rr(5), 32'h0000FFFF);

        // SB + LB + LBU (positive byte 0xAB)
        dut.u_if.imem[0]=32'h0AB00093; // addi x1,x0,0xAB
        dut.u_if.imem[1]=32'h00100423; // sb   x1,8(x0)
        dut.u_if.imem[2]=32'h00800203; // lb   x4,8(x0)  -> 0xAB (no sign-ext, bit7=1 -> actually signed!)
        dut.u_if.imem[3]=32'h00804303; // lbu  x6,8(x0)  -> 0x000000AB
        fill_nop(4); do_reset; run(20);
        // 0xAB = 171 = 0b10101011, bit7=1 so LB sign-extends to 0xFFFFFFAB
        chk("lb  sign-ext 0xAB -> neg", rr(4), 32'hFFFFFFAB);
        chk("lbu zero-ext 0xAB",        rr(6), 32'h000000AB);

        // SB + LB positive byte (0x7F, bit7=0)
        dut.u_if.imem[0]=32'h07F00093; // addi x1,x0,0x7F
        dut.u_if.imem[1]=32'h00100423; // sb   x1,8(x0)
        dut.u_if.imem[2]=32'h00800203; // lb   x4,8(x0)  -> +127
        fill_nop(3); do_reset; run(18);
        chk("lb  positive 0x7F=127", rr(4), 32'h0000007F);
    endtask

    // =====================================================
    //  TEST 5: All 6 branches (taken + not-taken)
    // =====================================================
    task test_branches;
        $display("\n=== TEST 5: Branches (all 6 types, taken + not-taken) ===");
        // Pattern: branch at imem[2] skips poison at imem[3], lands imem[4]=addi x3,x0,1
        //          if not-taken, imem[3]=addi x3,x0,99

        // BEQ taken (5==5)
        dut.u_if.imem[0]=32'h00500093; dut.u_if.imem[1]=32'h00500113;
        dut.u_if.imem[2]=32'h00208463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00100193;
        fill_nop(5); do_reset; run(20);
        chk("beq taken    x3=1",  rr(3), 32'd1);

        // BEQ not-taken (5!=6)
        dut.u_if.imem[0]=32'h00500093; dut.u_if.imem[1]=32'h00600113;
        dut.u_if.imem[2]=32'h00208463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00000013;
        fill_nop(5); do_reset; run(20);
        chk("beq not-taken x3=99",rr(3), 32'd99);

        // BNE taken (5!=6)
        dut.u_if.imem[0]=32'h00500093; dut.u_if.imem[1]=32'h00600113;
        dut.u_if.imem[2]=32'h00209463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00100193;
        fill_nop(5); do_reset; run(20);
        chk("bne taken    x3=1",  rr(3), 32'd1);

        // BNE not-taken (5==5)
        dut.u_if.imem[0]=32'h00500093; dut.u_if.imem[1]=32'h00500113;
        dut.u_if.imem[2]=32'h00209463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00000013;
        fill_nop(5); do_reset; run(20);
        chk("bne not-taken x3=99",rr(3), 32'd99);

        // BLT taken (3<7)
        dut.u_if.imem[0]=32'h00300093; dut.u_if.imem[1]=32'h00700113;
        dut.u_if.imem[2]=32'h0020C463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00100193;
        fill_nop(5); do_reset; run(20);
        chk("blt taken    x3=1",  rr(3), 32'd1);

        // BLT not-taken (7>=3)
        dut.u_if.imem[0]=32'h00700093; dut.u_if.imem[1]=32'h00300113;
        dut.u_if.imem[2]=32'h0020C463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00000013;
        fill_nop(5); do_reset; run(20);
        chk("blt not-taken x3=99",rr(3), 32'd99);

        // BLT signed -1<1 taken
        dut.u_if.imem[0]=32'hFFF00093; dut.u_if.imem[1]=32'h00100113;
        dut.u_if.imem[2]=32'h0020C463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00100193;
        fill_nop(5); do_reset; run(20);
        chk("blt signed -1<1 x3=1",rr(3), 32'd1);

        // BGE taken (7>=3)
        dut.u_if.imem[0]=32'h00700093; dut.u_if.imem[1]=32'h00300113;
        dut.u_if.imem[2]=32'h0020D463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00100193;
        fill_nop(5); do_reset; run(20);
        chk("bge taken    x3=1",  rr(3), 32'd1);

        // BGE not-taken (3<7)
        dut.u_if.imem[0]=32'h00300093; dut.u_if.imem[1]=32'h00700113;
        dut.u_if.imem[2]=32'h0020D463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00000013;
        fill_nop(5); do_reset; run(20);
        chk("bge not-taken x3=99",rr(3), 32'd99);

        // BLTU taken: 1 < 0xFFFFFFFF
        dut.u_if.imem[0]=32'h00100093; dut.u_if.imem[1]=32'hFFF00113;
        dut.u_if.imem[2]=32'h0020E463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00100193;
        fill_nop(5); do_reset; run(20);
        chk("bltu 1<0xFFFF.. x3=1",rr(3), 32'd1);

        // BLTU not-taken: 0xFFFFFFFF >= 1
        dut.u_if.imem[0]=32'hFFF00093; dut.u_if.imem[1]=32'h00100113;
        dut.u_if.imem[2]=32'h0020E463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00000013;
        fill_nop(5); do_reset; run(20);
        chk("bltu not-taken x3=99",rr(3), 32'd99);

        // BGEU taken: 0xFFFFFFFF >= 1
        dut.u_if.imem[0]=32'hFFF00093; dut.u_if.imem[1]=32'h00100113;
        dut.u_if.imem[2]=32'h0020F463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00100193;
        fill_nop(5); do_reset; run(20);
        chk("bgeu 0xFFFF..>=1 x3=1",rr(3), 32'd1);

        // BGEU not-taken: 1 < 0xFFFFFFFF
        dut.u_if.imem[0]=32'h00100093; dut.u_if.imem[1]=32'hFFF00113;
        dut.u_if.imem[2]=32'h0020F463; dut.u_if.imem[3]=32'h06300193; dut.u_if.imem[4]=32'h00000013;
        fill_nop(5); do_reset; run(20);
        chk("bgeu not-taken x3=99",rr(3), 32'd99);
    endtask

    // =====================================================
    //  TEST 6: JAL
    // =====================================================
    task test_jal;
        $display("\n=== TEST 6: JAL ===");
        // jal x1,+8 at addr 8 -> target=16, ra=12
        dut.u_if.imem[0]=32'h00000013; // nop (addr 0)
        dut.u_if.imem[1]=32'h00000013; // nop (addr 4)
        dut.u_if.imem[2]=32'h008000EF; // jal x1,+8   (addr 8, target=16, ra=12)
        dut.u_if.imem[3]=32'h06300193; // poison addi x3,x0,99 (addr 12, skipped)
        dut.u_if.imem[4]=32'h00100193; // addi x3,x0,1  (addr 16, target)
        fill_nop(5); do_reset; run(22);
        chk("jal  target reached x3=1",  rr(3), 32'd1);
        chk("jal  PC+4 saved  x1=12",    rr(1), 32'd12);
    endtask

    // =====================================================
    //  TEST 7: JALR
    // =====================================================
    task test_jalr;
        $display("\n=== TEST 7: JALR ===");
        // jalr x3,0(x1) at addr 8, x1=20 -> target=20, ra=12
        dut.u_if.imem[0]=32'h01400093; // addi x1,x0,20   (addr 0)
        dut.u_if.imem[1]=32'h00000013; // nop              (addr 4)
        dut.u_if.imem[2]=32'h000081E7; // jalr x3,0(x1)   (addr 8, target=20, ra=12)
        dut.u_if.imem[3]=32'h06300213; // poison x4=99     (addr 12)
        dut.u_if.imem[4]=32'h06300213; // poison x4=99     (addr 16)
        dut.u_if.imem[5]=32'h00100213; // addi x4,x0,1    (addr 20, target)
        fill_nop(6); do_reset; run(22);
        chk("jalr target reached x4=1", rr(4), 32'd1);
        chk("jalr PC+4 saved  x3=12",   rr(3), 32'd12);

        // JALR with offset: base=16, offset=4 -> target=20
        dut.u_if.imem[0]=32'h01000093; // addi x1,x0,16
        dut.u_if.imem[1]=32'h00000013;
        dut.u_if.imem[2]=32'h004081E7; // jalr x3,4(x1)  -> target=20
        dut.u_if.imem[3]=32'h06300213; // poison
        dut.u_if.imem[4]=32'h06300213; // poison
        dut.u_if.imem[5]=32'h00200213; // addi x4,x0,2   (addr 20)
        fill_nop(6); do_reset; run(22);
        chk("jalr+offset x4=2", rr(4), 32'd2);
    endtask

    // =====================================================
    //  TEST 8: Data Hazards
    // =====================================================
    task test_hazards;
        $display("\n=== TEST 8: Data Hazards ===");

        // EX/MEM forward (1-cycle gap)
        dut.u_if.imem[0]=32'h00A00093; // addi x1,x0,10
        dut.u_if.imem[1]=32'h00108133; // add  x2,x1,x1  -> 20 (x1 fwd EX/MEM)
        dut.u_if.imem[2]=32'h001101B3; // add  x3,x2,x1  -> 30 (x2 EX/MEM, x1 MEM/WB)
        fill_nop(3); do_reset; run(16);
        chk("EX/MEM fwd x2=20", rr(2), 32'd20);
        chk("MEM/WB fwd x3=30", rr(3), 32'd30);

        // MEM/WB forward (2-cycle gap)
        dut.u_if.imem[0]=32'h00500093; // addi x1,x0,5
        dut.u_if.imem[1]=32'h00000013; // nop
        dut.u_if.imem[2]=32'h00108133; // add  x2,x1,x1  -> 10 (x1 MEM/WB)
        fill_nop(3); do_reset; run(16);
        chk("MEM/WB 2-gap fwd x2=10", rr(2), 32'd10);

        // WB->ID write-through (3-cycle gap)
        dut.u_if.imem[0]=32'h00A00093; // addi x1,x0,10
        dut.u_if.imem[1]=32'h00000013; // nop
        dut.u_if.imem[2]=32'h00000013; // nop
        dut.u_if.imem[3]=32'h00108133; // add  x2,x1,x1  -> 20 (x1 from RF bypass)
        fill_nop(4); do_reset; run(18);
        chk("WB->ID bypass x2=20", rr(2), 32'd20);

        // Load-use stall
        dut.u_if.imem[0]=32'h00A00093; // addi x1,x0,10
        dut.u_if.imem[1]=32'h00102023; // sw   x1,0(x0)
        dut.u_if.imem[2]=32'h00002103; // lw   x2,0(x0)
        dut.u_if.imem[3]=32'h00210133; // add  x2,x2,x2  -> 20 (stall required)
        fill_nop(4); do_reset; run(22);
        chk("load-use stall x2=20", rr(2), 32'd20);

        // Chain: lw -> immediate use (deepest stall test)
        dut.u_if.imem[0]=32'h00500093; // addi x1,x0,5
        dut.u_if.imem[1]=32'h00102023; // sw   x1,0(x0)
        dut.u_if.imem[2]=32'h00002103; // lw   x2,0(x0)
        dut.u_if.imem[3]=32'h00210133; // add  x2,x2,x2  -> 10 (stall)
        dut.u_if.imem[4]=32'h00210133; // add  x2,x2,x2  -> 20
        fill_nop(5); do_reset; run(25);
        chk("load-use chain x2=20", rr(2), 32'd20);
    endtask

    // =====================================================
    //  TEST 9: Loops
    // =====================================================
    task test_loops;
        $display("\n=== TEST 9: Loops ===");

        // Count to 5 with BLT
        dut.u_if.imem[0]=32'h00000093; // addi x1,x0,0
        dut.u_if.imem[1]=32'h00500113; // addi x2,x0,5
        dut.u_if.imem[2]=32'h00108093; // addi x1,x1,1   <- loop (addr 8)
        dut.u_if.imem[3]=32'hFE20CEE3; // blt  x1,x2,-4  (back to addr 8)
        fill_nop(4); do_reset; run(60);
        chk("loop count=5", rr(1), 32'd5);

        // Sum 1+2+...+10 = 55
        dut.u_if.imem[0]=32'h00100093; // addi x1,x0,1    i=1    (addr 0)
        dut.u_if.imem[1]=32'h00B00113; // addi x2,x0,11   limit=11
        dut.u_if.imem[2]=32'h00000193; // addi x3,x0,0    sum=0
        dut.u_if.imem[3]=32'h001181B3; // add  x3,x3,x1   <- loop (addr 12)
        dut.u_if.imem[4]=32'h00108093; // addi x1,x1,1
        dut.u_if.imem[5]=32'hFE20CCE3; // blt  x1,x2,-8  (addr 20 -> addr 12)
        fill_nop(6); do_reset; run(120);
        chk("sum 1..10=55", rr(3), 32'd55);
    endtask

    // =====================================================
    //  TEST 10: Constrained-Random (full 32-bit ALU, 50 iters)
    // =====================================================
    task test_random;
        logic [31:0] a,b,exp;
        logic [3:0]  op;
        logic [31:0] ua, la, ub, lb;
        int pass,fail;
        pass=0; fail=0;
        $display("\n=== TEST 10: Constrained-Random ALU (50 iters, full 32-bit) ===");

        for (int it=0; it<50; it++) begin
            a  = $urandom();
            b  = $urandom();
            op = $urandom_range(0,9);

            // Build LUI+ADDI pair to load full 32-bit value into x1
            // LUI loads upper 20 bits; ADDI adds sign-extended lower 12 bits.
            // If lower 12 bits have bit11=1, ADDI sign-extends negative -> compensate upper.
            ua = a[11] ? (a[31:12]+1) : a[31:12];
            la = a[11:0];
            dut.u_if.imem[0] = (ua<<12)|(5'b00001<<7)|7'b0110111; // lui  x1,ua
            dut.u_if.imem[1] = (la<<20)|(5'b00001<<15)|(5'b00001<<7)|7'b0010011; // addi x1,x1,la

            ub = b[11] ? (b[31:12]+1) : b[31:12];
            lb = b[11:0];
            dut.u_if.imem[2] = (ub<<12)|(5'b00010<<7)|7'b0110111; // lui  x2,ub
            dut.u_if.imem[3] = (lb<<20)|(5'b00010<<15)|(5'b00010<<7)|7'b0010011; // addi x2,x2,lb

            case (op)
                0: begin dut.u_if.imem[4]=32'h002081B3; exp=a+b;                       end //add
                1: begin dut.u_if.imem[4]={7'b0100000,5'd2,5'd1,3'd0,5'd3,7'b0110011}; exp=a-b; end //sub
                2: begin dut.u_if.imem[4]=32'h0020F1B3; exp=a&b;                       end //and
                3: begin dut.u_if.imem[4]=32'h0020E1B3; exp=a|b;                       end //or
                4: begin dut.u_if.imem[4]=32'h0020C1B3; exp=a^b;                       end //xor
                5: begin dut.u_if.imem[4]=32'h002091B3; exp=a<<b[4:0];                 end //sll
                6: begin dut.u_if.imem[4]=32'h0020D1B3; exp=a>>b[4:0];                 end //srl
                7: begin dut.u_if.imem[4]=32'h4020D1B3; exp=$signed(a)>>>b[4:0];       end //sra
                8: begin dut.u_if.imem[4]=32'h0020A1B3; exp=($signed(a)<$signed(b))?1:0; end //slt
                9: begin dut.u_if.imem[4]=32'h0020B1B3; exp=(a<b)?1:0;                 end //sltu
            endcase

            // op=0 add writes x3 (imem[4]=002081B3 -> rd=x3) ✓
            // op=1 sub: custom encoding writes x3 ✓
            fill_nop(5); do_reset; run(18);

            if (rr(3)===exp) pass++;
            else begin
                $display("  FAIL it=%0d op=%0d a=0x%08X b=0x%08X got=0x%08X exp=0x%08X",
                         it, op, a, b, rr(3), exp);
                fail++;
            end
        end
        $display("  Random: %0d PASS, %0d FAIL", pass, fail);
        total_pass+=pass; total_fail+=fail;
    endtask

    // =====================================================
    //  Main
    // =====================================================
    initial begin
        $dumpfile("sim/dump.vcd");
        $dumpvars(0, tb_top);
        
        // Reset the processor
        rst=1; 
        repeat(5) @(posedge clk); 
        rst=0;

        // Run for enough cycles to complete program.hex
        $display("Running program.hex...");
        run(200); 

        // Print final register states to verify program.hex execution
        $display("\n=== Final Register States ===");
        $display("x1  (10)      = %0d", rr(1));
        $display("x2  (6)       = %0d", rr(2));
        $display("x3  (x1+x2)   = %0d", rr(3));
        $display("x14 (0xFFFFFABC) = 0x%08X", rr(14));
        $display("x17 (Loop)    = %0d", rr(17));
        $display("x20 (Func)    = %0d", rr(20));
        
        $display("\nSimulation complete.");
        $finish;
    end

    initial begin #1000000; $display("TIMEOUT"); $finish; end

endmodule