// =============================================================================
// RISC-V Category-by-Category Testbench
// =============================================================================
// Tests each instruction category separately with dedicated test programs
// =============================================================================

module tb_category_tests;

    logic        clock;
    logic        reset;
    logic [31:0] pc;
    logic [2:0]  state;
    logic [31:0] debug_reg_x1;
    logic [31:0] debug_reg_x2;
    
    int          test_errors;
    string       current_category;
    
    // Clock Generation
    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock;
    end
    
    // DUT Instantiation - uses built-in program
    riscv_soc #(
        .IMEM_SIZE(4096),
        .DMEM_SIZE(4096),
        .LOAD_PROGRAM(1)  // Use built-in test program
    ) u_dut (
        .clock           (clock),
        .reset           (reset),
        .pc_o            (pc),
        .state_o         (state),
        .debug_reg_x1_o  (debug_reg_x1),
        .debug_reg_x2_o  (debug_reg_x2)
    );
    
    // Register file access
    logic [31:0] reg_file [31:0];
    always_comb begin
        for (int i = 0; i < 32; i++) begin
            reg_file[i] = u_dut.u_cpu.u_regfile.registers[i];
        end
    end
    
    // Main test sequence
    initial begin
        $display("TEST START");
        $display("=============================================================================");
        $display("RISC-V Category Tests");
        $display("=============================================================================");
        $display("");
        
        test_errors = 0;
        
        // Reset
        reset = 1'b1;
        repeat(5) @(posedge clock);
        reset = 1'b0;
        $display("[%0t] Reset deasserted", $time);
        $display("");
        
        // Wait for Category 1 to execute (built-in program)
        repeat(100) @(posedge clock);
        
        // Test Category 1: Basic ALU (already in built-in program)
        $display("=============================================================================");
        $display("Category 1: Basic ALU Operations");
        $display("=============================================================================");
        current_category = "Basic ALU";
        check_register("x1", 1, 32'h0000_000A, "ADDI x1, x0, 10");
        check_register("x2", 2, 32'h0000_0014, "ADDI x2, x0, 20");
        check_register("x3", 3, 32'h0000_001E, "ADD x3, x1, x2");
        check_register("x4", 4, 32'hFFFF_FFF6, "SUB x4, x1, x2");
        check_register("x5", 5, 32'h0000_0000, "AND x5, x1, x2");
        check_register("x6", 6, 32'h0000_001E, "OR x6, x1, x2");
        check_register("x7", 7, 32'h0000_001E, "XOR x7, x1, x2");
        $display("");
        
        // Now test Category 2: Shift Operations
        test_shift_operations();
        
        // Test Category 3: Comparison Operations
        test_comparison_operations();
        
        // Test Category 4: Load/Store Operations
        test_load_store_operations();
        
        // Test Category 5: Branch Instructions
        test_branch_instructions();
        
        // Test Category 6: Jump Instructions
        test_jump_instructions();
        
        // Test Category 7: Upper Immediate Operations
        test_upper_immediate();
        
        // Test Category 8: Edge Cases
        test_edge_cases();
        
        // Print summary
        $display("");
        $display("=============================================================================");
        $display("Test Summary");
        $display("=============================================================================");
        $display("Total errors: %0d", test_errors);
        $display("");
        
        if (test_errors == 0) begin
            $display("TEST PASSED");
            $display("All categories completed successfully!");
        end else begin
            $display("TEST FAILED");
            $error("Test completed with %0d errors", test_errors);
        end
        
        $display("=============================================================================");
        $finish;
    end
    
    // =========================================================================
    // Category 2: Shift Operations
    // =========================================================================
    task test_shift_operations();
        $display("=============================================================================");
        $display("Category 2: Shift Operations");
        $display("=============================================================================");
        current_category = "Shift Ops";
        
        // Reset first, then load program while in reset
        reset = 1'b1;
        repeat(1) @(posedge clock);
        
        // Load shift test program while in reset
        u_dut.imem[0] = 32'h00100093;  // ADDI x1, x0, 1
        u_dut.imem[1] = 32'h00409093;  // SLLI x1, x1, 4  (x1 = 16)
        u_dut.imem[2] = 32'h00300113;  // ADDI x2, x0, 3
        u_dut.imem[3] = 32'h002091B3;  // SLL x3, x1, x2  (x3 = 128)
        u_dut.imem[4] = 32'hFFF00213;  // ADDI x4, x0, -1 (0xFFFFFFFF)
        u_dut.imem[5] = 32'h00425293;  // SRLI x5, x4, 4  (x5 = 0x0FFFFFFF)
        u_dut.imem[6] = 32'h00235333;  // SRL x6, x6, x2 (needs x6 setup)
        u_dut.imem[7] = 32'hFF800393;  // ADDI x7, x0, -8 (0xFFFFFFF8)
        u_dut.imem[8] = 32'h4023D413;  // SRAI x8, x7, 2  (x8 = 0xFFFFFFFE)
        u_dut.imem[9] = 32'h4023D4B3;  // SRA x9, x7, x2  (x9 = 0xFFFFFFFF)
        u_dut.imem[10] = 32'hFFDFF06F;  // JAL x0, -4 (loop)
        
        // Wait for program to load, then release reset
        repeat(2) @(posedge clock);
        reset = 1'b0;
        repeat(100) @(posedge clock);
        
        // Check results
        check_register("x1", 1, 32'h0000_0010, "SLLI (1<<4=16)");
        check_register("x2", 2, 32'h0000_0003, "ADDI 3");
        check_register("x3", 3, 32'h0000_0080, "SLL (16<<3=128)");
        check_register("x4", 4, 32'hFFFF_FFFF, "ADDI -1");
        check_register("x5", 5, 32'h0FFF_FFFF, "SRLI");
        check_register("x7", 7, 32'hFFFF_FFF8, "ADDI -8");
        check_register("x8", 8, 32'hFFFF_FFFE, "SRAI");
        check_register("x9", 9, 32'hFFFF_FFFF, "SRA");
        $display("");
    endtask
    
    // =========================================================================
    // Category 3: Comparison Operations
    // =========================================================================
    task test_comparison_operations();
        $display("=============================================================================");
        $display("Category 3: Comparison Operations");
        $display("=============================================================================");
        current_category = "Comparisons";
        
        // Reset first
        reset = 1'b1;
        repeat(1) @(posedge clock);
        
        // Load comparison test program while in reset
        u_dut.imem[0] = 32'hFFB00093;  // ADDI x1, x0, -5
        u_dut.imem[1] = 32'h00300113;  // ADDI x2, x0, 3
        u_dut.imem[2] = 32'h0020A1B3;  // SLT x3, x1, x2  (x3 = 1, -5 < 3)
        u_dut.imem[3] = 32'h00112233;  // SLT x4, x2, x1  (x4 = 0, 3 > -5)
        u_dut.imem[4] = 32'h0020B2B3;  // SLTU x5, x1, x2  (x5 = 0, unsigned)
        u_dut.imem[5] = 32'h00113333;  // SLTU x6, x2, x1  (x6 = 1, unsigned)
        u_dut.imem[6] = 32'h0000A393;  // SLTI x7, x1, 0  (x7 = 1, -5 < 0)
        u_dut.imem[7] = 32'h00A0B413;  // SLTIU x8, x1, 10  (x8 = 0, unsigned)
        u_dut.imem[8] = 32'hFFDFF06F;  // JAL x0, -4 (loop)
        
        // Release reset and run
        repeat(2) @(posedge clock);
        reset = 1'b0;
        repeat(100) @(posedge clock);
        
        // Check results
        check_register("x1", 1, 32'hFFFF_FFFB, "ADDI -5");
        check_register("x2", 2, 32'h0000_0003, "ADDI 3");
        check_register("x3", 3, 32'h0000_0001, "SLT (-5<3)");
        check_register("x4", 4, 32'h0000_0000, "SLT (3>-5)");
        check_register("x5", 5, 32'h0000_0000, "SLTU (unsigned)");
        check_register("x6", 6, 32'h0000_0001, "SLTU (unsigned)");
        check_register("x7", 7, 32'h0000_0001, "SLTI");
        check_register("x8", 8, 32'h0000_0000, "SLTIU");
        $display("");
    endtask
    
    // =========================================================================
    // Category 4: Load/Store Operations
    // =========================================================================
    task test_load_store_operations();
        $display("=============================================================================");
        $display("Category 4: Load/Store Operations");
        $display("=============================================================================");
        current_category = "Load/Store";
        
        // Reset first
        reset = 1'b1;
        repeat(1) @(posedge clock);
        
        // Load memory test program while in reset
        u_dut.imem[0] = 32'h10000093;  // ADDI x1, x0, 256 (address)
        u_dut.imem[1] = 32'h05A00113;  // ADDI x2, x0, 0x5A (data)
        u_dut.imem[2] = 32'h0020A023;  // SW x2, 0(x1)
        u_dut.imem[3] = 32'h0000A183;  // LW x3, 0(x1)
        u_dut.imem[4] = 32'hFFF00213;  // ADDI x4, x0, -1
        u_dut.imem[5] = 32'h00409223;  // SH x4, 4(x1)
        u_dut.imem[6] = 32'h00409283;  // LH x5, 4(x1)
        u_dut.imem[7] = 32'h0040D303;  // LHU x6, 4(x1)
        u_dut.imem[8] = 32'hFFE00393;  // ADDI x7, x0, -2
        u_dut.imem[9] = 32'h00708423;  // SB x7, 8(x1)
        u_dut.imem[10] = 32'h00808403;  // LB x8, 8(x1)
        u_dut.imem[11] = 32'h0080C483;  // LBU x9, 8(x1)
        u_dut.imem[12] = 32'hFFDFF06F;  // JAL x0, -4 (loop)
        
        // Release reset and run
        repeat(2) @(posedge clock);
        reset = 1'b0;
        repeat(150) @(posedge clock);
        
        // Check results
        check_register("x1", 1, 32'h0000_0100, "Base address");
        check_register("x2", 2, 32'h0000_005A, "Data to store");
        check_register("x3", 3, 32'h0000_005A, "LW");
        check_register("x4", 4, 32'hFFFF_FFFF, "Halfword data");
        check_register("x5", 5, 32'hFFFF_FFFF, "LH signed");
        check_register("x6", 6, 32'h0000_FFFF, "LHU unsigned");
        check_register("x7", 7, 32'hFFFF_FFFE, "Byte data");
        check_register("x8", 8, 32'hFFFF_FFFE, "LB signed");
        check_register("x9", 9, 32'h0000_00FE, "LBU unsigned");
        $display("");
    endtask
    
    // =========================================================================
    // Category 5: Branch Instructions
    // =========================================================================
    task test_branch_instructions();
        $display("=============================================================================");
        $display("Category 5: Branch Instructions");
        $display("=============================================================================");
        current_category = "Branches";
        
        // Reset first
        reset = 1'b1;
        repeat(1) @(posedge clock);
        
        // Load branch test program while in reset
        u_dut.imem[0] = 32'h00500093;  // ADDI x1, x0, 5
        u_dut.imem[1] = 32'h00500113;  // ADDI x2, x0, 5
        u_dut.imem[2] = 32'h00208463;  // BEQ x1, x2, +8
        u_dut.imem[3] = 32'h06300193;  // ADDI x3, x0, 99 (skipped)
        u_dut.imem[4] = 32'h00A00213;  // ADDI x4, x0, 10
        u_dut.imem[5] = 32'h00209463;  // BNE x1, x2, +8
        u_dut.imem[6] = 32'h01400293;  // ADDI x5, x0, 20 (executed)
        u_dut.imem[7] = 32'hFFF00313;  // ADDI x6, x0, -1
        u_dut.imem[8] = 32'h00100393;  // ADDI x7, x0, 1
        u_dut.imem[9] = 32'h0073C463;  // BLT x7, x7, +8
        u_dut.imem[10] = 32'h01E00413;  // ADDI x8, x0, 30
        u_dut.imem[11] = 32'hFFDFF06F;  // JAL x0, -4 (loop)
        
        // Release reset and run
        repeat(2) @(posedge clock);
        reset = 1'b0;
        repeat(150) @(posedge clock);
        
        // Check results
        check_register("x1", 1, 32'h0000_0005, "Setup");
        check_register("x2", 2, 32'h0000_0005, "Setup");
        check_register("x3", 3, 32'h0000_0000, "BEQ skipped");
        check_register("x4", 4, 32'h0000_000A, "BEQ target");
        check_register("x5", 5, 32'h0000_0014, "BNE not taken");
        check_register("x8", 8, 32'h0000_001E, "After branches");
        $display("");
    endtask
    
    // =========================================================================
    // Category 6: Jump Instructions
    // =========================================================================
    task test_jump_instructions();
        $display("=============================================================================");
        $display("Category 6: Jump Instructions");
        $display("=============================================================================");
        current_category = "Jumps";
        
        // Reset first
        reset = 1'b1;
        repeat(1) @(posedge clock);
        
        // Load jump test program while in reset
        u_dut.imem[0] = 32'h008000EF;  // JAL x1, +8
        u_dut.imem[1] = 32'h06300113;  // ADDI x2, x0, 99 (skipped)
        u_dut.imem[2] = 32'h00A00193;  // ADDI x3, x0, 10
        u_dut.imem[3] = 32'h03000213;  // ADDI x4, x0, 48 (address)
        u_dut.imem[4] = 32'h000200E7;  // JALR x1, x4, 0
        u_dut.imem[5] = 32'h06300293;  // ADDI x5, x0, 99 (skipped)
        for (int i = 6; i < 12; i++) u_dut.imem[i] = 32'h00000013;  // NOPs
        u_dut.imem[12] = 32'h01400313;  // ADDI x6, x0, 20
        u_dut.imem[13] = 32'hFFDFF06F;  // JAL x0, -4 (loop)
        
        // Release reset and run
        repeat(2) @(posedge clock);
        reset = 1'b0;
        repeat(150) @(posedge clock);
        
        // Check results
        check_register("x1", 1, 32'h0000_0014, "JALR return address");
        check_register("x2", 2, 32'h0000_0000, "JAL skipped");
        check_register("x3", 3, 32'h0000_000A, "JAL target");
        check_register("x5", 5, 32'h0000_0000, "JALR skipped");
        check_register("x6", 6, 32'h0000_0014, "JALR target");
        $display("");
    endtask
    
    // =========================================================================
    // Category 7: Upper Immediate Operations
    // =========================================================================
    task test_upper_immediate();
        $display("=============================================================================");
        $display("Category 7: Upper Immediate Operations");
        $display("=============================================================================");
        current_category = "Upper Imm";
        
        // Reset first
        reset = 1'b1;
        repeat(1) @(posedge clock);
        
        // Load upper immediate test program while in reset
        u_dut.imem[0] = 32'h123450B7;  // LUI x1, 0x12345
        u_dut.imem[1] = 32'h67808093;  // ADDI x1, x1, 0x678
        u_dut.imem[2] = 32'h00001117;  // AUIPC x2, 0x1
        u_dut.imem[3] = 32'hFFDFF06F;  // JAL x0, -4 (loop)
        
        // Release reset and run
        repeat(2) @(posedge clock);
        reset = 1'b0;
        repeat(100) @(posedge clock);
        
        // Check results
        check_register("x1", 1, 32'h1234_5678, "LUI+ADDI");
        check_register("x2", 2, 32'h0000_1008, "AUIPC");
        $display("");
    endtask
    
    // =========================================================================
    // Category 8: Edge Cases
    // =========================================================================
    task test_edge_cases();
        $display("=============================================================================");
        $display("Category 8: Edge Cases");
        $display("=============================================================================");
        current_category = "Edge Cases";
        
        // Reset first
        reset = 1'b1;
        repeat(1) @(posedge clock);
        
        // Load edge case test program while in reset
        u_dut.imem[0] = 32'h07B00013;  // ADDI x0, x0, 123 (write to x0)
        u_dut.imem[1] = 32'h000000B3;  // ADD x1, x0, x0 (x1 = 0)
        u_dut.imem[2] = 32'hFFF00113;  // ADDI x2, x0, -1
        u_dut.imem[3] = 32'h00110193;  // ADDI x3, x2, 1 (overflow)
        u_dut.imem[4] = 32'h80000237;  // LUI x4, 0x80000 (most negative)
        u_dut.imem[5] = 32'hFFF00293;  // ADDI x5, x0, -1
        u_dut.imem[6] = 32'h0012D293;  // SRLI x5, x5, 1 (most positive)
        u_dut.imem[7] = 32'hFFDFF06F;  // JAL x0, -4 (loop)
        
        // Release reset and run
        repeat(2) @(posedge clock);
        reset = 1'b0;
        repeat(100) @(posedge clock);
        
        // Check results
        check_register("x0", 0, 32'h0000_0000, "x0 always zero");
        check_register("x1", 1, 32'h0000_0000, "ADD x0,x0");
        check_register("x2", 2, 32'hFFFF_FFFF, "Max unsigned");
        check_register("x3", 3, 32'h0000_0000, "Overflow wrap");
        check_register("x4", 4, 32'h8000_0000, "Most negative");
        check_register("x5", 5, 32'h7FFF_FFFF, "Most positive");
        $display("");
    endtask
    
    // =========================================================================
    // Helper Tasks
    // =========================================================================
    
    task check_register(string name, int addr, logic [31:0] expected, string desc);
        logic [31:0] actual;
        actual = reg_file[addr];
        
        if (actual !== expected) begin
            $display("LOG: %0t : ERROR : tb_category_tests : u_dut.u_cpu.u_regfile.registers[%0d] : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, addr, expected, actual);
            $display("[FAIL] [%s] %s (%s): Expected 0x%08h, Got 0x%08h", current_category, name, desc, expected, actual);
            test_errors++;
        end else begin
            $display("LOG: %0t : INFO : tb_category_tests : u_dut.u_cpu.u_regfile.registers[%0d] : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, addr, expected, actual);
            $display("[PASS] [%s] %s (%s): 0x%08h", current_category, name, desc, actual);
        end
    endtask
    
    // Timeout watchdog
    initial begin
        #50000;
        $display("ERROR: Simulation timeout!");
        $error("Testbench timed out");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
