`timescale 1ns/1ps

`include "Defines.vh"
`include "PC_reg.v"
`include "IF.v"
`include "IF_ID.v"
`include "ID.v"
`include "ID_EX.v"
`include "EX.v"
`include "EX_ME.v"
`include "ME.v"
`include "ME_WB.v"
`include "WB.v"
`include "Regfile.v"
`include "Ctrl.v"

module cpu(
    input wire 		clk,
	input wire		rst,

	output wire[2*2-1:0] 	mem_rw_flag_o,
	output wire[2*32-1:0]	mem_addr_o,
	input wire[2*32-1:0]	mem_r_data_i,
	
	output wire[2*32-1:0]	mem_w_data_o,
	output wire[2*4-1:0]	mem_w_mask_o,
	input wire[1:0]			mem_busy_i,
	input wire[1:0]			mem_done_i
	/*input wire[`RegBus]			rom_data_i,


	output wire					rom_ce_o,
	output wire[`InstAddrBus]	rom_addr_o,

	input wire[`RegBus]			ram_r_data_i,
	output wire[`RegBus]		ram_addr_o,
	output wire[`RegBus]		ram_w_data_o,
	output wire					ram_w_enable_o,
	output wire[3:0]			ram_sel_o,
	output wire					ram_ce_o*/
);

wire [1:0]	ICACHE_rw_flag;
wire [31:0]	ICACHE_addr;
wire [31:0]	ICACHE_r_data;
wire [31:0]	ICACHE_w_data;
wire [3:0]	ICACHE_w_mask;
wire		ICACHE_busy;
wire 		ICACHE_done;

wire		ICACHE_flush_flag;
wire [31:0]	ICACHE_flush_addr;

assign ICACHE_flush_flag = 0;
assign ICACHE_flush_addr = 0;

assign ICACHE_w_data = 0;
assign ICACHE_w_mask = 0;
assign ICACHE_rw_flag[1] = 0;
/*
Cache#(.INDEX_BIT(4), .WAYS(2))
	ICACHE0(
	.clk(clk),
	.rst(rst),

	.rw_flag_i(ICACHE_rw_flag),
	.addr_i(ICACHE_addr),
	.r_data_o(ICACHE_r_data),
	.w_data_i(ICACHE_w_data),
	.w_mask_i(ICACHE_w_mask),
	.busy(ICACHE_busy),
	.done(ICACHE_done),
	
	.flush_flag_i(ICACHE_flush_flag),
	.flush_addr_i(ICACHE_flush_addr),
	
	.mem_rw_flag_o(mem_rw_flag_o[3:2]),
	.mem_addr_o(mem_addr_o[63:32]),
	.mem_r_data_i(mem_r_data_i[63:32]),
	.mem_w_data_o(mem_w_data_o[63:32]),
	.mem_w_mask_o(mem_w_mask_o[7:4]),
	.mem_busy(mem_busy_i[1]),
	.mem_done(mem_done_i[1])
);*/

cache#(.INDEX_BIT(4), .WAYS(2))
	ICACHE0(
	.CLK(clk),
	.RST(rst),

	.rw_flag_(ICACHE_rw_flag),
	.addr_(ICACHE_addr),
	.r_data(ICACHE_r_data),
	.w_data_(ICACHE_w_data),
	.w_mask_(ICACHE_w_mask),
	.busy(ICACHE_busy),
	.done(ICACHE_done),
	
	.flush_flag(ICACHE_flush_flag),
	.flush_addr(ICACHE_flush_addr),
	
	.mem_rw_flag(mem_rw_flag_o[3:2]),
	.mem_addr(mem_addr_o[63:32]),
	.mem_r_data(mem_r_data_i[63:32]),
	.mem_w_data(mem_w_data_o[63:32]),
	.mem_w_mask(mem_w_mask_o[7:4]),
	.mem_busy(mem_busy_i[1]),
	.mem_done(mem_done_i[1])
);

wire [1:0]	DCACHE_rw_flag;
wire [31:0]	DCACHE_addr;
wire [31:0]	DCACHE_r_data;
wire [31:0]	DCACHE_w_data;
wire [3:0]	DCACHE_w_mask;
wire		DCACHE_busy;
wire 		DCACHE_done;

wire		DCACHE_flush_flag;
wire [31:0]	DCACHE_flush_addr;

assign DCACHE_flush_flag = 0;
assign DCACHE_flush_addr = 0;


cache#(/*.INDEX_BIT(4), .WAYS(2)*/)
	DCACHE0(
	.CLK(clk),
	.RST(rst),

	.rw_flag_(DCACHE_rw_flag),
	.addr_(DCACHE_addr),
	.r_data(DCACHE_r_data),
	.w_data_(DCACHE_w_data),
	.w_mask_(DCACHE_w_mask),
	.busy(DCACHE_busy),
	.done(DCACHE_done),
	
	.flush_flag(DCACHE_flush_flag),
	.flush_addr(DCACHE_flush_addr),
	
	.mem_rw_flag(mem_rw_flag_o[1:0]),
	.mem_addr(mem_addr_o[31:0]),
	.mem_r_data(mem_r_data_i[31:0]),
	.mem_w_data(mem_w_data_o[31:0]),
	.mem_w_mask(mem_w_mask_o[3:0]),
	.mem_busy(mem_busy_i[0]),
	.mem_done(mem_done_i[0])
);



wire 				if_stall_req;
wire 				id_stall_req;
wire 				ex_stall_req;
wire 				me_stall_req;
wire[5:0]			stall;


Ctrl ctrl0(
	.rst(rst),
	.if_stall_req_i(if_stall_req),
	.id_stall_req_i(id_stall_req),
	.ex_stall_req_i(ex_stall_req),
	.me_stall_req_i(me_stall_req),
	.stall(stall)
);

// ================== IF ============================
wire[`InstAddrBus]	pc;
wire[`InstAddrBus]	if_pc_o;
wire[`InstBus]		if_inst_o;

//wire				ex_b_flag_o;
//wire[`RegBus]		ex_b_target_addr_o;

wire				id_b_flag_o;
wire[`RegBus]		id_b_target_addr_o;

PC_reg pc_reg0(
	.clk(clk),
	.rst(rst),
	.pc(pc),
	//.ce(rom_ce_o),
	.stall(stall),

	//.ex_b_flag_i(ex_b_flag_o),
	//.ex_b_target_addr_i(ex_b_target_addr_o),

	.id_b_flag_i(id_b_flag_o),
	.id_b_target_addr_i(id_b_target_addr_o)
);

IF if0 (
	.clk(clk),
	.rst(rst),

	.pc_i(pc),
	.rom_data_i(ICACHE_r_data),
	.pc_o(if_pc_o),
	.inst_o(if_inst_o),
	.rom_addr_o(ICACHE_addr),

	.r_enable_o(ICACHE_rw_flag[0]),
	.rom_busy_i(ICACHE_busy),
	.rom_done_i(ICACHE_done),
	.stall_req_o(if_stall_req)
);

// ================== IF_ID =========================
wire[`InstAddrBus]	id_pc_i;
wire[`InstBus]		id_inst_i;

IF_ID if_id0 (
	.clk(clk),
	.rst(rst),

	.if_pc(if_pc_o),
	.if_inst(if_inst_o),
	.id_pc(id_pc_i),
	.id_inst(id_inst_i),

	.stall(stall),
	//.ex_b_flag(ex_b_flag_o),
	.id_b_flag(id_b_flag_o)
);

// ================== ID ===========================

wire					id_r1_enable_o;
wire					id_r2_enable_o;
wire[`RegAddrBus]		id_r1_addr_o;
wire[`RegAddrBus]		id_r2_addr_o;

wire[`RegBus]			id_r2_data_i;
wire[`RegBus]			id_r1_data_i;

wire[`AluOpBus]			id_aluop_o;
wire[`AluOutSelBus]		id_alusel_o;
wire[`RegBus]			id_r1_data_o;
wire[`RegBus]			id_r2_data_o;
wire					id_w_enable_o;
wire[`RegAddrBus]		id_w_addr_o;

wire					ex2id_w_enable;
wire[`RegAddrBus]		ex2id_w_addr;
wire[`RegBus]			ex2id_w_data;
wire					me2id_w_enable;
wire[`RegAddrBus]		me2id_w_addr;
wire[`RegBus]			me2id_w_data;
wire[`InstAddrBus]		id_pc_o;
wire[`RegBus]			id_offset_o;
wire					ex2id_pre_ld;

ID id0 (
	.rst(rst),

	.pc_i(id_pc_i),
	.inst_i(id_inst_i),
	.r1_data_i(id_r1_data_i),
	.r2_data_i(id_r2_data_i),
	.r1_enable_o(id_r1_enable_o),
	.r2_enable_o(id_r2_enable_o),
	.r1_addr_o(id_r1_addr_o),
	.r2_addr_o(id_r2_addr_o),
	.aluop_o(id_aluop_o),
	.alusel_o(id_alusel_o),
	.r1_data_o(id_r1_data_o),
	.r2_data_o(id_r2_data_o),
	.w_enable_o(id_w_enable_o),
	.w_addr_o(id_w_addr_o),
	.pc_o(id_pc_o),
	.ex_w_enable_i(ex2id_w_enable),
	.ex_w_addr_i(ex2id_w_addr),
	.ex_w_data_i(ex2id_w_data),
	.me_w_enable_i(me2id_w_enable),
	.me_w_addr_i(me2id_w_addr),
	.me_w_data_i(me2id_w_data),

	.stall_req_o(id_stall_req),
	.offset_o(id_offset_o),
	.b_flag_o(id_b_flag_o),
	.b_target_addr_o(id_b_target_addr_o),

	.ex_pre_ld(ex2id_pre_ld)
);

// ================== ID_EX =========================

wire[`AluOpBus]				ex_aluop_i;
wire[`AluOutSelBus]			ex_alusel_i;
wire[`RegBus]				ex_r1_data_i;
wire[`RegBus]				ex_r2_data_i;
wire						ex_w_enable_i;
wire[`RegAddrBus]			ex_w_addr_i;

wire[`InstAddrBus]			ex_pc_i;
wire[`RegBus]				ex_offset_i;


ID_EX id_ex0 (
	.clk(clk),
	.rst(rst),

	.id_pc(id_pc_o),
	.id_aluop(id_aluop_o),
	.id_alusel(id_alusel_o),
	.id_r1_data(id_r1_data_o),
	.id_r2_data(id_r2_data_o),
	.id_w_enable(id_w_enable_o),
	.id_w_addr(id_w_addr_o),
	.ex_aluop(ex_aluop_i),
	.ex_alusel(ex_alusel_i),
	.ex_r1_data(ex_r1_data_i),
	.ex_r2_data(ex_r2_data_i),
	.ex_w_enable(ex_w_enable_i),
	.ex_w_addr(ex_w_addr_i),
	.ex_pc(ex_pc_i),

	.stall(stall),
	//.ex_b_flag(ex_b_flag_o),
	.id_offset(id_offset_o),
	.ex_offset(ex_offset_i)
);

// ================== EX ===========================
wire						ex_w_enable_o;
wire[`RegAddrBus]			ex_w_addr_o;
wire[`RegBus]				ex_w_data_o;

wire[`AluOpBus]				ex_aluop_o;
wire[`RegBus]				ex_mem_addr_o;

EX ex0 (
	.rst(rst),

	.pc_i(ex_pc_i),
	.aluop_i(ex_aluop_i),
	.alusel_i(ex_alusel_i),
	.r1_data_i(ex_r1_data_i),
	.r2_data_i(ex_r2_data_i),
	.w_enable_i(ex_w_enable_i),
	.w_addr_i(ex_w_addr_i),
	.w_enable_o(ex_w_enable_o),
	.w_addr_o(ex_w_addr_o),
	.w_data_o(ex_w_data_o),

	.stall_req_o(ex_stall_req),

	.offset_i(ex_offset_i),
	//.b_flag_o(ex_b_flag_o),
	//.b_target_addr_o(ex_b_target_addr_o),

	.aluop_o(ex_aluop_o),
	.mem_addr_o(ex_mem_addr_o),

	.is_ld(ex2id_pre_ld)
);

// Forwarding wire
assign ex2id_w_enable	=	ex_w_enable_o;
assign ex2id_w_addr		=	ex_w_addr_o;
assign ex2id_w_data		=	ex_w_data_o;

// ================== EX_ME ===========================
wire						me_w_enable_i;
wire[`RegAddrBus]			me_w_addr_i;
wire[`RegBus]				me_w_data_i;
wire[`AluOpBus]				me_aluop_i;
wire[`RegBus]				me_mem_addr_i;


EX_ME ex_me0 (
	.clk(clk),
	.rst(rst),

	.ex_w_enable(ex_w_enable_o),
	.ex_w_addr(ex_w_addr_o),
	.ex_w_data(ex_w_data_o),
	.me_w_enable(me_w_enable_i),
	.me_w_addr(me_w_addr_i),
	.me_w_data(me_w_data_i),

	.stall(stall),

	.ex_aluop(ex_aluop_o),
	.ex_mem_addr(ex_mem_addr_o),
	.me_aluop(me_aluop_i),
	.me_mem_addr(me_mem_addr_i)
);


// ================== ME =============================
wire						me_w_enable_o;
wire[`RegAddrBus]			me_w_addr_o;
wire[`RegBus]				me_w_data_o;


ME me0 (
	.rst(rst),

	.w_enable_i(me_w_enable_i),
	.w_addr_i(me_w_addr_i),
	.w_data_i(me_w_data_i),
	.w_enable_o(me_w_enable_o),
	.w_addr_o(me_w_addr_o),
	.w_data_o(me_w_data_o),

	.stall_req_o(me_stall_req),

	.aluop_i(me_aluop_i),
	.mem_addr_i(me_mem_addr_i),

	.mem_r_enable_o(DCACHE_rw_flag[0]),
	.mem_r_data_i(DCACHE_r_data),
	.mem_w_enable_o(DCACHE_rw_flag[1]),
	.mem_w_mask_o(DCACHE_w_mask),
	.mem_w_data_o(DCACHE_w_data),
	.mem_addr_o(DCACHE_addr),
	.mem_busy(DCACHE_busy),
	.mem_done(DCACHE_done)

	//.mem_ce_o(ram_ce_o)
);

// Forwarding wire
assign me2id_w_enable	=	me_w_enable_o;	
assign me2id_w_addr		=	me_w_addr_o;
assign me2id_w_data		=	me_w_data_o;


// ================== ME_WB ===========================
wire						wb_w_enable_i;
wire[`RegAddrBus]			wb_w_addr_i;
wire[`RegBus]				wb_w_data_i;

ME_WB me_wb0 (
	.clk(clk),
	.rst(rst),

	.me_w_enable(me_w_enable_o),
	.me_w_addr(me_w_addr_o),
	.me_w_data(me_w_data_o),
	.wb_w_enable(wb_w_enable_i),
	.wb_w_addr(wb_w_addr_i),
	.wb_w_data(wb_w_data_i),

	.stall(stall)
);

// ================== WB ==============================

wire						wb_w_enable_o;
wire[`RegAddrBus]			wb_w_addr_o;
wire[`RegBus]				wb_w_data_o;

WB wb0 (
	.rst(rst),

	.w_enable_i(wb_w_enable_i),
	.w_addr_i(wb_w_addr_i),
	.w_data_i(wb_w_data_i),
	.w_enable_o(wb_w_enable_o),
	.w_addr_o(wb_w_addr_o),
	.w_data_o(wb_w_data_o)

);


Regfile regfile0(
	.clk(clk),
	.rst(rst),
	
	.w_enable(wb_w_enable_o),
	.w_addr(wb_w_addr_o),
	.w_data(wb_w_data_o),
	.r1_enable(id_r1_enable_o),
	.r1_addr(id_r1_addr_o),
	.r1_data(id_r1_data_i),
	.r2_enable(id_r2_enable_o),
	.r2_addr(id_r2_addr_o),
	.r2_data(id_r2_data_i)
);

endmodule