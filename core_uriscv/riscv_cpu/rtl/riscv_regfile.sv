// =============================================================================
// RISC-V 32-bit Register File
// =============================================================================
// 32 x 32-bit integer registers (x0-x31)
// x0 is hardwired to zero
// 2 read ports, 1 write port
// =============================================================================

module riscv_regfile (
    input  logic        clock,
    input  logic        reset,
    
    // Read port 1
    input  logic [4:0]  rs1_addr_i,
    output logic [31:0] rs1_data_o,
    
    // Read port 2
    input  logic [4:0]  rs2_addr_i,
    output logic [31:0] rs2_data_o,
    
    // Write port
    input  logic        rd_wen_i,
    input  logic [4:0]  rd_addr_i,
    input  logic [31:0] rd_data_i
);

    // 32 x 32-bit register array
    logic [31:0] registers [31:0];
    
    // Read port 1 (combinational)
    assign rs1_data_o = (rs1_addr_i == 5'b0) ? 32'b0 : registers[rs1_addr_i];
    
    // Read port 2 (combinational)
    assign rs2_data_o = (rs2_addr_i == 5'b0) ? 32'b0 : registers[rs2_addr_i];
    
    // Write port (synchronous)
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            // Initialize all registers to zero
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 32'b0;
            end
        end else if (rd_wen_i && (rd_addr_i != 5'b0)) begin
            // Write to register (x0 is always zero, ignore writes)
            registers[rd_addr_i] <= rd_data_i;
        end
    end

endmodule
