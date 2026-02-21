// Testbench for 8-bit ALU
// Comprehensive verification of all ALU operations and flags

`timescale 1ns/1ps

module tb_alu_8bit;

    // Testbench signals
    reg [7:0] A;
    reg [7:0] B;
    reg [3:0] opcode;
    wire [7:0] result;
    wire zero, carry, overflow, sign;

    // Test tracking
    integer test_count;
    integer pass_count;
    integer fail_count;

    // Operation codes (matching DUT)
    localparam ADD  = 4'b0000;
    localparam SUB  = 4'b0001;
    localparam AND  = 4'b0010;
    localparam OR   = 4'b0011;
    localparam XOR  = 4'b0100;
    localparam NOT  = 4'b0101;
    localparam SLL  = 4'b0110;
    localparam SRL  = 4'b0111;
    localparam SLA  = 4'b1000;
    localparam SRA  = 4'b1001;
    localparam INC  = 4'b1010;
    localparam DEC  = 4'b1011;
    localparam EQ   = 4'b1100;
    localparam LT   = 4'b1101;
    localparam GT   = 4'b1110;
    localparam PASS = 4'b1111;

    // Instantiate DUT
    alu_8bit dut (
        .A(A),
        .B(B),
        .opcode(opcode),
        .result(result),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .sign(sign)
    );

    // Task to check results
    task check_result;
        input [7:0] expected_result;
        input expected_zero;
        input expected_carry;
        input expected_overflow;
        input expected_sign;
        input [255:0] test_name;
        begin
            test_count = test_count + 1;
            #1; // Small delay for combinational propagation
            
            if (result !== expected_result) begin
                $display("LOG: %0t : ERROR : tb_alu_8bit : dut.result : expected_value: 8'h%02h actual_value: 8'h%02h", 
                         $time, expected_result, result);
                $display("  Test: %s FAILED", test_name);
                fail_count = fail_count + 1;
            end else if (zero !== expected_zero) begin
                $display("LOG: %0t : ERROR : tb_alu_8bit : dut.zero : expected_value: 1'b%b actual_value: 1'b%b", 
                         $time, expected_zero, zero);
                $display("  Test: %s FAILED (zero flag mismatch)", test_name);
                fail_count = fail_count + 1;
            end else if (carry !== expected_carry) begin
                $display("LOG: %0t : ERROR : tb_alu_8bit : dut.carry : expected_value: 1'b%b actual_value: 1'b%b", 
                         $time, expected_carry, carry);
                $display("  Test: %s FAILED (carry flag mismatch)", test_name);
                fail_count = fail_count + 1;
            end else if (overflow !== expected_overflow) begin
                $display("LOG: %0t : ERROR : tb_alu_8bit : dut.overflow : expected_value: 1'b%b actual_value: 1'b%b", 
                         $time, expected_overflow, overflow);
                $display("  Test: %s FAILED (overflow flag mismatch)", test_name);
                fail_count = fail_count + 1;
            end else if (sign !== expected_sign) begin
                $display("LOG: %0t : ERROR : tb_alu_8bit : dut.sign : expected_value: 1'b%b actual_value: 1'b%b", 
                         $time, expected_sign, sign);
                $display("  Test: %s FAILED (sign flag mismatch)", test_name);
                fail_count = fail_count + 1;
            end else begin
                $display("LOG: %0t : INFO : tb_alu_8bit : dut.result : expected_value: 8'h%02h actual_value: 8'h%02h", 
                         $time, expected_result, result);
                $display("  Test: %s PASSED", test_name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("=====================================");
        $display("8-bit ALU Testbench");
        $display("=====================================");
        
        // Initialize counters
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Initialize inputs
        A = 8'h00;
        B = 8'h00;
        opcode = 4'h0;
        #10;

        //===========================================
        // Test ADD operation
        //===========================================
        $display("\n--- Testing ADD Operation ---");
        
        // Basic addition
        A = 8'h05; B = 8'h03; opcode = ADD; #10;
        check_result(8'h08, 1'b0, 1'b0, 1'b0, 1'b0, "ADD: 5 + 3 = 8");
        
        // Addition with carry
        A = 8'hFF; B = 8'h01; opcode = ADD; #10;
        check_result(8'h00, 1'b1, 1'b1, 1'b0, 1'b0, "ADD: FF + 1 = 00 (carry)");
        
        // Addition with overflow (signed)
        A = 8'h7F; B = 8'h01; opcode = ADD; #10;
        check_result(8'h80, 1'b0, 1'b0, 1'b1, 1'b1, "ADD: 7F + 1 = 80 (overflow)");
        
        // Zero result
        A = 8'h00; B = 8'h00; opcode = ADD; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "ADD: 0 + 0 = 0 (zero)");

        //===========================================
        // Test SUB operation
        //===========================================
        $display("\n--- Testing SUB Operation ---");
        
        // Basic subtraction
        A = 8'h0A; B = 8'h05; opcode = SUB; #10;
        check_result(8'h05, 1'b0, 1'b0, 1'b0, 1'b0, "SUB: A - 5 = 5");
        
        // Subtraction resulting in zero
        A = 8'h05; B = 8'h05; opcode = SUB; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "SUB: 5 - 5 = 0 (zero)");
        
        // Subtraction with underflow
        A = 8'h00; B = 8'h01; opcode = SUB; #10;
        check_result(8'hFF, 1'b0, 1'b1, 1'b0, 1'b1, "SUB: 0 - 1 = FF (underflow)");
        
        // Subtraction with overflow (signed)
        A = 8'h80; B = 8'h01; opcode = SUB; #10;
        check_result(8'h7F, 1'b0, 1'b0, 1'b1, 1'b0, "SUB: 80 - 1 = 7F (overflow)");

        //===========================================
        // Test AND operation
        //===========================================
        $display("\n--- Testing AND Operation ---");
        
        A = 8'hF0; B = 8'h0F; opcode = AND; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "AND: F0 & 0F = 00");
        
        A = 8'hFF; B = 8'hAA; opcode = AND; #10;
        check_result(8'hAA, 1'b0, 1'b0, 1'b0, 1'b1, "AND: FF & AA = AA");
        
        A = 8'h55; B = 8'hAA; opcode = AND; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "AND: 55 & AA = 00");

        //===========================================
        // Test OR operation
        //===========================================
        $display("\n--- Testing OR Operation ---");
        
        A = 8'hF0; B = 8'h0F; opcode = OR; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "OR: F0 | 0F = FF");
        
        A = 8'h00; B = 8'h00; opcode = OR; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "OR: 00 | 00 = 00");
        
        A = 8'h55; B = 8'hAA; opcode = OR; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "OR: 55 | AA = FF");

        //===========================================
        // Test XOR operation
        //===========================================
        $display("\n--- Testing XOR Operation ---");
        
        A = 8'hFF; B = 8'hFF; opcode = XOR; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "XOR: FF ^ FF = 00");
        
        A = 8'h55; B = 8'hAA; opcode = XOR; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "XOR: 55 ^ AA = FF");
        
        A = 8'hA5; B = 8'h5A; opcode = XOR; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "XOR: A5 ^ 5A = FF");

        //===========================================
        // Test NOT operation
        //===========================================
        $display("\n--- Testing NOT Operation ---");
        
        A = 8'h00; B = 8'hxx; opcode = NOT; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "NOT: ~00 = FF");
        
        A = 8'hFF; B = 8'hxx; opcode = NOT; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "NOT: ~FF = 00");
        
        A = 8'hAA; B = 8'hxx; opcode = NOT; #10;
        check_result(8'h55, 1'b0, 1'b0, 1'b0, 1'b0, "NOT: ~AA = 55");

        //===========================================
        // Test SLL (Shift Left Logical)
        //===========================================
        $display("\n--- Testing SLL Operation ---");
        
        A = 8'h01; B = 8'hxx; opcode = SLL; #10;
        check_result(8'h02, 1'b0, 1'b0, 1'b0, 1'b0, "SLL: 01 << 1 = 02");
        
        A = 8'h80; B = 8'hxx; opcode = SLL; #10;
        check_result(8'h00, 1'b1, 1'b1, 1'b0, 1'b0, "SLL: 80 << 1 = 00 (carry)");
        
        A = 8'hC0; B = 8'hxx; opcode = SLL; #10;
        check_result(8'h80, 1'b0, 1'b1, 1'b0, 1'b1, "SLL: C0 << 1 = 80 (carry)");

        //===========================================
        // Test SRL (Shift Right Logical)
        //===========================================
        $display("\n--- Testing SRL Operation ---");
        
        A = 8'h02; B = 8'hxx; opcode = SRL; #10;
        check_result(8'h01, 1'b0, 1'b0, 1'b0, 1'b0, "SRL: 02 >> 1 = 01");
        
        A = 8'h01; B = 8'hxx; opcode = SRL; #10;
        check_result(8'h00, 1'b1, 1'b1, 1'b0, 1'b0, "SRL: 01 >> 1 = 00 (carry)");
        
        A = 8'h80; B = 8'hxx; opcode = SRL; #10;
        check_result(8'h40, 1'b0, 1'b0, 1'b0, 1'b0, "SRL: 80 >> 1 = 40");

        //===========================================
        // Test SRA (Shift Right Arithmetic)
        //===========================================
        $display("\n--- Testing SRA Operation ---");
        
        A = 8'h80; B = 8'hxx; opcode = SRA; #10;
        check_result(8'hC0, 1'b0, 1'b0, 1'b0, 1'b1, "SRA: 80 >> 1 = C0 (sign extended)");
        
        A = 8'h40; B = 8'hxx; opcode = SRA; #10;
        check_result(8'h20, 1'b0, 1'b0, 1'b0, 1'b0, "SRA: 40 >> 1 = 20");
        
        A = 8'h01; B = 8'hxx; opcode = SRA; #10;
        check_result(8'h00, 1'b1, 1'b1, 1'b0, 1'b0, "SRA: 01 >> 1 = 00 (carry)");

        //===========================================
        // Test INC operation
        //===========================================
        $display("\n--- Testing INC Operation ---");
        
        A = 8'h00; B = 8'hxx; opcode = INC; #10;
        check_result(8'h01, 1'b0, 1'b0, 1'b0, 1'b0, "INC: 00 + 1 = 01");
        
        A = 8'hFF; B = 8'hxx; opcode = INC; #10;
        check_result(8'h00, 1'b1, 1'b1, 1'b0, 1'b0, "INC: FF + 1 = 00 (carry)");
        
        A = 8'h7F; B = 8'hxx; opcode = INC; #10;
        check_result(8'h80, 1'b0, 1'b0, 1'b1, 1'b1, "INC: 7F + 1 = 80 (overflow)");

        //===========================================
        // Test DEC operation
        //===========================================
        $display("\n--- Testing DEC Operation ---");
        
        A = 8'h01; B = 8'hxx; opcode = DEC; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "DEC: 01 - 1 = 00");
        
        A = 8'h00; B = 8'hxx; opcode = DEC; #10;
        check_result(8'hFF, 1'b0, 1'b1, 1'b0, 1'b1, "DEC: 00 - 1 = FF (underflow)");
        
        A = 8'h80; B = 8'hxx; opcode = DEC; #10;
        check_result(8'h7F, 1'b0, 1'b0, 1'b1, 1'b0, "DEC: 80 - 1 = 7F (overflow)");

        //===========================================
        // Test EQ (Equal) operation
        //===========================================
        $display("\n--- Testing EQ Operation ---");
        
        A = 8'h55; B = 8'h55; opcode = EQ; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "EQ: 55 == 55 = FF (true)");
        
        A = 8'h55; B = 8'hAA; opcode = EQ; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "EQ: 55 == AA = 00 (false)");
        
        A = 8'h00; B = 8'h00; opcode = EQ; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "EQ: 00 == 00 = FF (true)");

        //===========================================
        // Test LT (Less Than) operation
        //===========================================
        $display("\n--- Testing LT Operation ---");
        
        A = 8'h05; B = 8'h0A; opcode = LT; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "LT: 05 < 0A = FF (true)");
        
        A = 8'h0A; B = 8'h05; opcode = LT; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "LT: 0A < 05 = 00 (false)");
        
        A = 8'h05; B = 8'h05; opcode = LT; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "LT: 05 < 05 = 00 (false)");

        //===========================================
        // Test GT (Greater Than) operation
        //===========================================
        $display("\n--- Testing GT Operation ---");
        
        A = 8'h0A; B = 8'h05; opcode = GT; #10;
        check_result(8'hFF, 1'b0, 1'b0, 1'b0, 1'b1, "GT: 0A > 05 = FF (true)");
        
        A = 8'h05; B = 8'h0A; opcode = GT; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "GT: 05 > 0A = 00 (false)");
        
        A = 8'h05; B = 8'h05; opcode = GT; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "GT: 05 > 05 = 00 (false)");

        //===========================================
        // Test PASS operation
        //===========================================
        $display("\n--- Testing PASS Operation ---");
        
        A = 8'hAA; B = 8'hxx; opcode = PASS; #10;
        check_result(8'hAA, 1'b0, 1'b0, 1'b0, 1'b1, "PASS: AA passed through");
        
        A = 8'h00; B = 8'hxx; opcode = PASS; #10;
        check_result(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "PASS: 00 passed through");
        
        A = 8'h55; B = 8'hxx; opcode = PASS; #10;
        check_result(8'h55, 1'b0, 1'b0, 1'b0, 1'b0, "PASS: 55 passed through");

        //===========================================
        // Final Results
        //===========================================
        #10;
        $display("\n=====================================");
        $display("Test Summary:");
        $display("  Total Tests: %0d", test_count);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("=====================================");
        
        if (fail_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("ERROR");
            $error("TEST FAILED - %0d test(s) failed", fail_count);
        end
        
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
