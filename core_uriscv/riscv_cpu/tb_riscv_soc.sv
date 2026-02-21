// =============================================================================
// RISC-V SoC Testbench
// =============================================================================
// Comprehensive testbench for RV32I multi-cycle CPU
// Tests:
//   - Arithmetic instructions (ADD, SUB, ADDI)
//   - Logical instructions (AND, OR, XOR)
//   - Instruction fetch and decode
//   - Register file operations
//   - Multi-cycle state machine operation
// =============================================================================

module tb_riscv_soc;

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
    int          instruction_count;
    logic [31:0] prev_pc;
    int          test_errors;
    
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
        .IMEM_SIZE(4096),
        .DMEM_SIZE(4096)
    ) u_dut (
        .clock           (clock),
        .reset           (reset),
        .pc_o            (pc),
        .state_o         (state),
        .debug_reg_x1_o  (debug_reg_x1),
        .debug_reg_x2_o  (debug_reg_x2)
    );
    
    // =========================================================================
    // State Monitoring
    // =========================================================================
    
    string state_name;
    
    always_comb begin
        case (state)
            3'b000:  state_name = "FETCH";
            3'b001:  state_name = "DECODE";
            3'b010:  state_name = "EXECUTE";
            3'b011:  state_name = "MEMORY";
            3'b100:  state_name = "WRITEBACK";
            default: state_name = "UNKNOWN";
        endcase
    end
    
    // =========================================================================
    // Instruction Tracking
    // =========================================================================
    
    logic [31:0] current_instruction;
    string instr_name;
    
    always_ff @(posedge clock) begin
        if (state == 3'b001) begin  // DECODE state
            current_instruction <= u_dut.u_cpu.instruction_reg;
        end
    end
    
    // Decode instruction for display
    always_comb begin
        instr_name = "UNKNOWN";
        
        if (state == 3'b001 || state == 3'b010) begin
            case (u_dut.u_cpu.opcode)
                7'b0010011: begin  // OP-IMM
                    case (u_dut.u_cpu.funct3)
                        3'b000: instr_name = "ADDI";
                        3'b001: instr_name = "SLLI";
                        3'b010: instr_name = "SLTI";
                        3'b011: instr_name = "SLTIU";
                        3'b100: instr_name = "XORI";
                        3'b101: instr_name = u_dut.u_cpu.funct7[5] ? "SRAI" : "SRLI";
                        3'b110: instr_name = "ORI";
                        3'b111: instr_name = "ANDI";
                    endcase
                end
                7'b0110011: begin  // OP
                    case (u_dut.u_cpu.funct3)
                        3'b000: instr_name = u_dut.u_cpu.funct7[5] ? "SUB" : "ADD";
                        3'b001: instr_name = "SLL";
                        3'b010: instr_name = "SLT";
                        3'b011: instr_name = "SLTU";
                        3'b100: instr_name = "XOR";
                        3'b101: instr_name = u_dut.u_cpu.funct7[5] ? "SRA" : "SRL";
                        3'b110: instr_name = "OR";
                        3'b111: instr_name = "AND";
                    endcase
                end
                7'b1101111: instr_name = "JAL";
                7'b1100111: instr_name = "JALR";
                7'b1100011: begin  // BRANCH
                    case (u_dut.u_cpu.funct3)
                        3'b000: instr_name = "BEQ";
                        3'b001: instr_name = "BNE";
                        3'b100: instr_name = "BLT";
                        3'b101: instr_name = "BGE";
                        3'b110: instr_name = "BLTU";
                        3'b111: instr_name = "BGEU";
                    endcase
                end
                7'b0000011: begin  // LOAD
                    case (u_dut.u_cpu.funct3)
                        3'b000: instr_name = "LB";
                        3'b001: instr_name = "LH";
                        3'b010: instr_name = "LW";
                        3'b100: instr_name = "LBU";
                        3'b101: instr_name = "LHU";
                    endcase
                end
                7'b0100011: begin  // STORE
                    case (u_dut.u_cpu.funct3)
                        3'b000: instr_name = "SB";
                        3'b001: instr_name = "SH";
                        3'b010: instr_name = "SW";
                    endcase
                end
                7'b0110111: instr_name = "LUI";
                7'b0010111: instr_name = "AUIPC";
                7'b1110011: instr_name = "SYSTEM";
                default:    instr_name = "UNKNOWN";
            endcase
        end
    end
    
    // =========================================================================
    // Register File Monitoring
    // =========================================================================
    
    logic [31:0] reg_file [31:0];
    
    always_comb begin
        for (int i = 0; i < 32; i++) begin
            reg_file[i] = u_dut.u_cpu.u_regfile.registers[i];
        end
    end
    
    // =========================================================================
    // Test Stimulus and Checking
    // =========================================================================
    
    initial begin
        $display("TEST START");
        $display("=============================================================================");
        $display("RISC-V RV32I Multi-Cycle CPU Testbench");
        $display("=============================================================================");
        $display("");
        
        // Initialize
        reset = 1'b1;
        cycle_count = 0;
        instruction_count = 0;
        test_errors = 0;
        prev_pc = 32'h0;
        
        // Reset sequence
        repeat(5) @(posedge clock);
        reset = 1'b0;
        $display("[%0t] Reset deasserted, CPU starting execution", $time);
        $display("");
        
        // Wait for initial instructions to execute
        // The test program in riscv_soc.sv performs:
        // 1. x1 = 10 (ADDI)
        // 2. x2 = 20 (ADDI)
        // 3. x3 = x1 + x2 = 30 (ADD)
        // 4. x4 = x1 - x2 = -10 (SUB)
        // 5. x5 = x1 & x2 = 0 (AND)
        // 6. x6 = x1 | x2 = 30 (OR)
        // 7. x7 = x1 ^ x2 = 30 (XOR)
        // 8. Infinite loop (JAL)
        
        // Wait for sufficient cycles to execute all instructions
        repeat(100) @(posedge clock);
        
        $display("");
        $display("=============================================================================");
        $display("Checking Results");
        $display("=============================================================================");
        
        // Check x1 = 10 (0x0A)
        check_register("x1", 1, 32'h0000_000A);
        
        // Check x2 = 20 (0x14)
        check_register("x2", 2, 32'h0000_0014);
        
        // Check x3 = x1 + x2 = 30 (0x1E)
        check_register("x3", 3, 32'h0000_001E);
        
        // Check x4 = x1 - x2 = -10 (0xFFFFFFF6)
        check_register("x4", 4, 32'hFFFF_FFF6);
        
        // Check x5 = x1 & x2 = 0 (0x00)
        check_register("x5", 5, 32'h0000_0000);
        
        // Check x6 = x1 | x2 = 30 (0x1E)
        check_register("x6", 6, 32'h0000_001E);
        
        // Check x7 = x1 ^ x2 = 30 (0x1E)
        check_register("x7", 7, 32'h0000_001E);
        
        // Check that x0 is always 0
        check_register("x0", 0, 32'h0000_0000);
        
        $display("");
        $display("=============================================================================");
        $display("Test Summary");
        $display("=============================================================================");
        $display("Total cycles executed: %0d", cycle_count);
        $display("Total instructions fetched: %0d", instruction_count);
        $display("Total errors: %0d", test_errors);
        $display("");
        
        if (test_errors == 0) begin
            $display("TEST PASSED");
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
    
    task check_register(string name, int addr, logic [31:0] expected);
        logic [31:0] actual;
        actual = reg_file[addr];
        
        if (actual !== expected) begin
            $display("LOG: %0t : ERROR : tb_riscv_soc : u_dut.u_cpu.u_regfile.registers[%0d] : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, addr, expected, actual);
            $display("[FAIL] %s: Expected 0x%08h, Got 0x%08h", name, expected, actual);
            test_errors++;
        end else begin
            $display("LOG: %0t : INFO : tb_riscv_soc : u_dut.u_cpu.u_regfile.registers[%0d] : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, addr, expected, actual);
            $display("[PASS] %s: 0x%08h", name, actual);
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
    // Instruction Counter (counts when PC changes)
    // =========================================================================
    
    always_ff @(posedge clock) begin
        if (reset) begin
            instruction_count <= 0;
            prev_pc <= 32'h0;
        end else begin
            if (pc != prev_pc && state == 3'b001) begin  // New instruction fetched
                instruction_count <= instruction_count + 1;
            end
            prev_pc <= pc;
        end
    end
    
    // =========================================================================
    // Execution Trace (optional, can be enabled for debugging)
    // =========================================================================
    
    // Uncomment for detailed execution trace
    /*
    always_ff @(posedge clock) begin
        if (!reset) begin
            if (state == 3'b010) begin  // EXECUTE state
                $display("[%0t] PC=0x%08h | %s | State=%s", 
                         $time, pc, instr_name, state_name);
            end
        end
    end
    */
    
    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    
    initial begin
        #10000;  // 10us timeout
        $display("");
        $display("ERROR: Simulation timeout!");
        $error("Testbench timed out after 10us");
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
