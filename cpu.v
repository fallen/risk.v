`include "rv32i.vh"
module rv32i(
input         rst,
input         clk,
output [31:0] mem_i_addr,
output        mem_i_rstrb,
input  [31:0] mem_i_rdata,
input         mem_i_rbusy,
output [31:0] mem_d_addr,
output [31:0] mem_d_wdata,
output  [3:0] mem_d_wmask,
output        mem_d_wstrb,
output        mem_d_rstrb,
input  [31:0] mem_d_rdata,
input         mem_d_rbusy,
input         mem_d_wbusy
);
reg [31:0] regfile [0:31];
reg [31:0] pc;
reg [63:0] csr_cycle;
reg [63:0] csr_timer;
reg [63:0] csr_instret;
reg [31:0] csr_mvendorid = 0;
reg [31:0] csr_marchid;
reg [31:0] csr_mimpid;
reg [31:0] csr_mhartid;
reg [31:0] csr_mstatus;
reg [31:0] csr_misa;
reg [31:0] csr_medeleg;
reg [31:0] csr_mideleg;
reg [31:0] csr_mie;
reg [31:0] csr_mtvec;
reg [31:0] csr_mcounteren;
reg [31:0] csr_mscratch;
reg [31:0] csr_mepc;
reg [31:0] csr_mcause;
reg [31:0] csr_mtval;
reg [31:0] csr_mip;

reg [5:0]   state;
wire        f_en, d_en, x_en, m_en, w_en;
assign f_en = state[0];
assign d_en = state[1];
assign x_en = state[2];
assign m_en = state[3];
assign w_en = state[4];
parameter FETCH_INSN = 1 << 0;
parameter DECODE_AND_REGFILE_FETCH = 1 << 1;
parameter EXECUTE = 1 << 2;
parameter MEMORY = 1 << 3;
parameter WRITE_BACK = 1 << 4;

/* fetch */
assign mem_i_rstrb = 1;
assign mem_i_addr = pc;
reg [31:0]  f_addr;
wire [31:0] f_insn;

assign f_insn = mem_i_rdata;

always @(posedge clk) begin if (f_en) begin
	$display("fetching pc = %x", pc);
	f_addr <= pc;
end end

/* decode internal wire */
wire [4:0]  opcode_w;
wire [6:0]  funct7_w;
wire [2:0]  funct3_w;
wire        invalid_w;
wire [4:0]  rs1_w, rs2_w, rd_w;
wire [31:0] reg1_w, reg2_w, imm_w;
wire [11:0] csr_w;
assign csr_w = f_insn[31:20];
assign reg1_w = regfile[rs1_w];
assign reg2_w = regfile[rs2_w];
/* decode output values */
reg [31:0]  d_addr;
reg [4:0]   d_opcode;
reg [31:0]  d_op_val1, d_op_val2;
reg [3:0]   d_alu_op;
reg [31:0]  d_bcu_val1, d_bcu_val2;
reg [2:0]   d_bcu_op;
reg [2:0]   d_lsu_op;
reg [11:0]  d_csr;
reg         d_csr_rd, d_csr_wr;
reg [31:0]  d_csr_val;
reg [4:0]   d_rd;

wire [31:0] csr_val =
	    (csr_w == `CSR_RDCYCLE) ? csr_cycle[31:0] :
	    (csr_w == `CSR_RDCYCLEH) ? csr_cycle[63:32] :
	    (csr_w == `CSR_RDTIME) ? csr_timer[31:0] :
	    (csr_w == `CSR_RDTIMEH) ? csr_timer[63:32] :
	    (csr_w == `CSR_RDINSTRET) ? csr_instret[31:0] :
	    (csr_w == `CSR_RDINSTRETH) ? csr_instret[63:32] :
	    (csr_w == `CSR_MVENDORID) ? csr_mvendorid :
	    (csr_w == `CSR_MARCHID) ? csr_marchid :
	    (csr_w == `CSR_MIMPID) ? csr_mimpid :
	    (csr_w == `CSR_MHARTID) ? csr_mhartid :
	    (csr_w == `CSR_MSCRATCH) ? csr_mscratch :
	    (csr_w == `CSR_MEPC) ? csr_mepc :
	    (csr_w == `CSR_MCAUSE) ? csr_mcause :
	    (csr_w == `CSR_MTVAL) ? csr_mtval :
	    (csr_w == `CSR_MIP) ? csr_mip :
	    0;

always @(posedge clk) begin if (d_en) begin
	d_addr <= f_addr;
	d_opcode <= opcode_w;
	if (opcode_w == `OP_ALUIMM) begin
		d_bcu_op <= `BCU_DISABLE;
		/* SRL/SRA both uses the same funct3 */
		d_alu_op <= (funct3_w == `ALU_SRL) ?
			    {funct7_w[5],funct3_w} :
			    {1'b0,funct3_w};
		d_op_val1 <= reg1_w;
		d_op_val2 <= imm_w;
		d_rd <= rd_w;
	end else if (opcode_w == `OP_ALU) begin
		d_bcu_op <= `BCU_DISABLE;
		d_alu_op <= {funct7_w[5],funct3_w};
		d_op_val1 <= reg1_w;
		d_op_val2 <= reg2_w;
		d_rd <= rd_w;
	end else if (opcode_w == `OP_JAL) begin
		d_bcu_op <= `BCU_TAKEN;
		d_alu_op <= `ALU_ADD;
		d_op_val1 <= f_addr;
		d_op_val2 <= imm_w;
		d_rd <= rd_w;
	end else if (opcode_w == `OP_JALR) begin
		d_bcu_op <= `BCU_TAKEN;
		d_alu_op <= `ALU_ADD;
		d_op_val1 <= reg1_w;
		d_op_val2 <= imm_w;
		d_rd <= rd_w;
	end else if (opcode_w == `OP_AUIPC) begin
		d_bcu_op <= `BCU_DISABLE;
		d_alu_op <= `ALU_ADD;
		d_op_val1 <= pc;
		d_op_val2 <= imm_w;
		d_rd <= rd_w;
	end else if (opcode_w == `OP_LUI) begin
		d_bcu_op <= `BCU_DISABLE;
		d_alu_op <= `ALU_ADD;
		d_op_val1 <= 0;
		d_op_val2 <= imm_w;
		d_rd <= rd_w;
	end else if (opcode_w == `OP_BRANCH) begin
		d_bcu_op <= funct3_w;
		d_bcu_val1 <= reg1_w;
		d_bcu_val2 <= reg2_w;
		d_alu_op <= `ALU_ADD;
		d_op_val1 <= f_addr;
		d_op_val2 <= imm_w;
		d_rd <= 0; /* do not write back */
	end else if (opcode_w == `OP_LOAD) begin
		d_lsu_op <= funct3_w;
		d_bcu_op <= `BCU_DISABLE;
		d_alu_op <= `ALU_ADD;
		d_op_val1 <= reg1_w;
		d_op_val2 <= imm_w;
		d_rd <= rd_w;
	end else if (opcode_w == `OP_STORE) begin
		d_lsu_op <= funct3_w;
		d_bcu_op <= `BCU_DISABLE;
		d_alu_op <= `ALU_ADD;
		d_op_val1 <= reg1_w;
		d_op_val2 <= imm_w;
		d_bcu_val2 <= reg2_w; /* store value */
		d_rd <= 0; /* do not write back */
	end else if (opcode_w == `OP_MISC) begin
		/* there is only fence in OP_MISC */
		/* insert a nop instruction */
		d_bcu_op <= `BCU_DISABLE;
		d_alu_op <= `ALU_ADD;
		d_rd <= 0; /* do not write back */
	end
	if (opcode_w == `OP_SYSTEM) begin
		if ({rs1_w,funct3_w,rd_w} == 0) begin
			case (f_insn[31:20])
			12'b000000000000: $display("ECALL  @%x", f_addr);
			12'b000000000001: $display("EBREAK @%x", f_addr);
			12'b000000000010: $display("URET   @%x", f_addr);
			12'b000100000010: $display("SRET   @%x", f_addr);
			12'b001100000010: $display("MRET   @%x", f_addr);
			12'b000100000101: $display("WFI    @%x", f_addr);
			default: $display("illegal insn @%x", f_addr);
			endcase
		end
		d_csr_rd <= !((funct3_w[1:0] == `CSR_RW) && !rd_w);
		d_csr_wr <= !((funct3_w[1:0] == `CSR_RS ||
			       funct3_w[1:0] == `CSR_RC) && !rs1_w);
		d_csr <= csr_w;
		d_csr_val <= csr_val;
		d_rd <= rd_w;
		d_alu_op <= (funct3_w[1:0] == `CSR_RS) ? `ALU_OR :
			    (funct3_w[1:0] == `CSR_RC) ? `ALU_ANDN :
			    `ALU_OR;
		d_op_val1 <= (funct3_w[1:0] == `CSR_RW) ? 0 : csr_val;
		d_op_val2 <= (funct3_w[2]) ? rs1_w : reg1_w;
		d_bcu_op <= `BCU_DISABLE;
	end else begin
		d_csr_rd <= 0;
		d_csr_wr <= 0;
	end
end end

/* execute output */
reg [31:0]  x_out, x_npc;
reg [4:0]   x_rd;
reg [2:0]   x_lsu_op;
reg [31:0]  x_lsu_val;
reg [11:0]  x_csr;
reg         x_csr_wr;
reg         x_csr_rd;
reg [31:0]  x_csr_val;
reg         x_taken, x_link, x_load, x_store;

always @(posedge clk) begin if (x_en) begin
	case (d_bcu_op)
	`COMP_BEQ:	x_taken <= d_bcu_val1 == d_bcu_val2;
	`COMP_BNE:	x_taken <= d_bcu_val1 != d_bcu_val2;
	`COMP_BLT:	x_taken <= $signed(d_bcu_val1) < $signed(d_bcu_val2);
	`COMP_BGE:	x_taken <= $signed(d_bcu_val1) >= $signed(d_bcu_val2);
	`COMP_BLTU:	x_taken <= d_bcu_val1 < d_bcu_val2;
	`COMP_BGEU:	x_taken <= d_bcu_val1 >= d_bcu_val2;
	`BCU_TAKEN:	x_taken <= 1;
	default:	x_taken <= 0;
	endcase
	case (d_alu_op)
	`ALU_ADD:	x_out <= d_op_val1 + d_op_val2;
	`ALU_SUB:	x_out <= d_op_val1 - d_op_val2;
	`ALU_SLL:	x_out <= d_op_val1 << d_op_val2[4:0];
	`ALU_SLT:	x_out <= $signed(d_op_val1) < $signed(d_op_val2);
	`ALU_SLTU:	x_out <= d_op_val1 < d_op_val2;
	`ALU_XOR:	x_out <= d_op_val1 ^ d_op_val2;
	`ALU_SRL:	x_out <= d_op_val1 >> d_op_val2[4:0];
	`ALU_SRA:	x_out <= $signed(d_op_val1) >>> d_op_val2[4:0];
	`ALU_OR:	x_out <= d_op_val1 | d_op_val2;
	`ALU_AND:	x_out <= d_op_val1 & d_op_val2;
	`ALU_ANDN:	x_out <= d_op_val1 & ~d_op_val2;
	default:	x_out <= 0;
	endcase
	x_link <= d_opcode == `OP_JAL || d_opcode == `OP_JALR;
	x_lsu_op <= d_lsu_op;
	case (d_lsu_op)
	`LSU_SB:	x_lsu_val <= {4{d_bcu_val2[7:0]}};
	`LSU_SH:	x_lsu_val <= {2{d_bcu_val2[15:0]}};
	`LSU_SW:	x_lsu_val <= d_bcu_val2;
	endcase
	x_load <= d_opcode == `OP_LOAD;
	x_store <= d_opcode == `OP_STORE;
	x_npc <= d_addr + 4;
	x_rd <= d_rd;

	x_csr_wr <= d_csr_wr;
	x_csr_rd <= d_csr_rd;
	x_csr_val <= d_csr_val;
	x_csr <= d_csr;
end end

/* memory output */
reg [31:0]  m_out, m_npc;
reg [4:0]   m_rd;
reg [2:0]   m_lsu_op;
reg         m_taken, m_link, m_load;
reg [11:0]  m_csr;
reg         m_csr_wr;
reg [31:0]  m_csr_val;

wire [31:0] lsu_out;
wire [7:0] lsu_out_byte;
wire [15:0] lsu_out_half;

assign mem_d_addr = x_out;
assign mem_d_wdata = x_lsu_val;
assign mem_d_wmask = (x_lsu_op == `LSU_SB) ? 4'b0001 << x_out[1:0] :
		     (x_lsu_op == `LSU_SH) ? 4'b0011 << 2*x_out[1] :
		     4'b1111;
assign mem_d_wstrb = m_en && x_store;
assign mem_d_rstrb = m_en && x_load;
assign lsu_out = mem_d_rdata;
assign lsu_out_byte = (mem_d_addr[1:0] == 2'b00) ? lsu_out[7:0] :
		      (mem_d_addr[1:0] == 2'b01) ? lsu_out[15:8] :
		      (mem_d_addr[1:0] == 2'b10) ? lsu_out[23:16] :
		      lsu_out[31:24];
assign lsu_out_half = mem_d_addr[1] ? lsu_out[31:16] : lsu_out[15:0];

always @(posedge clk) begin if (m_en) begin
	if (x_store) begin
		$display("store @%x: %x", x_out, x_lsu_val);
	end
	if (x_csr_rd) begin
		m_out <= x_csr_val;
	end else begin
		m_out <= x_out;
	end
	m_csr_val <= x_out;
	m_csr_wr <= x_csr_wr;
	m_csr <= x_csr;

	m_npc <= x_npc;
	m_rd <= x_rd;
	m_link <= x_link;
	m_taken <= x_taken;
	m_load <= x_load;
	m_lsu_op <= x_lsu_op;
end end

always @(posedge clk) begin if (w_en) begin
	if (m_rd != 0 && m_load) begin
		$display("load  @%x: %x", m_out, lsu_out);
		case (m_lsu_op)
		`LSU_LB:	regfile[m_rd] <= $signed(lsu_out_byte);
		`LSU_LH:	regfile[m_rd] <= $signed(lsu_out_half);
		`LSU_LW:	regfile[m_rd] <= lsu_out;
		`LSU_LBU:	regfile[m_rd] <= lsu_out_byte;
		`LSU_LHU:	regfile[m_rd] <= lsu_out_half;
		default:	regfile[m_rd] <= 0; /* invalid */
		endcase
	end else if (m_rd != 0) begin
		regfile[m_rd] <= (m_link) ? m_npc : m_out;
	end
	if (m_csr_wr) begin
		case (m_csr)
		`CSR_MSCRATCH:	csr_mscratch <= m_csr_val;
		`CSR_MEPC:	csr_mepc     <= m_csr_val;
		`CSR_MCAUSE:	csr_mcause   <= m_csr_val;
		`CSR_MTVAL:	csr_mtval    <= m_csr_val;
		`CSR_MIP:	csr_mip      <= m_csr_val;
		endcase
	end
	if (m_taken) begin
		$display("branch taken to %x", m_out);
		pc <= m_out;
	end else begin
		pc <= m_npc;
	end
end end

decode decode(f_insn, opcode_w, funct7_w, funct3_w, invalid, rd_w, rs1_w, rs2_w, imm_w);

integer i;
always @(posedge clk) begin
	if (rst) begin
		state <= FETCH_INSN;
		pc <= 0;
		d_opcode <= 0;
		d_op_val1 <= 0;
		d_op_val2 <= 0;
		d_alu_op <= 0;
		d_rd <= 0;
		x_rd <= 0;
		x_taken <= 0;
		x_link <= 0;
		x_lsu_val <= 0;
		x_lsu_op <= 0;
		x_out <= 0;
		for (i = 0; i < 32; i = i + 1) regfile[i] <= 0;
	end else begin
		state <= (state << 1) | w_en;
	end
end

always @(posedge clk) begin
	if (rst) begin
		csr_cycle <= 0;
		csr_timer <= 0;
		csr_instret <= 0;
		csr_mvendorid <= 0;
		csr_marchid <= 0;
		csr_mimpid <= 0;
		csr_mhartid <= 0;
		csr_mstatus <= 0;
		csr_misa <= 0;
		csr_medeleg <= 0;
		csr_mideleg <= 0;
		csr_mie <= 0;
		csr_mtvec <= 0;
		csr_mcounteren <= 0;
		csr_mscratch <= 0;
		csr_mepc <= 0;
		csr_mcause <= 0;
		csr_mtval <= 0;
		csr_mip <= 0;
	end else begin
		csr_cycle <= csr_cycle + 1;
	end
end

endmodule
