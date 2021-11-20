module Riskv (input clk,
	    input reset,
	    output [31:2] iBusWishbone_ADR,
	    output [3:0] iBusWishbone_SEL,
	    output iBusWishbone_CYC,
	    output iBusWishbone_STB,
	    input [31:0] iBusWishbone_DAT_MISO,
	    input iBusWishbone_ACK,
	    input iBusWishbone_ERR,

	    output [31:2] dBusWishbone_ADR,
	    output [31:0] dBusWishbone_DAT_MOSI,
	    output [3:0] dBusWishbone_SEL,
	    output dBusWishbone_CYC,
	    output dBusWishbone_STB,
	    output dBusWishbone_WE,
	    input [31:0] dBusWishbone_DAT_MISO,
	    input dBusWishbone_ACK,
	    input dBusWishbone_ERR,

	    input [31:0] externalResetVector
);

wire [31:0] mem_i_addr;
wire        mem_i_rstrb;
wire [31:0] mem_i_rdata;
wire        mem_i_rbusy;
wire [31:0]  mem_i_wdata;
wire [3:0]   mem_i_wmask;
wire 	    mem_i_wstrb;
wire 	    mem_i_wbusy;

wire [31:0] mem_d_addr;
wire [31:0] mem_d_wdata;
wire [3:0]  mem_d_wmask;
wire        mem_d_wstrb;
wire        mem_d_rstrb;
wire [31:0] mem_d_rdata;
wire        mem_d_rbusy;
wire        mem_d_wbusy;

/* Wishbone master interface for Insn Fetch */
assign mem_i_rbusy = iBusWishbone_CYC & iBusWishbone_STB & ~(iBusWishbone_ACK | iBusWishbone_ERR);
assign iBusWishbone_STB = iBusWishbone_CYC;
assign iBusWishbone_CYC = mem_i_rstrb;
assign mem_i_rdata = iBusWishbone_DAT_MISO;
assign iBusWishbone_ADR = mem_i_addr[31:2];
assign iBusWishbone_SEL = 4'b1111;

/* Wishbone master interface for Data load/store */
assign mem_d_rbusy = dBusWishbone_CYC & dBusWishbone_STB & ~(dBusWishbone_ACK | dBusWishbone_ERR);
assign mem_d_wbusy = mem_d_rbusy;
assign dBusWishbone_STB = dBusWishbone_CYC;
assign dBusWishbone_CYC = mem_d_rstrb | mem_d_wstrb;
assign dBusWishbone_WE = mem_d_wstrb;
assign mem_d_rdata = dBusWishbone_DAT_MISO;
assign dBusWishbone_DAT_MOSI = mem_d_wdata;
assign dBusWishbone_SEL = mem_d_wmask;
assign dBusWishbone_ADR = mem_d_addr[31:2];


rv32i cpu(reset, clk,
	  mem_i_addr,
	  mem_i_rstrb,
	  mem_i_rdata,
	  mem_i_rbusy,
	  mem_d_addr,
	  mem_d_wdata,
	  mem_d_wmask,
	  mem_d_wstrb,
	  mem_d_rstrb,
	  mem_d_rdata,
	  mem_d_rbusy,
	  mem_d_wbusy,
	  externalResetVector);

endmodule
