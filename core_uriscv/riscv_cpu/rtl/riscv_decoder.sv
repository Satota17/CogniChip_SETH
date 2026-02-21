// =============================================================================
// RISC-V 32-bit Instruction Decoder
// =============================================================================
// Decodes RV32I base instructions
// Extracts instruction fields and generates control signals
// =============================================================================

module riscv_decoder (
    input  logic [31:0] instruction_i,
    
    // Instruction fields
    output logic [6:0]  opcode_o,
    output logic [4:0]  rd_o,
    output logic [4:0]  rs1_o,
    output logic [4:0]  rs2_o,
    output logic [2:0]  funct3_o,
    output logic [6:0]  funct7_o,
    
    // Immediate values
    output logic [31:0] imm_i_o,     // I-type immediate
    output logic [31:0] imm_s_o,     // S-type immediate
    output logic [31:0] imm_b_o,     // B-type immediate
    output logic [31:0] imm_u_o,     // U-type immediate
    output logic [31:0] imm_j_o,     // J-type immediate
    
    // Instruction type decode
    output logic        is_rtype_o,
    output logic        is_itype_o,
    output logic        is_stype_o,
    output logic        is_btype_o,
    output logic        is_utype_o,
    output logic        is_jtype_o,
    
    // Instruction category
    output logic        is_load_o,
    output logic        is_store_o,
    output logic        is_branch_o,
    output logic        is_jal_o,
    output logic        is_jalr_o,
    output logic        is_lui_o,
    output logic        is_auipc_o,
    output logic        is_op_o,      // R-type ALU
    output logic        is_op_imm_o,  // I-type ALU
    output logic        is_system_o,
    
    // Invalid instruction
    output logic        illegal_instr_o
);

    // Opcode definitions (bits [6:0])
    localparam OPCODE_LOAD    = 7'b0000011;
    localparam OPCODE_STORE   = 7'b0100011;
    localparam OPCODE_BRANCH  = 7'b1100011;
    localparam OPCODE_JAL     = 7'b1101111;
    localparam OPCODE_JALR    = 7'b1100111;
    localparam OPCODE_LUI     = 7'b0110111;
    localparam OPCODE_AUIPC   = 7'b0010111;
    localparam OPCODE_OP      = 7'b0110011;  // R-type
    localparam OPCODE_OP_IMM  = 7'b0010011;  // I-type
    localparam OPCODE_SYSTEM  = 7'b1110011;
    localparam OPCODE_FENCE   = 7'b0001111;
    
    // Extract instruction fields
    assign opcode_o = instruction_i[6:0];
    assign rd_o     = instruction_i[11:7];
    assign funct3_o = instruction_i[14:12];
    assign rs1_o    = instruction_i[19:15];
    assign rs2_o    = instruction_i[24:20];
    assign funct7_o = instruction_i[31:25];
    
    // Immediate value extraction with sign extension
    // I-type: imm[11:0] = inst[31:20]
    assign imm_i_o = {{20{instruction_i[31]}}, instruction_i[31:20]};
    
    // S-type: imm[11:0] = {inst[31:25], inst[11:7]}
    assign imm_s_o = {{20{instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
    
    // B-type: imm[12:0] = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}
    assign imm_b_o = {{19{instruction_i[31]}}, instruction_i[31], instruction_i[7], 
                      instruction_i[30:25], instruction_i[11:8], 1'b0};
    
    // U-type: imm[31:0] = {inst[31:12], 12'b0}
    assign imm_u_o = {instruction_i[31:12], 12'b0};
    
    // J-type: imm[20:0] = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
    assign imm_j_o = {{11{instruction_i[31]}}, instruction_i[31], instruction_i[19:12], 
                      instruction_i[20], instruction_i[30:21], 1'b0};
    
    // Instruction type decode
    assign is_rtype_o = (opcode_o == OPCODE_OP);
    assign is_itype_o = (opcode_o == OPCODE_OP_IMM) || (opcode_o == OPCODE_JALR) || 
                        (opcode_o == OPCODE_LOAD);
    assign is_stype_o = (opcode_o == OPCODE_STORE);
    assign is_btype_o = (opcode_o == OPCODE_BRANCH);
    assign is_utype_o = (opcode_o == OPCODE_LUI) || (opcode_o == OPCODE_AUIPC);
    assign is_jtype_o = (opcode_o == OPCODE_JAL);
    
    // Instruction category decode
    assign is_load_o    = (opcode_o == OPCODE_LOAD);
    assign is_store_o   = (opcode_o == OPCODE_STORE);
    assign is_branch_o  = (opcode_o == OPCODE_BRANCH);
    assign is_jal_o     = (opcode_o == OPCODE_JAL);
    assign is_jalr_o    = (opcode_o == OPCODE_JALR);
    assign is_lui_o     = (opcode_o == OPCODE_LUI);
    assign is_auipc_o   = (opcode_o == OPCODE_AUIPC);
    assign is_op_o      = (opcode_o == OPCODE_OP);
    assign is_op_imm_o  = (opcode_o == OPCODE_OP_IMM);
    assign is_system_o  = (opcode_o == OPCODE_SYSTEM);
    
    // Illegal instruction detection (basic check)
    logic valid_opcode;
    
    always_comb begin
        valid_opcode = 1'b0;
        case (opcode_o)
            OPCODE_LOAD,
            OPCODE_STORE,
            OPCODE_BRANCH,
            OPCODE_JAL,
            OPCODE_JALR,
            OPCODE_LUI,
            OPCODE_AUIPC,
            OPCODE_OP,
            OPCODE_OP_IMM,
            OPCODE_SYSTEM,
            OPCODE_FENCE:
                valid_opcode = 1'b1;
            default:
                valid_opcode = 1'b0;
        endcase
    end
    
    assign illegal_instr_o = !valid_opcode;

endmodule
