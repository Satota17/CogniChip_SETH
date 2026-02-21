// =============================================================================
// RISC-V 32-bit ALU Module
// =============================================================================
// Arithmetic and Logic Unit for RV32I base instruction set
// Supports: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
// =============================================================================

module riscv_alu (
    // Operands
    input  logic [31:0] operand_a_i,
    input  logic [31:0] operand_b_i,
    
    // ALU operation control
    input  logic [3:0]  alu_op_i,
    
    // Result
    output logic [31:0] result_o,
    
    // Flags
    output logic        zero_o,
    output logic        lt_signed_o,
    output logic        lt_unsigned_o
);

    // ALU operation encoding
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;  // Shift left logical
    localparam ALU_SRL  = 4'b0110;  // Shift right logical
    localparam ALU_SRA  = 4'b0111;  // Shift right arithmetic
    localparam ALU_SLT  = 4'b1000;  // Set less than (signed)
    localparam ALU_SLTU = 4'b1001;  // Set less than (unsigned)
    localparam ALU_PASS_A = 4'b1010; // Pass operand A
    localparam ALU_PASS_B = 4'b1011; // Pass operand B
    
    // Internal signals
    logic [31:0] result;
    logic [4:0]  shift_amount;
    
    // Shift amount (lower 5 bits of operand_b)
    assign shift_amount = operand_b_i[4:0];
    
    // ALU operation
    always_comb begin
        case (alu_op_i)
            ALU_ADD:    result = operand_a_i + operand_b_i;
            ALU_SUB:    result = operand_a_i - operand_b_i;
            ALU_AND:    result = operand_a_i & operand_b_i;
            ALU_OR:     result = operand_a_i | operand_b_i;
            ALU_XOR:    result = operand_a_i ^ operand_b_i;
            ALU_SLL:    result = operand_a_i << shift_amount;
            ALU_SRL:    result = operand_a_i >> shift_amount;
            ALU_SRA:    result = $signed(operand_a_i) >>> shift_amount;
            ALU_SLT:    result = {31'b0, $signed(operand_a_i) < $signed(operand_b_i)};
            ALU_SLTU:   result = {31'b0, operand_a_i < operand_b_i};
            ALU_PASS_A: result = operand_a_i;
            ALU_PASS_B: result = operand_b_i;
            default:    result = 32'b0;
        endcase
    end
    
    assign result_o = result;
    
    // Flag generation
    assign zero_o = (result == 32'b0);
    assign lt_signed_o = $signed(operand_a_i) < $signed(operand_b_i);
    assign lt_unsigned_o = operand_a_i < operand_b_i;

endmodule
