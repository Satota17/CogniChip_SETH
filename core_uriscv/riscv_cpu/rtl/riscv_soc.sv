// =============================================================================
// RISC-V System-on-Chip (SoC) Top Level
// =============================================================================
// Integrates the RISC-V CPU core with instruction and data memories
// Simple Harvard architecture with separate instruction and data memory spaces
// =============================================================================

module riscv_soc #(
    parameter IMEM_SIZE = 4096,  // Instruction memory size in bytes
    parameter DMEM_SIZE = 4096,  // Data memory size in bytes
    parameter LOAD_PROGRAM = 1   // Load built-in test program (0=disabled, 1=enabled)
) (
    input  logic        clock,
    input  logic        reset,
    
    // Debug outputs
    output logic [31:0] pc_o,
    output logic [2:0]  state_o,
    output logic [31:0] debug_reg_x1_o,
    output logic [31:0] debug_reg_x2_o
);

    // =========================================================================
    // Memory Size Calculations
    // =========================================================================
    
    localparam IMEM_ADDR_WIDTH = $clog2(IMEM_SIZE/4);
    localparam DMEM_ADDR_WIDTH = $clog2(DMEM_SIZE/4);
    
    // =========================================================================
    // CPU Interface Signals
    // =========================================================================
    
    // Instruction memory interface
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ren;
    
    // Data memory interface
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic        dmem_wen;
    logic        dmem_ren;
    logic [1:0]  dmem_size;
    
    // =========================================================================
    // Instruction Memory (ROM/RAM)
    // =========================================================================
    
    logic [31:0] imem [0:IMEM_SIZE/4-1];
    logic [IMEM_ADDR_WIDTH-1:0] imem_addr_word;
    
    assign imem_addr_word = imem_addr[IMEM_ADDR_WIDTH+1:2];
    
    always_ff @(posedge clock) begin
        if (imem_ren) begin
            imem_rdata <= imem[imem_addr_word];
        end
    end
    
    // Initialize instruction memory with a simple program (if enabled)
    initial begin
        // Initialize all memory to NOP (ADDI x0, x0, 0)
        for (int i = 0; i < IMEM_SIZE/4; i++) begin
            imem[i] = 32'h00000013;
        end
        
        if (LOAD_PROGRAM) begin
            // Simple test program
            // x1 = 10 (ADDI x1, x0, 10)
            imem[0] = 32'h00A00093;
            
            // x2 = 20 (ADDI x2, x0, 20)
            imem[1] = 32'h01400113;
            
            // x3 = x1 + x2 (ADD x3, x1, x2)
            imem[2] = 32'h002081B3;
            
            // x4 = x1 - x2 (SUB x4, x1, x2)
            imem[3] = 32'h40208233;
            
            // x5 = x1 & x2 (AND x5, x1, x2)
            imem[4] = 32'h0020F2B3;
            
            // x6 = x1 | x2 (OR x6, x1, x2)
            imem[5] = 32'h0020E333;
            
            // x7 = x1 ^ x2 (XOR x7, x1, x2)
            imem[6] = 32'h0020C3B3;
            
            // Infinite loop: JAL x0, -4 (jump back to previous instruction)
            imem[7] = 32'hFFDFF06F;
        end
    end
    
    // =========================================================================
    // Data Memory (RAM)
    // =========================================================================
    
    logic [31:0] dmem [0:DMEM_SIZE/4-1];
    logic [DMEM_ADDR_WIDTH-1:0] dmem_addr_word;
    
    assign dmem_addr_word = dmem_addr[DMEM_ADDR_WIDTH+1:2];
    
    // Data memory read
    always_ff @(posedge clock) begin
        if (dmem_ren) begin
            dmem_rdata <= dmem[dmem_addr_word];
        end
    end
    
    // Data memory write with byte/halfword/word support
    always_ff @(posedge clock) begin
        if (dmem_wen) begin
            case (dmem_size)
                2'b00: begin  // Byte
                    case (dmem_addr[1:0])
                        2'b00: dmem[dmem_addr_word][7:0]   <= dmem_wdata[7:0];
                        2'b01: dmem[dmem_addr_word][15:8]  <= dmem_wdata[7:0];
                        2'b10: dmem[dmem_addr_word][23:16] <= dmem_wdata[7:0];
                        2'b11: dmem[dmem_addr_word][31:24] <= dmem_wdata[7:0];
                    endcase
                end
                2'b01: begin  // Halfword
                    case (dmem_addr[1])
                        1'b0: dmem[dmem_addr_word][15:0]  <= dmem_wdata[15:0];
                        1'b1: dmem[dmem_addr_word][31:16] <= dmem_wdata[15:0];
                    endcase
                end
                2'b10: begin  // Word
                    dmem[dmem_addr_word] <= dmem_wdata;
                end
                default: begin
                    dmem[dmem_addr_word] <= dmem_wdata;
                end
            endcase
        end
    end
    
    // Initialize data memory
    initial begin
        for (int i = 0; i < DMEM_SIZE/4; i++) begin
            dmem[i] = 32'h0000_0000;
        end
    end
    
    // =========================================================================
    // RISC-V CPU Core Instantiation
    // =========================================================================
    
    riscv_cpu_core u_cpu (
        .clock         (clock),
        .reset         (reset),
        .imem_addr_o   (imem_addr),
        .imem_data_i   (imem_rdata),
        .imem_ren_o    (imem_ren),
        .dmem_addr_o   (dmem_addr),
        .dmem_wdata_o  (dmem_wdata),
        .dmem_rdata_i  (dmem_rdata),
        .dmem_wen_o    (dmem_wen),
        .dmem_ren_o    (dmem_ren),
        .dmem_size_o   (dmem_size),
        .pc_o          (pc_o),
        .state_o       (state_o)
    );
    
    // =========================================================================
    // Debug Outputs - Access Register File Values
    // =========================================================================
    
    assign debug_reg_x1_o = u_cpu.u_regfile.registers[1];
    assign debug_reg_x2_o = u_cpu.u_regfile.registers[2];

endmodule
