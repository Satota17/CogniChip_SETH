/*
 * PicoRV32 - Simplified Single-File Implementation
 * Compatible with golden testbench
 *
 * This is a simplified implementation for testing purposes.
 * For a full-featured implementation, use the original PicoRV32.
 */

module picorv32 #(
    parameter ENABLE_COUNTERS = 1,
    parameter ENABLE_COUNTERS64 = 1,
    parameter ENABLE_REGS_16_31 = 1,
    parameter ENABLE_REGS_DUALPORT = 1,
    parameter LATCHED_MEM_RDATA = 0,
    parameter TWO_STAGE_SHIFT = 1,
    parameter BARREL_SHIFTER = 0,
    parameter TWO_CYCLE_COMPARE = 0,
    parameter TWO_CYCLE_ALU = 0,
    parameter COMPRESSED_ISA = 0,
    parameter CATCH_MISALIGN = 1,
    parameter CATCH_ILLINSN = 1,
    parameter ENABLE_PCPI = 0,
    parameter ENABLE_MUL = 0,
    parameter ENABLE_FAST_MUL = 0,
    parameter ENABLE_DIV = 0,
    parameter ENABLE_IRQ = 0,
    parameter ENABLE_IRQ_QREGS = 1,
    parameter ENABLE_IRQ_TIMER = 1,
    parameter ENABLE_TRACE = 0,
    parameter REGS_INIT_ZERO = 0,
    parameter MASKED_IRQ = 32'h00000000,
    parameter LATCHED_IRQ = 32'hFFFFFFFF,
    parameter PROGADDR_RESET = 32'h00000000,
    parameter PROGADDR_IRQ = 32'h00000010,
    parameter STACKADDR = 32'hFFFFFFFF
) (
    input clk,
    input resetn,
    output reg trap,
    
    // Memory interface
    output reg        mem_valid,
    output reg        mem_instr,
    input             mem_ready,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [ 3:0] mem_wstrb,
    input      [31:0] mem_rdata,
    
    // Look-ahead interface
    output reg        mem_la_read,
    output reg        mem_la_write,
    output reg [31:0] mem_la_addr,
    output reg [31:0] mem_la_wdata,
    output reg [ 3:0] mem_la_wstrb,
    
    // PCPI interface (optional)
    output reg        pcpi_valid,
    output reg [31:0] pcpi_insn,
    output reg [31:0] pcpi_rs1,
    output reg [31:0] pcpi_rs2,
    input             pcpi_wr,
    input      [31:0] pcpi_rd,
    input             pcpi_wait,
    input             pcpi_ready,
    
    // IRQ interface (optional)
    input      [31:0] irq,
    output reg [31:0] eoi,
    
    // Trace interface (optional)
    output reg        trace_valid,
    output reg [35:0] trace_data
);

    // Internal signals
    reg [31:0] pc;
    reg [31:0] next_pc;
    reg [31:0] instruction;
    reg [31:0] regs [0:31];
    
    // FSM states
    localparam STATE_FETCH    = 3'd0;
    localparam STATE_DECODE   = 3'd1;
    localparam STATE_EXECUTE  = 3'd2;
    localparam STATE_MEMORY   = 3'd3;
    localparam STATE_WRITEBACK = 3'd4;
    localparam STATE_TRAP     = 3'd5;
    
    reg [2:0] state;
    
    // Decoded instruction fields
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd     = instruction[11:7];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    
    // Immediate generation
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};
    wire [31:0] imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    wire [31:0] imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire [31:0] imm_u = {instruction[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    
    // ALU result
    reg [31:0] alu_result;
    reg [31:0] mem_result;
    
    // Initialize registers
    integer i;
    initial begin
        if (REGS_INIT_ZERO) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] = 32'h00000000;
            end
        end
        pc = PROGADDR_RESET;
        state = STATE_FETCH;
        trap = 0;
        mem_valid = 0;
        mem_instr = 0;
    end
    
    // Main CPU FSM
    always @(posedge clk) begin
        if (!resetn) begin
            pc <= PROGADDR_RESET;
            state <= STATE_FETCH;
            trap <= 0;
            mem_valid <= 0;
            mem_instr <= 0;
            mem_wstrb <= 4'b0000;
        end else begin
            case (state)
                STATE_FETCH: begin
                    // Fetch instruction
                    mem_valid <= 1;
                    mem_instr <= 1;
                    mem_addr  <= pc;
                    mem_wstrb <= 4'b0000;
                    
                    if (mem_ready) begin
                        instruction <= mem_rdata;
                        mem_valid <= 0;
                        mem_instr <= 0;
                        state <= STATE_DECODE;
                    end
                end
                
                STATE_DECODE: begin
                    // Decode is combinational, move to execute
                    state <= STATE_EXECUTE;
                end
                
                STATE_EXECUTE: begin
                    // Execute ALU operations
                    case (opcode)
                        7'b0110011: begin // R-type (ADD, SUB, etc.)
                            case (funct3)
                                3'b000: alu_result <= (funct7[5]) ? (regs[rs1] - regs[rs2]) : (regs[rs1] + regs[rs2]);
                                3'b001: alu_result <= regs[rs1] << regs[rs2][4:0];
                                3'b010: alu_result <= ($signed(regs[rs1]) < $signed(regs[rs2])) ? 32'd1 : 32'd0;
                                3'b011: alu_result <= (regs[rs1] < regs[rs2]) ? 32'd1 : 32'd0;
                                3'b100: alu_result <= regs[rs1] ^ regs[rs2];
                                3'b101: alu_result <= (funct7[5]) ? ($signed(regs[rs1]) >>> regs[rs2][4:0]) : (regs[rs1] >> regs[rs2][4:0]);
                                3'b110: alu_result <= regs[rs1] | regs[rs2];
                                3'b111: alu_result <= regs[rs1] & regs[rs2];
                            endcase
                            state <= STATE_WRITEBACK;
                        end
                        
                        7'b0010011: begin // I-type (ADDI, etc.)
                            case (funct3)
                                3'b000: alu_result <= regs[rs1] + imm_i;
                                3'b010: alu_result <= ($signed(regs[rs1]) < $signed(imm_i)) ? 32'd1 : 32'd0;
                                3'b011: alu_result <= (regs[rs1] < imm_i) ? 32'd1 : 32'd0;
                                3'b100: alu_result <= regs[rs1] ^ imm_i;
                                3'b110: alu_result <= regs[rs1] | imm_i;
                                3'b111: alu_result <= regs[rs1] & imm_i;
                                3'b001: alu_result <= regs[rs1] << imm_i[4:0];
                                3'b101: alu_result <= (funct7[5]) ? ($signed(regs[rs1]) >>> imm_i[4:0]) : (regs[rs1] >> imm_i[4:0]);
                            endcase
                            state <= STATE_WRITEBACK;
                        end
                        
                        7'b0000011: begin // LOAD
                            mem_valid <= 1;
                            mem_instr <= 0;
                            mem_addr  <= regs[rs1] + imm_i;
                            mem_wstrb <= 4'b0000;
                            state <= STATE_MEMORY;
                        end
                        
                        7'b0100011: begin // STORE
                            mem_valid <= 1;
                            mem_instr <= 0;
                            mem_addr  <= regs[rs1] + imm_s;
                            mem_wdata <= regs[rs2];
                            mem_wstrb <= 4'b1111; // Simplified: always word store
                            state <= STATE_MEMORY;
                        end
                        
                        7'b1100011: begin // BRANCH
                            case (funct3)
                                3'b000: next_pc <= (regs[rs1] == regs[rs2]) ? (pc + imm_b) : (pc + 4);
                                3'b001: next_pc <= (regs[rs1] != regs[rs2]) ? (pc + imm_b) : (pc + 4);
                                3'b100: next_pc <= ($signed(regs[rs1]) < $signed(regs[rs2])) ? (pc + imm_b) : (pc + 4);
                                3'b101: next_pc <= ($signed(regs[rs1]) >= $signed(regs[rs2])) ? (pc + imm_b) : (pc + 4);
                                3'b110: next_pc <= (regs[rs1] < regs[rs2]) ? (pc + imm_b) : (pc + 4);
                                3'b111: next_pc <= (regs[rs1] >= regs[rs2]) ? (pc + imm_b) : (pc + 4);
                                default: next_pc <= pc + 4;
                            endcase
                            pc <= next_pc;
                            state <= STATE_FETCH;
                        end
                        
                        7'b1101111: begin // JAL
                            alu_result <= pc + 4;
                            pc <= pc + imm_j;
                            state <= STATE_WRITEBACK;
                        end
                        
                        7'b1100111: begin // JALR
                            alu_result <= pc + 4;
                            pc <= (regs[rs1] + imm_i) & ~32'd1;
                            state <= STATE_WRITEBACK;
                        end
                        
                        7'b0110111: begin // LUI
                            alu_result <= imm_u;
                            state <= STATE_WRITEBACK;
                        end
                        
                        7'b0010111: begin // AUIPC
                            alu_result <= pc + imm_u;
                            state <= STATE_WRITEBACK;
                        end
                        
                        default: begin
                            trap <= 1;
                            state <= STATE_TRAP;
                        end
                    endcase
                end
                
                STATE_MEMORY: begin
                    if (mem_ready) begin
                        if (mem_wstrb == 4'b0000) begin
                            // Load
                            mem_result <= mem_rdata;
                        end
                        mem_valid <= 0;
                        mem_wstrb <= 4'b0000;
                        state <= STATE_WRITEBACK;
                    end
                end
                
                STATE_WRITEBACK: begin
                    if (rd != 5'h00) begin
                        if (opcode == 7'b0000011) begin // LOAD
                            regs[rd] <= mem_result;
                        end else if (opcode != 7'b0100011) begin // Not STORE
                            regs[rd] <= alu_result;
                        end
                    end
                    
                    // Increment PC for most instructions
                    if (opcode != 7'b1100011 && opcode != 7'b1101111 && opcode != 7'b1100111) begin
                        pc <= pc + 4;
                    end
                    
                    state <= STATE_FETCH;
                end
                
                STATE_TRAP: begin
                    // Halt on trap
                    trap <= 1;
                end
            endcase
        end
    end
    
    // Hardwire x0 to zero
    always @(posedge clk) begin
        regs[0] <= 32'h00000000;
    end
    
    // Look-ahead signals (unused in simplified version)
    always @(*) begin
        mem_la_read = 0;
        mem_la_write = 0;
        mem_la_addr = 32'h0;
        mem_la_wdata = 32'h0;
        mem_la_wstrb = 4'b0000;
        pcpi_valid = 0;
        pcpi_insn = 32'h0;
        pcpi_rs1 = 32'h0;
        pcpi_rs2 = 32'h0;
        eoi = 32'h0;
        trace_valid = 0;
        trace_data = 36'h0;
    end

endmodule

/*
 * PicoRV32 AXI4-Lite Wrapper
 * Wraps the native memory interface with AXI4-Lite protocol
 */
module picorv32_axi #(
    parameter ENABLE_COUNTERS = 1,
    parameter ENABLE_COUNTERS64 = 1,
    parameter ENABLE_REGS_16_31 = 1,
    parameter ENABLE_REGS_DUALPORT = 1,
    parameter LATCHED_MEM_RDATA = 0,
    parameter TWO_STAGE_SHIFT = 1,
    parameter BARREL_SHIFTER = 0,
    parameter TWO_CYCLE_COMPARE = 0,
    parameter TWO_CYCLE_ALU = 0,
    parameter COMPRESSED_ISA = 0,
    parameter CATCH_MISALIGN = 1,
    parameter CATCH_ILLINSN = 1,
    parameter ENABLE_PCPI = 0,
    parameter ENABLE_MUL = 0,
    parameter ENABLE_FAST_MUL = 0,
    parameter ENABLE_DIV = 0,
    parameter ENABLE_IRQ = 0,
    parameter ENABLE_IRQ_QREGS = 1,
    parameter ENABLE_IRQ_TIMER = 1,
    parameter ENABLE_TRACE = 0,
    parameter REGS_INIT_ZERO = 0,
    parameter MASKED_IRQ = 32'h00000000,
    parameter LATCHED_IRQ = 32'hFFFFFFFF,
    parameter PROGADDR_RESET = 32'h00000000,
    parameter PROGADDR_IRQ = 32'h00000010,
    parameter STACKADDR = 32'hFFFFFFFF
) (
    input clk,
    input resetn,
    output trap,
    
    // AXI4-Lite Master Interface
    output        mem_axi_awvalid,
    input         mem_axi_awready,
    output [31:0] mem_axi_awaddr,
    output [ 2:0] mem_axi_awprot,
    
    output        mem_axi_wvalid,
    input         mem_axi_wready,
    output [31:0] mem_axi_wdata,
    output [ 3:0] mem_axi_wstrb,
    
    input         mem_axi_bvalid,
    output        mem_axi_bready,
    
    output        mem_axi_arvalid,
    input         mem_axi_arready,
    output [31:0] mem_axi_araddr,
    output [ 2:0] mem_axi_arprot,
    
    input         mem_axi_rvalid,
    output        mem_axi_rready,
    input  [31:0] mem_axi_rdata,
    
    // PCPI interface (optional)
    output        pcpi_valid,
    output [31:0] pcpi_insn,
    output [31:0] pcpi_rs1,
    output [31:0] pcpi_rs2,
    input         pcpi_wr,
    input  [31:0] pcpi_rd,
    input         pcpi_wait,
    input         pcpi_ready,
    
    // IRQ interface (optional)
    input  [31:0] irq,
    output [31:0] eoi,
    
    // Trace interface (optional)
    output        trace_valid,
    output [35:0] trace_data
);

    // Native memory interface signals
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire [31:0] mem_rdata;
    
    // Instantiate the core CPU
    picorv32 #(
        .ENABLE_COUNTERS(ENABLE_COUNTERS),
        .ENABLE_COUNTERS64(ENABLE_COUNTERS64),
        .ENABLE_REGS_16_31(ENABLE_REGS_16_31),
        .ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
        .LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
        .TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
        .BARREL_SHIFTER(BARREL_SHIFTER),
        .TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
        .TWO_CYCLE_ALU(TWO_CYCLE_ALU),
        .COMPRESSED_ISA(COMPRESSED_ISA),
        .CATCH_MISALIGN(CATCH_MISALIGN),
        .CATCH_ILLINSN(CATCH_ILLINSN),
        .ENABLE_PCPI(ENABLE_PCPI),
        .ENABLE_MUL(ENABLE_MUL),
        .ENABLE_FAST_MUL(ENABLE_FAST_MUL),
        .ENABLE_DIV(ENABLE_DIV),
        .ENABLE_IRQ(ENABLE_IRQ),
        .ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
        .ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
        .ENABLE_TRACE(ENABLE_TRACE),
        .REGS_INIT_ZERO(REGS_INIT_ZERO),
        .MASKED_IRQ(MASKED_IRQ),
        .LATCHED_IRQ(LATCHED_IRQ),
        .PROGADDR_RESET(PROGADDR_RESET),
        .PROGADDR_IRQ(PROGADDR_IRQ),
        .STACKADDR(STACKADDR)
    ) cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .mem_la_read(),
        .mem_la_write(),
        .mem_la_addr(),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready),
        .irq(irq),
        .eoi(eoi),
        .trace_valid(trace_valid),
        .trace_data(trace_data)
    );
    
    // AXI4-Lite adapter
    reg        axi_awvalid_reg;
    reg [31:0] axi_awaddr_reg;
    reg        axi_wvalid_reg;
    reg [31:0] axi_wdata_reg;
    reg [ 3:0] axi_wstrb_reg;
    reg        axi_bready_reg;
    reg        axi_arvalid_reg;
    reg [31:0] axi_araddr_reg;
    reg        axi_rready_reg;
    reg        mem_ready_reg;
    reg [31:0] mem_rdata_reg;
    
    assign mem_axi_awvalid = axi_awvalid_reg;
    assign mem_axi_awaddr  = axi_awaddr_reg;
    assign mem_axi_awprot  = 3'b000;
    assign mem_axi_wvalid  = axi_wvalid_reg;
    assign mem_axi_wdata   = axi_wdata_reg;
    assign mem_axi_wstrb   = axi_wstrb_reg;
    assign mem_axi_bready  = axi_bready_reg;
    assign mem_axi_arvalid = axi_arvalid_reg;
    assign mem_axi_araddr  = axi_araddr_reg;
    assign mem_axi_arprot  = 3'b000;
    assign mem_axi_rready  = axi_rready_reg;
    assign mem_ready       = mem_ready_reg;
    assign mem_rdata       = mem_rdata_reg;
    
    localparam AXI_IDLE = 3'd0;
    localparam AXI_WRITE_ADDR = 3'd1;
    localparam AXI_WRITE_RESP = 3'd2;
    localparam AXI_READ_ADDR = 3'd3;
    localparam AXI_READ_DATA = 3'd4;
    
    reg [2:0] axi_state;
    
    always @(posedge clk) begin
        if (!resetn) begin
            axi_state <= AXI_IDLE;
            axi_awvalid_reg <= 0;
            axi_wvalid_reg <= 0;
            axi_bready_reg <= 0;
            axi_arvalid_reg <= 0;
            axi_rready_reg <= 0;
            mem_ready_reg <= 0;
        end else begin
            mem_ready_reg <= 0;
            
            case (axi_state)
                AXI_IDLE: begin
                    if (mem_valid && !mem_ready_reg) begin
                        if (mem_wstrb != 4'b0000) begin
                            // Write
                            axi_awvalid_reg <= 1;
                            axi_awaddr_reg <= mem_addr;
                            axi_wvalid_reg <= 1;
                            axi_wdata_reg <= mem_wdata;
                            axi_wstrb_reg <= mem_wstrb;
                            axi_state <= AXI_WRITE_ADDR;
                        end else begin
                            // Read
                            axi_arvalid_reg <= 1;
                            axi_araddr_reg <= mem_addr;
                            axi_state <= AXI_READ_ADDR;
                        end
                    end
                end
                
                AXI_WRITE_ADDR: begin
                    if (mem_axi_awready) axi_awvalid_reg <= 0;
                    if (mem_axi_wready) axi_wvalid_reg <= 0;
                    
                    if ((!axi_awvalid_reg || mem_axi_awready) && 
                        (!axi_wvalid_reg || mem_axi_wready)) begin
                        axi_bready_reg <= 1;
                        axi_state <= AXI_WRITE_RESP;
                    end
                end
                
                AXI_WRITE_RESP: begin
                    if (mem_axi_bvalid) begin
                        axi_bready_reg <= 0;
                        mem_ready_reg <= 1;
                        axi_state <= AXI_IDLE;
                    end
                end
                
                AXI_READ_ADDR: begin
                    if (mem_axi_arready) begin
                        axi_arvalid_reg <= 0;
                        axi_rready_reg <= 1;
                        axi_state <= AXI_READ_DATA;
                    end
                end
                
                AXI_READ_DATA: begin
                    if (mem_axi_rvalid) begin
                        mem_rdata_reg <= mem_axi_rdata;
                        axi_rready_reg <= 0;
                        mem_ready_reg <= 1;
                        axi_state <= AXI_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
