// =============================================================================
// RISC-V Multi-Cycle Control Unit
// =============================================================================
// Finite State Machine controlling the multi-cycle CPU datapath
// States: FETCH -> DECODE -> EXECUTE -> MEMORY -> WRITEBACK
// =============================================================================

module riscv_control (
    input  logic        clock,
    input  logic        reset,
    
    // Decoder inputs
    input  logic [6:0]  opcode_i,
    input  logic [2:0]  funct3_i,
    input  logic [6:0]  funct7_i,
    input  logic        is_load_i,
    input  logic        is_store_i,
    input  logic        is_branch_i,
    input  logic        is_jal_i,
    input  logic        is_jalr_i,
    input  logic        is_lui_i,
    input  logic        is_auipc_i,
    input  logic        is_op_i,
    input  logic        is_op_imm_i,
    input  logic        illegal_instr_i,
    
    // ALU flags
    input  logic        alu_zero_i,
    input  logic        alu_lt_signed_i,
    input  logic        alu_lt_unsigned_i,
    
    // Control outputs
    output logic        pc_wen_o,           // PC write enable
    output logic        pc_src_o,           // PC source: 0=PC+4, 1=branch/jump
    output logic        ir_wen_o,           // Instruction register write enable
    output logic        regfile_wen_o,      // Register file write enable
    output logic [1:0]  regfile_src_o,      // Regfile data source
    output logic [1:0]  alu_src_a_o,        // ALU operand A source
    output logic [1:0]  alu_src_b_o,        // ALU operand B source
    output logic [3:0]  alu_op_o,           // ALU operation
    output logic        mem_wen_o,          // Memory write enable
    output logic        mem_ren_o,          // Memory read enable
    output logic [1:0]  mem_size_o,         // Memory access size
    output logic        mem_unsigned_o,     // Memory unsigned access
    
    // State output for debugging
    output logic [2:0]  state_o
);

    // FSM states
    typedef enum logic [2:0] {
        STATE_FETCH     = 3'b000,
        STATE_DECODE    = 3'b001,
        STATE_EXECUTE   = 3'b010,
        STATE_MEMORY    = 3'b011,
        STATE_WRITEBACK = 3'b100
    } state_t;
    
    state_t current_state, next_state;
    
    // ALU operation encoding
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_PASS_A = 4'b1010;
    localparam ALU_PASS_B = 4'b1011;
    
    // Regfile data source encoding
    localparam RF_SRC_ALU   = 2'b00;
    localparam RF_SRC_MEM   = 2'b01;
    localparam RF_SRC_PC4   = 2'b10;
    
    // ALU source encoding
    localparam ALU_A_RS1    = 2'b00;
    localparam ALU_A_PC     = 2'b01;
    localparam ALU_A_ZERO   = 2'b10;
    
    localparam ALU_B_RS2    = 2'b00;
    localparam ALU_B_IMM    = 2'b01;
    localparam ALU_B_FOUR   = 2'b10;
    
    // State register
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            current_state <= STATE_FETCH;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            STATE_FETCH: begin
                next_state = STATE_DECODE;
            end
            
            STATE_DECODE: begin
                next_state = STATE_EXECUTE;
            end
            
            STATE_EXECUTE: begin
                if (is_load_i || is_store_i) begin
                    next_state = STATE_MEMORY;
                end else if (is_op_i || is_op_imm_i || is_lui_i || is_auipc_i || 
                            is_jal_i || is_jalr_i) begin
                    next_state = STATE_WRITEBACK;
                end else begin
                    // Branches, or other instructions that don't write back
                    next_state = STATE_FETCH;
                end
            end
            
            STATE_MEMORY: begin
                if (is_load_i) begin
                    next_state = STATE_WRITEBACK;
                end else begin
                    next_state = STATE_FETCH;
                end
            end
            
            STATE_WRITEBACK: begin
                next_state = STATE_FETCH;
            end
            
            default: begin
                next_state = STATE_FETCH;
            end
        endcase
    end
    
    // Output state for debugging
    assign state_o = current_state;
    
    // Control signal generation
    always_comb begin
        // Default values
        pc_wen_o = 1'b0;
        pc_src_o = 1'b0;
        ir_wen_o = 1'b0;
        regfile_wen_o = 1'b0;
        regfile_src_o = RF_SRC_ALU;
        alu_src_a_o = ALU_A_RS1;
        alu_src_b_o = ALU_B_RS2;
        alu_op_o = ALU_ADD;
        mem_wen_o = 1'b0;
        mem_ren_o = 1'b0;
        mem_size_o = 2'b10; // Word
        mem_unsigned_o = 1'b0;
        
        case (current_state)
            STATE_FETCH: begin
                // Read instruction from memory
                mem_ren_o = 1'b1;
                ir_wen_o = 1'b1;
            end
            
            STATE_DECODE: begin
                // Decode happens automatically in decoder module
                // No control signals needed
            end
            
            STATE_EXECUTE: begin
                // Execute ALU operations or calculate addresses
                
                // ALU operand A selection
                if (is_auipc_i || is_jal_i) begin
                    alu_src_a_o = ALU_A_PC;
                end else if (is_lui_i) begin
                    alu_src_a_o = ALU_A_ZERO;
                end else begin
                    alu_src_a_o = ALU_A_RS1;
                end
                
                // ALU operand B selection
                if (is_op_i) begin
                    alu_src_b_o = ALU_B_RS2;
                end else if (is_op_imm_i || is_load_i || is_store_i || 
                            is_jalr_i || is_auipc_i || is_jal_i) begin
                    alu_src_b_o = ALU_B_IMM;
                end else if (is_lui_i) begin
                    alu_src_b_o = ALU_B_IMM;
                end else if (is_branch_i) begin
                    alu_src_b_o = ALU_B_RS2;
                end
                
                // ALU operation selection
                if (is_load_i || is_store_i || is_auipc_i || is_jal_i || is_jalr_i) begin
                    alu_op_o = ALU_ADD;
                end else if (is_lui_i) begin
                    alu_op_o = ALU_PASS_B;
                end else if (is_op_i || is_op_imm_i) begin
                    // Determine ALU operation based on funct3 and funct7
                    case (funct3_i)
                        3'b000: alu_op_o = (is_op_i && funct7_i[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: alu_op_o = ALU_SLL;
                        3'b010: alu_op_o = ALU_SLT;
                        3'b011: alu_op_o = ALU_SLTU;
                        3'b100: alu_op_o = ALU_XOR;
                        3'b101: alu_op_o = funct7_i[5] ? ALU_SRA : ALU_SRL;
                        3'b110: alu_op_o = ALU_OR;
                        3'b111: alu_op_o = ALU_AND;
                    endcase
                end else if (is_branch_i) begin
                    // For branches, use ALU to compute comparison
                    case (funct3_i)
                        3'b000, 3'b001: alu_op_o = ALU_SUB;  // BEQ, BNE
                        3'b100, 3'b101: alu_op_o = ALU_SLT;  // BLT, BGE
                        3'b110, 3'b111: alu_op_o = ALU_SLTU; // BLTU, BGEU
                        default: alu_op_o = ALU_ADD;
                    endcase
                end
                
                // Branch decision and PC update
                if (is_branch_i) begin
                    logic take_branch;
                    case (funct3_i)
                        3'b000: take_branch = alu_zero_i;              // BEQ
                        3'b001: take_branch = !alu_zero_i;             // BNE
                        3'b100: take_branch = alu_lt_signed_i;         // BLT
                        3'b101: take_branch = !alu_lt_signed_i;        // BGE
                        3'b110: take_branch = alu_lt_unsigned_i;       // BLTU
                        3'b111: take_branch = !alu_lt_unsigned_i;      // BGEU
                        default: take_branch = 1'b0;
                    endcase
                    
                    if (take_branch) begin
                        pc_wen_o = 1'b1;
                        pc_src_o = 1'b1;  // PC = PC + imm_b
                    end else begin
                        pc_wen_o = 1'b1;
                        pc_src_o = 1'b0;  // PC = PC + 4
                    end
                end else if (is_jal_i) begin
                    pc_wen_o = 1'b1;
                    pc_src_o = 1'b1;  // PC = PC + imm_j
                end else if (is_jalr_i) begin
                    pc_wen_o = 1'b1;
                    pc_src_o = 1'b1;  // PC = rs1 + imm_i
                end
            end
            
            STATE_MEMORY: begin
                if (is_load_i) begin
                    mem_ren_o = 1'b1;
                    // Memory size and sign extension
                    case (funct3_i[1:0])
                        2'b00: mem_size_o = 2'b00;  // Byte
                        2'b01: mem_size_o = 2'b01;  // Halfword
                        2'b10: mem_size_o = 2'b10;  // Word
                        default: mem_size_o = 2'b10;
                    endcase
                    mem_unsigned_o = funct3_i[2];
                end else if (is_store_i) begin
                    mem_wen_o = 1'b1;
                    // Memory size
                    case (funct3_i[1:0])
                        2'b00: mem_size_o = 2'b00;  // Byte
                        2'b01: mem_size_o = 2'b01;  // Halfword
                        2'b10: mem_size_o = 2'b10;  // Word
                        default: mem_size_o = 2'b10;
                    endcase
                end
            end
            
            STATE_WRITEBACK: begin
                regfile_wen_o = 1'b1;
                
                if (is_load_i) begin
                    regfile_src_o = RF_SRC_MEM;
                end else if (is_jal_i || is_jalr_i) begin
                    regfile_src_o = RF_SRC_PC4;
                end else begin
                    regfile_src_o = RF_SRC_ALU;
                end
                
                // Maintain ALU control signals from EXECUTE state for ALU result
                // ALU operand A selection
                if (is_auipc_i || is_jal_i) begin
                    alu_src_a_o = ALU_A_PC;
                end else if (is_lui_i) begin
                    alu_src_a_o = ALU_A_ZERO;
                end else begin
                    alu_src_a_o = ALU_A_RS1;
                end
                
                // ALU operand B selection
                if (is_op_i) begin
                    alu_src_b_o = ALU_B_RS2;
                end else if (is_op_imm_i || is_load_i || is_jalr_i || is_auipc_i || is_jal_i) begin
                    alu_src_b_o = ALU_B_IMM;
                end else if (is_lui_i) begin
                    alu_src_b_o = ALU_B_IMM;
                end
                
                // ALU operation selection
                if (is_load_i || is_auipc_i || is_jal_i || is_jalr_i) begin
                    alu_op_o = ALU_ADD;
                end else if (is_lui_i) begin
                    alu_op_o = ALU_PASS_B;
                end else if (is_op_i || is_op_imm_i) begin
                    // Determine ALU operation based on funct3 and funct7
                    case (funct3_i)
                        3'b000: alu_op_o = (is_op_i && funct7_i[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: alu_op_o = ALU_SLL;
                        3'b010: alu_op_o = ALU_SLT;
                        3'b011: alu_op_o = ALU_SLTU;
                        3'b100: alu_op_o = ALU_XOR;
                        3'b101: alu_op_o = funct7_i[5] ? ALU_SRA : ALU_SRL;
                        3'b110: alu_op_o = ALU_OR;
                        3'b111: alu_op_o = ALU_AND;
                    endcase
                end
                
                // Update PC for non-branch/jump instructions
                if (!is_branch_i && !is_jal_i && !is_jalr_i) begin
                    pc_wen_o = 1'b1;
                    pc_src_o = 1'b0;  // PC = PC + 4
                end
            end
        endcase
    end

endmodule
