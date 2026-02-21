// =============================================================================
// RISC-V 32-bit Multi-Cycle CPU Core
// =============================================================================
// Simple multi-cycle RV32I implementation
// Architecture: Harvard architecture with separate instruction and data memory
// Features:
//   - 32-bit RV32I base instruction set
//   - Multi-cycle execution (5 stages: Fetch, Decode, Execute, Memory, Writeback)
//   - 32 x 32-bit integer register file
//   - Support for all RV32I instructions
// =============================================================================

module riscv_cpu_core (
    input  logic        clock,
    input  logic        reset,
    
    // Instruction memory interface
    output logic [31:0] imem_addr_o,
    input  logic [31:0] imem_data_i,
    output logic        imem_ren_o,
    
    // Data memory interface
    output logic [31:0] dmem_addr_o,
    output logic [31:0] dmem_wdata_o,
    input  logic [31:0] dmem_rdata_i,
    output logic        dmem_wen_o,
    output logic        dmem_ren_o,
    output logic [1:0]  dmem_size_o,
    
    // Debug outputs
    output logic [31:0] pc_o,
    output logic [2:0]  state_o
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    // Program Counter
    logic [31:0] pc_reg, pc_next;
    logic        pc_wen;
    logic        pc_src;
    
    // Instruction Register
    logic [31:0] instruction_reg;
    logic        ir_wen;
    
    // Decoder outputs
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    logic        is_rtype, is_itype, is_stype, is_btype, is_utype, is_jtype;
    logic        is_load, is_store, is_branch, is_jal, is_jalr;
    logic        is_lui, is_auipc, is_op, is_op_imm, is_system;
    logic        illegal_instr;
    
    // Register file signals
    logic [31:0] rs1_data, rs2_data;
    logic        regfile_wen;
    logic [31:0] regfile_wdata;
    logic [1:0]  regfile_src;
    
    // ALU signals
    logic [31:0] alu_operand_a, alu_operand_b;
    logic [31:0] alu_result;
    logic [3:0]  alu_op;
    logic        alu_zero, alu_lt_signed, alu_lt_unsigned;
    logic [1:0]  alu_src_a, alu_src_b;
    
    // Memory signals
    logic [31:0] mem_addr;
    logic [31:0] mem_rdata_extended;
    logic        mem_wen, mem_ren;
    logic [1:0]  mem_size;
    logic        mem_unsigned;
    
    // Branch/Jump target calculation
    logic [31:0] branch_target;
    logic [31:0] pc_plus_4;
    
    // =========================================================================
    // Program Counter
    // =========================================================================
    
    assign pc_plus_4 = pc_reg + 32'd4;
    
    // Calculate branch/jump target
    always_comb begin
        if (is_jalr) begin
            branch_target = (rs1_data + imm_i) & ~32'b1;  // JALR clears LSB
        end else if (is_jal) begin
            branch_target = pc_reg + imm_j;
        end else if (is_branch) begin
            branch_target = pc_reg + imm_b;
        end else begin
            branch_target = pc_plus_4;
        end
    end
    
    assign pc_next = pc_src ? branch_target : pc_plus_4;
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            pc_reg <= 32'h0000_0000;
        end else if (pc_wen) begin
            pc_reg <= pc_next;
        end
    end
    
    assign pc_o = pc_reg;
    
    // =========================================================================
    // Instruction Memory Interface
    // =========================================================================
    
    assign imem_addr_o = pc_reg;
    
    // =========================================================================
    // Instruction Register
    // =========================================================================
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            instruction_reg <= 32'h0000_0013;  // NOP (ADDI x0, x0, 0)
        end else if (ir_wen) begin
            instruction_reg <= imem_data_i;
        end
    end
    
    // =========================================================================
    // Instruction Decoder
    // =========================================================================
    
    riscv_decoder u_decoder (
        .instruction_i    (instruction_reg),
        .opcode_o         (opcode),
        .rd_o             (rd),
        .rs1_o            (rs1),
        .rs2_o            (rs2),
        .funct3_o         (funct3),
        .funct7_o         (funct7),
        .imm_i_o          (imm_i),
        .imm_s_o          (imm_s),
        .imm_b_o          (imm_b),
        .imm_u_o          (imm_u),
        .imm_j_o          (imm_j),
        .is_rtype_o       (is_rtype),
        .is_itype_o       (is_itype),
        .is_stype_o       (is_stype),
        .is_btype_o       (is_btype),
        .is_utype_o       (is_utype),
        .is_jtype_o       (is_jtype),
        .is_load_o        (is_load),
        .is_store_o       (is_store),
        .is_branch_o      (is_branch),
        .is_jal_o         (is_jal),
        .is_jalr_o        (is_jalr),
        .is_lui_o         (is_lui),
        .is_auipc_o       (is_auipc),
        .is_op_o          (is_op),
        .is_op_imm_o      (is_op_imm),
        .is_system_o      (is_system),
        .illegal_instr_o  (illegal_instr)
    );
    
    // =========================================================================
    // Register File
    // =========================================================================
    
    // Register file write data selection
    always_comb begin
        case (regfile_src)
            2'b00:   regfile_wdata = alu_result;          // ALU result
            2'b01:   regfile_wdata = mem_rdata_extended;  // Memory data
            2'b10:   regfile_wdata = pc_plus_4;           // PC + 4 (for JAL/JALR)
            default: regfile_wdata = alu_result;
        endcase
    end
    
    riscv_regfile u_regfile (
        .clock        (clock),
        .reset        (reset),
        .rs1_addr_i   (rs1),
        .rs1_data_o   (rs1_data),
        .rs2_addr_i   (rs2),
        .rs2_data_o   (rs2_data),
        .rd_wen_i     (regfile_wen),
        .rd_addr_i    (rd),
        .rd_data_i    (regfile_wdata)
    );
    
    // =========================================================================
    // ALU
    // =========================================================================
    
    // ALU operand A selection
    always_comb begin
        case (alu_src_a)
            2'b00:   alu_operand_a = rs1_data;
            2'b01:   alu_operand_a = pc_reg;
            2'b10:   alu_operand_a = 32'b0;
            default: alu_operand_a = rs1_data;
        endcase
    end
    
    // ALU operand B selection
    always_comb begin
        case (alu_src_b)
            2'b00:   alu_operand_b = rs2_data;
            2'b01:   begin
                // Select appropriate immediate based on instruction type
                if (is_itype || is_jalr) alu_operand_b = imm_i;
                else if (is_stype) alu_operand_b = imm_s;
                else if (is_btype) alu_operand_b = imm_b;
                else if (is_utype) alu_operand_b = imm_u;
                else if (is_jtype) alu_operand_b = imm_j;
                else alu_operand_b = imm_i;
            end
            2'b10:   alu_operand_b = 32'd4;
            default: alu_operand_b = rs2_data;
        endcase
    end
    
    riscv_alu u_alu (
        .operand_a_i     (alu_operand_a),
        .operand_b_i     (alu_operand_b),
        .alu_op_i        (alu_op),
        .result_o        (alu_result),
        .zero_o          (alu_zero),
        .lt_signed_o     (alu_lt_signed),
        .lt_unsigned_o   (alu_lt_unsigned)
    );
    
    // =========================================================================
    // Data Memory Interface
    // =========================================================================
    
    assign mem_addr = alu_result;
    assign dmem_addr_o = mem_addr;
    assign dmem_wdata_o = rs2_data;  // Store data comes from rs2
    assign dmem_wen_o = mem_wen;
    assign dmem_ren_o = mem_ren;
    assign dmem_size_o = mem_size;
    
    // Memory read data extension (with proper byte/halfword alignment)
    always_comb begin
        case (mem_size)
            2'b00: begin  // Byte - select based on address[1:0]
                logic [7:0] byte_data;
                case (mem_addr[1:0])
                    2'b00: byte_data = dmem_rdata_i[7:0];
                    2'b01: byte_data = dmem_rdata_i[15:8];
                    2'b10: byte_data = dmem_rdata_i[23:16];
                    2'b11: byte_data = dmem_rdata_i[31:24];
                endcase
                
                if (mem_unsigned) begin
                    mem_rdata_extended = {24'b0, byte_data};
                end else begin
                    mem_rdata_extended = {{24{byte_data[7]}}, byte_data};
                end
            end
            2'b01: begin  // Halfword - select based on address[1]
                logic [15:0] half_data;
                case (mem_addr[1])
                    1'b0: half_data = dmem_rdata_i[15:0];
                    1'b1: half_data = dmem_rdata_i[31:16];
                endcase
                
                if (mem_unsigned) begin
                    mem_rdata_extended = {16'b0, half_data};
                end else begin
                    mem_rdata_extended = {{16{half_data[15]}}, half_data};
                end
            end
            2'b10: begin  // Word
                mem_rdata_extended = dmem_rdata_i;
            end
            default: begin
                mem_rdata_extended = dmem_rdata_i;
            end
        endcase
    end
    
    // =========================================================================
    // Control Unit
    // =========================================================================
    
    riscv_control u_control (
        .clock              (clock),
        .reset              (reset),
        .opcode_i           (opcode),
        .funct3_i           (funct3),
        .funct7_i           (funct7),
        .is_load_i          (is_load),
        .is_store_i         (is_store),
        .is_branch_i        (is_branch),
        .is_jal_i           (is_jal),
        .is_jalr_i          (is_jalr),
        .is_lui_i           (is_lui),
        .is_auipc_i         (is_auipc),
        .is_op_i            (is_op),
        .is_op_imm_i        (is_op_imm),
        .illegal_instr_i    (illegal_instr),
        .alu_zero_i         (alu_zero),
        .alu_lt_signed_i    (alu_lt_signed),
        .alu_lt_unsigned_i  (alu_lt_unsigned),
        .pc_wen_o           (pc_wen),
        .pc_src_o           (pc_src),
        .ir_wen_o           (ir_wen),
        .regfile_wen_o      (regfile_wen),
        .regfile_src_o      (regfile_src),
        .alu_src_a_o        (alu_src_a),
        .alu_src_b_o        (alu_src_b),
        .alu_op_o           (alu_op),
        .mem_wen_o          (mem_wen),
        .mem_ren_o          (mem_ren),
        .mem_size_o         (mem_size),
        .mem_unsigned_o     (mem_unsigned),
        .state_o            (state_o)
    );
    
    // Instruction memory read enable
    assign imem_ren_o = 1'b1;  // Always enabled for fetching

endmodule
