// =============================================================================
// RISC-V Comprehensive Testbench
// =============================================================================
// Complete test suite covering all RV32I instruction categories:
// 1. Basic ALU Operations (ADD, SUB, AND, OR, XOR)
// 2. Shift Operations (SLL, SRL, SRA, SLLI, SRLI, SRAI)
// 3. Comparison Operations (SLT, SLTU, SLTI, SLTIU)
// 4. Load/Store Operations (LW, SW, LH, LHU, SH, LB, LBU, SB)
// 5. Branch Instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
// 6. Jump Instructions (JAL, JALR)
// 7. Upper Immediate Operations (LUI, AUIPC)
// 8. Edge Cases (x0 behavior, overflow, max values)
// 9. Sequential Program Flow
// 10. Memory Aliasing & Data Hazards
// =============================================================================

module tb_riscv_comprehensive;

    // =========================================================================
    // Testbench Signals
    // =========================================================================
    
    logic        clock;
    logic        reset;
    logic [31:0] pc;
    logic [2:0]  state;
    logic [31:0] debug_reg_x1;
    logic [31:0] debug_reg_x2;
    
    // Test control
    int          cycle_count;
    int          test_errors;
    string       current_test;
    
    // =========================================================================
    // Clock Generation
    // =========================================================================
    
    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock;  // 10ns period = 100MHz
    end
    
    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    
    riscv_soc #(
        .IMEM_SIZE(8192),     // Larger memory for comprehensive tests
        .DMEM_SIZE(8192),
        .LOAD_PROGRAM(0)      // Disable built-in program, testbench loads its own
    ) u_dut (
        .clock           (clock),
        .reset           (reset),
        .pc_o            (pc),
        .state_o         (state),
        .debug_reg_x1_o  (debug_reg_x1),
        .debug_reg_x2_o  (debug_reg_x2)
    );
    
    // =========================================================================
    // Register File Access
    // =========================================================================
    
    logic [31:0] reg_file [31:0];
    
    always_comb begin
        for (int i = 0; i < 32; i++) begin
            reg_file[i] = u_dut.u_cpu.u_regfile.registers[i];
        end
    end
    
    // =========================================================================
    // Data Memory Access (for verification)
    // =========================================================================
    
    function logic [31:0] read_dmem(logic [31:0] addr);
        return u_dut.dmem[addr[15:2]];
    endfunction
    
    // =========================================================================
    // Test Program Loading
    // =========================================================================
    
    initial begin
        // Wait for module initialization to complete
        #1;
        // Load comprehensive test program into instruction memory
        load_test_program();
    end
    
    task load_test_program();
        // Initialize all memory to NOP (ADDI x0, x0, 0)
        for (int i = 0; i < 2048; i++) begin
            u_dut.imem[i] = 32'h00000013;
        end
        
        // =====================================================================
        // TEST CATEGORY 1: Basic ALU Operations (already tested, but include for completeness)
        // =====================================================================
        // PC 0x00: ADDI x1, x0, 10
        u_dut.imem[0] = 32'h00A00093;
        // PC 0x04: ADDI x2, x0, 20
        u_dut.imem[1] = 32'h01400113;
        // PC 0x08: ADD x3, x1, x2  (x3 = 30)
        u_dut.imem[2] = 32'h002081B3;
        // PC 0x0C: SUB x4, x1, x2  (x4 = -10)
        u_dut.imem[3] = 32'h40208233;
        // PC 0x10: AND x5, x1, x2  (x5 = 0)
        u_dut.imem[4] = 32'h0020F2B3;
        // PC 0x14: OR x6, x1, x2   (x6 = 30)
        u_dut.imem[5] = 32'h0020E333;
        // PC 0x18: XOR x7, x1, x2  (x7 = 30)
        u_dut.imem[6] = 32'h0020C3B3;
        
        // =====================================================================
        // TEST CATEGORY 2: Shift Operations
        // =====================================================================
        // PC 0x1C: ADDI x8, x0, 1
        u_dut.imem[7] = 32'h00100413;
        // PC 0x20: SLLI x9, x8, 4  (x9 = 16, shift left by 4)
        u_dut.imem[8] = 32'h00441493;
        // PC 0x24: ADDI x10, x0, 3
        u_dut.imem[9] = 32'h00300513;
        // PC 0x28: SLL x11, x8, x10  (x11 = 8, shift left by 3)
        u_dut.imem[10] = 32'h00A415B3;
        // PC 0x2C: ADDI x12, x0, -1  (x12 = 0xFFFFFFFF)
        u_dut.imem[11] = 32'hFFF00613;
        // PC 0x30: SRLI x13, x12, 4  (x13 = 0x0FFFFFFF)
        u_dut.imem[12] = 32'h00465693;
        // PC 0x34: SRL x14, x12, x10  (x14 = 0x1FFFFFFF, shift right by 3)
        u_dut.imem[13] = 32'h00A65733;
        // PC 0x38: ADDI x15, x0, -8  (x15 = 0xFFFFFFF8)
        u_dut.imem[14] = 32'hFF800793;
        // PC 0x3C: SRAI x16, x15, 2  (x16 = 0xFFFFFFFE, arithmetic shift)
        u_dut.imem[15] = 32'h4027D813;
        // PC 0x40: SRA x17, x15, x10  (x17 = 0xFFFFFFFF)
        u_dut.imem[16] = 32'h40A7D8B3;
        
        // =====================================================================
        // TEST CATEGORY 3: Comparison Operations
        // =====================================================================
        // PC 0x44: ADDI x18, x0, -5  (x18 = -5)
        u_dut.imem[17] = 32'hFFB00913;
        // PC 0x48: ADDI x19, x0, 3   (x19 = 3)
        u_dut.imem[18] = 32'h00300993;
        // PC 0x4C: SLT x20, x18, x19  (x20 = 1, -5 < 3 signed)
        u_dut.imem[19] = 32'h01392A33;
        // PC 0x50: SLT x21, x19, x18  (x21 = 0, 3 > -5 signed)
        u_dut.imem[20] = 32'h0129AAB3;
        // PC 0x54: SLTU x22, x18, x19  (x22 = 0, 0xFFFFFFFB > 3 unsigned)
        u_dut.imem[21] = 32'h01393B33;
        // PC 0x58: SLTU x23, x19, x18  (x23 = 1, 3 < 0xFFFFFFFB unsigned)
        u_dut.imem[22] = 32'h0129BBB3;
        // PC 0x5C: SLTI x24, x18, 0  (x24 = 1, -5 < 0)
        u_dut.imem[23] = 32'h00092C13;
        // PC 0x60: SLTIU x25, x18, 10  (x25 = 0, 0xFFFFFFFB > 10 unsigned)
        u_dut.imem[24] = 32'h00A93C93;
        
        // =====================================================================
        // TEST CATEGORY 4: Load/Store Operations
        // =====================================================================
        // Setup base address in x26 = 0x100
        // PC 0x64: ADDI x26, x0, 256
        u_dut.imem[25] = 32'h10000D13;
        
        // Test SW/LW (word operations)
        // PC 0x68: ADDI x27, x0, 0x5A  (x27 = 0x5A)
        u_dut.imem[26] = 32'h05A00D93;
        // PC 0x6C: SW x27, 0(x26)  (Store 0x5A to address 0x100)
        u_dut.imem[27] = 32'h01BD2023;
        // PC 0x70: LW x28, 0(x26)  (Load from 0x100, x28 = 0x5A)
        u_dut.imem[28] = 32'h000D2E03;
        
        // Test SH/LH (halfword operations)
        // PC 0x74: ADDI x29, x0, -1  (x29 = 0xFFFFFFFF)
        u_dut.imem[29] = 32'hFFF00E93;
        // PC 0x78: SH x29, 4(x26)  (Store halfword 0xFFFF to 0x104)
        u_dut.imem[30] = 32'h01DD1223;
        // PC 0x7C: LH x30, 4(x26)  (Load signed halfword, x30 = 0xFFFFFFFF)
        u_dut.imem[31] = 32'h004D1F03;
        // PC 0x80: LHU x31, 4(x26)  (Load unsigned halfword, x31 = 0x0000FFFF)
        u_dut.imem[32] = 32'h004D5F83;
        
        // Test SB/LB (byte operations)
        // PC 0x84: ADDI x1, x0, -2  (x1 = 0xFFFFFFFE)
        u_dut.imem[33] = 32'hFFE00093;
        // PC 0x88: SB x1, 8(x26)  (Store byte 0xFE to 0x108)
        u_dut.imem[34] = 32'h001D0423;
        // PC 0x8C: LB x2, 8(x26)  (Load signed byte, x2 = 0xFFFFFFFE)
        u_dut.imem[35] = 32'h008D0103;
        // PC 0x90: LBU x3, 8(x26)  (Load unsigned byte, x3 = 0x000000FE)
        u_dut.imem[36] = 32'h008D4183;
        
        // =====================================================================
        // TEST CATEGORY 5: Branch Instructions
        // =====================================================================
        // Setup test values
        // PC 0x94: ADDI x4, x0, 5
        u_dut.imem[37] = 32'h00500213;
        // PC 0x98: ADDI x5, x0, 5
        u_dut.imem[38] = 32'h00500293;
        
        // BEQ test (should branch)
        // PC 0x9C: BEQ x4, x5, +8  (branch to PC + 8 = 0xA4)
        u_dut.imem[39] = 32'h00520463;
        // PC 0xA0: ADDI x6, x0, 99  (should be skipped)
        u_dut.imem[40] = 32'h06300313;
        
        // Branch target (PC 0xA4)
        // PC 0xA4: ADDI x7, x0, 10  (x7 = 10, confirms branch taken)
        u_dut.imem[41] = 32'h00A00393;
        
        // BNE test (should not branch)
        // PC 0xA8: BNE x4, x5, +8  (should not branch)
        u_dut.imem[42] = 32'h00521463;
        // PC 0xAC: ADDI x8, x0, 20  (x8 = 20, should execute)
        u_dut.imem[43] = 32'h01400413;
        
        // BLT test (signed comparison)
        // PC 0xB0: ADDI x9, x0, -1  (x9 = -1)
        u_dut.imem[44] = 32'hFFF00493;
        // PC 0xB4: ADDI x10, x0, 1  (x10 = 1)
        u_dut.imem[45] = 32'h00100513;
        // PC 0xB8: BLT x9, x10, +8  (branch, -1 < 1)
        u_dut.imem[46] = 32'h00A4C463;
        // PC 0xBC: ADDI x11, x0, 99  (should be skipped)
        u_dut.imem[47] = 32'h06300593;
        
        // Branch target (PC 0xC0)
        // PC 0xC0: ADDI x12, x0, 30  (x12 = 30)
        u_dut.imem[48] = 32'h01E00613;
        
        // BGE test (signed comparison, should not branch)
        // PC 0xC4: BGE x9, x10, +8  (should not branch, -1 >= 1 is false)
        u_dut.imem[49] = 32'h00A4D463;
        // PC 0xC8: ADDI x13, x0, 40  (x13 = 40, should execute)
        u_dut.imem[50] = 32'h02800693;
        
        // BLTU test (unsigned comparison, should branch)
        // PC 0xCC: BLTU x10, x9, +8  (branch, 1 < 0xFFFFFFFF unsigned)
        u_dut.imem[51] = 32'h00956463;
        // PC 0xD0: ADDI x14, x0, 99  (should be skipped)
        u_dut.imem[52] = 32'h06300713;
        
        // Branch target (PC 0xD4)
        // PC 0xD4: ADDI x15, x0, 50  (x15 = 50)
        u_dut.imem[53] = 32'h03200793;
        
        // BGEU test (unsigned comparison, should not branch)
        // PC 0xD8: BGEU x10, x9, +8  (should not branch)
        u_dut.imem[54] = 32'h00957463;
        // PC 0xDC: ADDI x16, x0, 60  (x16 = 60, should execute)
        u_dut.imem[55] = 32'h03C00813;
        
        // =====================================================================
        // TEST CATEGORY 6: Jump Instructions
        // =====================================================================
        // JAL test
        // PC 0xE0: JAL x17, +16  (jump to PC + 16 = 0xF0, x17 = 0xE4)
        u_dut.imem[56] = 32'h010008EF;
        // PC 0xE4: ADDI x18, x0, 99  (should be skipped)
        u_dut.imem[57] = 32'h06300913;
        
        // More instructions that should be skipped
        // PC 0xE8: NOP
        u_dut.imem[58] = 32'h00000013;
        // PC 0xEC: NOP
        u_dut.imem[59] = 32'h00000013;
        
        // Jump target (PC 0xF0)
        // PC 0xF0: ADDI x19, x0, 70  (x19 = 70, confirms jump)
        u_dut.imem[60] = 32'h04600993;
        
        // JALR test (function call/return pattern)
        // PC 0xF4: ADDI x20, x0, 0x110  (x20 = target address 0x110)
        u_dut.imem[61] = 32'h11000A13;
        // PC 0xF8: JALR x21, x20, 0  (jump to address in x20, x21 = 0xFC)
        u_dut.imem[62] = 32'h000A0AE7;
        // PC 0xFC: ADDI x22, x0, 99  (should be skipped)
        u_dut.imem[63] = 32'h06300B13;
        
        // Fill gap
        for (int i = 64; i < 68; i++) begin
            u_dut.imem[i] = 32'h00000013;  // NOP
        end
        
        // Jump target (PC 0x110)
        // PC 0x110: ADDI x23, x0, 80  (x23 = 80)
        u_dut.imem[68] = 32'h05000B93;
        // PC 0x114: JALR x0, x21, 0  (return to x21, no return address saved)
        u_dut.imem[69] = 32'h000A8067;
        
        // After return (PC 0xFC next, but we skipped that, so 0x100)
        // PC 0x100: ADDI x24, x0, 90  (x24 = 90)
        u_dut.imem[64] = 32'h05A00C13;
        
        // =====================================================================
        // TEST CATEGORY 7: Upper Immediate Operations
        // =====================================================================
        // LUI test
        // PC 0x104: LUI x25, 0x12345  (x25 = 0x12345000)
        u_dut.imem[65] = 32'h12345CB7;
        // PC 0x108: ADDI x25, x25, 0x678  (x25 = 0x12345678)
        u_dut.imem[66] = 32'h678C8C93;
        
        // AUIPC test
        // PC 0x10C: AUIPC x26, 0x1  (x26 = PC + 0x1000 = 0x110C)
        u_dut.imem[67] = 32'h00001D17;
        
        // =====================================================================
        // TEST CATEGORY 8: Edge Cases
        // =====================================================================
        // x0 always zero test
        // PC 0x118: ADDI x0, x0, 123  (try to write to x0)
        u_dut.imem[70] = 32'h07B00013;
        // PC 0x11C: ADD x27, x0, x0  (x27 = 0, x0 always zero)
        u_dut.imem[71] = 32'h00000DB3;
        
        // Overflow test
        // PC 0x120: ADDI x28, x0, -1  (x28 = 0xFFFFFFFF)
        u_dut.imem[72] = 32'hFFF00E13;
        // PC 0x124: ADDI x29, x28, 1  (x29 = 0, overflow wraps)
        u_dut.imem[73] = 32'h001E0E93;
        
        // Max values
        // PC 0x128: LUI x30, 0x80000  (x30 = 0x80000000, most negative)
        u_dut.imem[74] = 32'h80000F37;
        // PC 0x12C: ADDI x31, x0, -1
        u_dut.imem[75] = 32'hFFF00F93;
        // PC 0x130: SRLI x31, x31, 1  (x31 = 0x7FFFFFFF, most positive)
        u_dut.imem[76] = 32'h001FDF93;
        
        // =====================================================================
        // TEST CATEGORY 9: Sequential Program Flow
        // =====================================================================
        // PC 0x134: ADDI x1, x0, 1
        u_dut.imem[77] = 32'h00100093;
        // PC 0x138: ADDI x2, x1, 2
        u_dut.imem[78] = 32'h00208113;
        // PC 0x13C: ADDI x3, x2, 3
        u_dut.imem[79] = 32'h00310193;
        // PC 0x140: ADDI x4, x3, 4
        u_dut.imem[80] = 32'h00418213;
        
        // =====================================================================
        // TEST CATEGORY 10: Memory Aliasing & Data Hazards
        // =====================================================================
        // RAW (Read After Write) hazard
        // PC 0x144: ADDI x5, x0, 10
        u_dut.imem[81] = 32'h00A00293;
        // PC 0x148: ADDI x6, x5, 5  (uses x5 immediately)
        u_dut.imem[82] = 32'h00528313;
        // PC 0x14C: ADD x7, x5, x6  (uses both x5 and x6)
        u_dut.imem[83] = 32'h006283B3;
        
        // Memory RAW
        // PC 0x150: ADDI x8, x0, 200
        u_dut.imem[84] = 32'h0C800413;
        // PC 0x154: SW x5, 0(x8)  (store x5 to memory)
        u_dut.imem[85] = 32'h00542023;
        // PC 0x158: LW x9, 0(x8)  (load immediately after store)
        u_dut.imem[86] = 32'h00042483;
        
        // =====================================================================
        // END: Infinite loop
        // =====================================================================
        // PC 0x15C: JAL x0, -4  (infinite loop)
        u_dut.imem[87] = 32'hFFDFF06F;
        
    endtask
    
    // =========================================================================
    // Test Stimulus and Checking
    // =========================================================================
    
    initial begin
        $display("TEST START");
        $display("=============================================================================");
        $display("RISC-V Comprehensive Test Suite - All 10 Categories");
        $display("=============================================================================");
        $display("");
        
        // Initialize
        reset = 1'b1;
        cycle_count = 0;
        test_errors = 0;
        
        // Reset sequence
        repeat(5) @(posedge clock);
        reset = 1'b0;
        $display("[%0t] Reset deasserted, CPU starting execution", $time);
        $display("");
        
        // Wait for all tests to execute
        repeat(500) @(posedge clock);
        
        $display("");
        $display("=============================================================================");
        $display("Verification: Checking All Test Categories");
        $display("=============================================================================");
        
        // Category 1: Basic ALU Operations
        current_test = "Basic ALU";
        check_register("x1", 1, 32'h0000_000A, "ADDI");
        check_register("x2", 2, 32'h0000_0014, "ADDI");
        check_register("x3", 3, 32'h0000_001E, "ADD");
        check_register("x4", 4, 32'hFFFF_FFF6, "SUB");
        check_register("x5", 5, 32'h0000_0000, "AND");
        check_register("x6", 6, 32'h0000_001E, "OR");
        check_register("x7", 7, 32'h0000_001E, "XOR");
        
        // Category 2: Shift Operations
        current_test = "Shift Ops";
        check_register("x8", 8, 32'h0000_0001, "ADDI");
        check_register("x9", 9, 32'h0000_0010, "SLLI (1<<4=16)");
        check_register("x10", 10, 32'h0000_0003, "ADDI");
        check_register("x11", 11, 32'h0000_0008, "SLL (1<<3=8)");
        check_register("x12", 12, 32'hFFFF_FFFF, "ADDI -1");
        check_register("x13", 13, 32'h0FFF_FFFF, "SRLI");
        check_register("x14", 14, 32'h1FFF_FFFF, "SRL");
        check_register("x15", 15, 32'hFFFF_FFF8, "ADDI -8");
        check_register("x16", 16, 32'hFFFF_FFFE, "SRAI");
        check_register("x17", 17, 32'hFFFF_FFFF, "SRA");
        
        // Category 3: Comparison Operations
        current_test = "Comparisons";
        check_register("x18", 18, 32'hFFFF_FFFB, "ADDI -5");
        check_register("x19", 19, 32'h0000_0003, "ADDI 3");
        check_register("x20", 20, 32'h0000_0001, "SLT (-5<3)");
        check_register("x21", 21, 32'h0000_0000, "SLT (3>-5)");
        check_register("x22", 22, 32'h0000_0000, "SLTU unsigned");
        check_register("x23", 23, 32'h0000_0001, "SLTU unsigned");
        check_register("x24", 24, 32'h0000_0001, "SLTI");
        check_register("x25", 25, 32'h0000_0000, "SLTIU");
        
        // Category 4: Load/Store Operations
        current_test = "Load/Store";
        check_register("x26", 26, 32'h0000_0100, "Base addr");
        check_register("x27", 27, 32'h0000_005A, "ADDI 0x5A");
        check_register("x28", 28, 32'h0000_005A, "LW");
        check_register("x29", 29, 32'hFFFF_FFFF, "ADDI -1");
        check_register("x30", 30, 32'hFFFF_FFFF, "LH signed");
        check_register("x31", 31, 32'h0000_FFFF, "LHU unsigned");
        check_register("x1", 1, 32'hFFFF_FFFE, "ADDI -2");
        check_register("x2", 2, 32'hFFFF_FFFE, "LB signed");
        check_register("x3", 3, 32'h0000_00FE, "LBU unsigned");
        
        // Category 5: Branch Instructions
        current_test = "Branches";
        check_register("x4", 4, 32'h0000_0005, "Setup");
        check_register("x5", 5, 32'h0000_0005, "Setup");
        check_register("x6", 6, 32'h0000_0000, "BEQ skipped");
        check_register("x7", 7, 32'h0000_000A, "BEQ target");
        check_register("x8", 8, 32'h0000_0014, "BNE not taken");
        check_register("x9", 9, 32'hFFFF_FFFF, "Setup -1");
        check_register("x10", 10, 32'h0000_0001, "Setup 1");
        check_register("x11", 11, 32'h0000_0000, "BLT skipped");
        check_register("x12", 12, 32'h0000_001E, "BLT target");
        check_register("x13", 13, 32'h0000_0028, "BGE not taken");
        check_register("x14", 14, 32'h0000_0000, "BLTU skipped");
        check_register("x15", 15, 32'h0000_0032, "BLTU target");
        check_register("x16", 16, 32'h0000_003C, "BGEU not taken");
        
        // Category 6: Jump Instructions
        current_test = "Jumps";
        check_register("x17", 17, 32'h0000_00E4, "JAL return addr");
        check_register("x18", 18, 32'h0000_0000, "JAL skipped");
        check_register("x19", 19, 32'h0000_0046, "JAL target");
        check_register("x20", 20, 32'h0000_0110, "JALR target");
        check_register("x21", 21, 32'h0000_00FC, "JALR return");
        check_register("x22", 22, 32'h0000_0000, "JALR skipped");
        check_register("x23", 23, 32'h0000_0050, "JALR executed");
        check_register("x24", 24, 32'h0000_005A, "After return");
        
        // Category 7: Upper Immediate
        current_test = "Upper Imm";
        check_register("x25", 25, 32'h1234_5678, "LUI+ADDI");
        check_register("x26", 26, 32'h0000_110C, "AUIPC");
        
        // Category 8: Edge Cases
        current_test = "Edge Cases";
        check_register("x0", 0, 32'h0000_0000, "x0 always zero");
        check_register("x27", 27, 32'h0000_0000, "ADD x0,x0");
        check_register("x28", 28, 32'hFFFF_FFFF, "Max unsigned");
        check_register("x29", 29, 32'h0000_0000, "Overflow wrap");
        check_register("x30", 30, 32'h8000_0000, "Most negative");
        check_register("x31", 31, 32'h7FFF_FFFF, "Most positive");
        
        // Category 9: Sequential Flow
        current_test = "Sequential";
        check_register("x1", 1, 32'h0000_0001, "Sequential 1");
        check_register("x2", 2, 32'h0000_0003, "Sequential 2");
        check_register("x3", 3, 32'h0000_0006, "Sequential 3");
        check_register("x4", 4, 32'h0000_000A, "Sequential 4");
        
        // Category 10: Data Hazards
        current_test = "Hazards";
        check_register("x5", 5, 32'h0000_000A, "RAW setup");
        check_register("x6", 6, 32'h0000_000F, "RAW immediate use");
        check_register("x7", 7, 32'h0000_0019, "RAW both operands");
        check_register("x8", 8, 32'h0000_00C8, "Mem addr");
        check_register("x9", 9, 32'h0000_000A, "Load after store");
        
        $display("");
        $display("=============================================================================");
        $display("Test Summary");
        $display("=============================================================================");
        $display("Total cycles executed: %0d", cycle_count);
        $display("Total errors: %0d", test_errors);
        $display("");
        
        if (test_errors == 0) begin
            $display("TEST PASSED");
            $display("All 10 test categories completed successfully!");
        end else begin
            $display("TEST FAILED");
            $error("Test completed with %0d errors", test_errors);
        end
        
        $display("=============================================================================");
        $finish;
    end
    
    // =========================================================================
    // Helper Task: Check Register Value
    // =========================================================================
    
    task check_register(string name, int addr, logic [31:0] expected, string desc);
        logic [31:0] actual;
        actual = reg_file[addr];
        
        if (actual !== expected) begin
            $display("LOG: %0t : ERROR : tb_riscv_comprehensive : u_dut.u_cpu.u_regfile.registers[%0d] : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, addr, expected, actual);
            $display("[FAIL] [%s] %s (%s): Expected 0x%08h, Got 0x%08h", current_test, name, desc, expected, actual);
            test_errors++;
        end else begin
            $display("LOG: %0t : INFO : tb_riscv_comprehensive : u_dut.u_cpu.u_regfile.registers[%0d] : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, addr, expected, actual);
            $display("[PASS] [%s] %s (%s): 0x%08h", current_test, name, desc, actual);
        end
    endtask
    
    // =========================================================================
    // Cycle Counter
    // =========================================================================
    
    always_ff @(posedge clock) begin
        if (reset) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
    end
    
    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    
    initial begin
        #20000;  // 20us timeout
        $display("");
        $display("ERROR: Simulation timeout!");
        $error("Testbench timed out after 20us");
        $finish;
    end
    
    // =========================================================================
    // Waveform Dump
    // =========================================================================
    
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
