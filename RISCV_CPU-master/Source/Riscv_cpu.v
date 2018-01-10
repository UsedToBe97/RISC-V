`timescale 1ns/1ps

`include "Defines.vh"
`include "cpu.v"

module Riscv_cpu(
	input wire EXCLK,
	input wire button,
	output wire led,
	output wire Tx,
	input wire Rx
);
assign led = button;
reg RST;
reg RST_delay;

wire CLK;
clk_wiz_0 clk0(.clk_out1(CLK), .reset(1'b0), .clk_in1(EXCLK));

always @(posedge CLK or negedge button) begin
	if(!button) begin
		RST <= 1;
		RST_delay <= 1;
	end else begin
		RST_delay <= 0;
		RST <= RST_delay;
	end
end

wire 		UART_send_flag;
wire [7:0]	UART_send_data;
wire 		UART_recv_flag;
wire [7:0]	UART_recv_data;
wire		UART_sendable;
wire		UART_receivable;

uart_comm #(.BAUDRATE(5000000/*115200*/), .CLOCKRATE(66667000)) UART(
//uart_comm UART(		
	CLK, RST,
	UART_send_flag, UART_send_data,
	UART_recv_flag, UART_recv_data,
	UART_sendable, UART_receivable,
	Tx, Rx);

localparam CHANNEL_BIT = 1;
localparam MESSAGE_BIT = 72;
localparam CHANNEL = 1 << CHANNEL_BIT;

wire 					COMM_read_flag[CHANNEL-1:0];
wire [MESSAGE_BIT-1:0]	COMM_read_data[CHANNEL-1:0];
wire [4:0]				COMM_read_length[CHANNEL-1:0];
wire 					COMM_write_flag[CHANNEL-1:0];
wire [MESSAGE_BIT-1:0]	COMM_write_data[CHANNEL-1:0];
wire [4:0]				COMM_write_length[CHANNEL-1:0];
wire					COMM_readable[CHANNEL-1:0];
wire					COMM_writable[CHANNEL-1:0];

multchan_comm #(.MESSAGE_BIT(MESSAGE_BIT), .CHANNEL_BIT(CHANNEL_BIT)) COMM(
	CLK, RST,
	UART_send_flag, UART_send_data,
	UART_recv_flag, UART_recv_data,
	UART_sendable, UART_receivable,
	{COMM_read_flag[1], COMM_read_flag[0]},
	{COMM_read_length[1], COMM_read_data[1], COMM_read_length[0], COMM_read_data[0]},
	{COMM_write_flag[1], COMM_write_flag[0]},
	{COMM_write_length[1], COMM_write_data[1], COMM_write_length[0], COMM_write_data[0]},
	{COMM_readable[1], COMM_readable[0]},
	{COMM_writable[1], COMM_writable[0]});

wire [2*2-1:0]	MEM_rw_flag;
wire [2*32-1:0]	MEM_addr;
wire [2*32-1:0]	MEM_read_data;
wire [2*32-1:0]	MEM_write_data;
wire [2*4-1:0]	MEM_write_mask;
wire [1:0]		MEM_busy;
wire [1:0]		MEM_done;

memory_controller MEM_CTRL(
	CLK, RST,
	COMM_write_flag[0], COMM_write_data[0], COMM_write_length[0],
	COMM_read_flag[0], COMM_read_data[0], COMM_read_length[0],
	COMM_writable[0], COMM_readable[0],
	MEM_rw_flag, MEM_addr,
	MEM_read_data, MEM_write_data, MEM_write_mask,
	MEM_busy, MEM_done
);

cpu CORE(
	.clk(CLK), .rst(RST),
	.mem_rw_flag_o(MEM_rw_flag), 
	.mem_addr_o(MEM_addr),
	.mem_r_data_i(MEM_read_data), 
	.mem_w_data_o(MEM_write_data),
	.mem_w_mask_o(MEM_write_mask),
	.mem_busy_i(MEM_busy), 
	.mem_done_i(MEM_done)
);
endmodule

/*
wire[`InstAddrBus]	inst_addr;
wire[`InstBus]		inst;
wire				rom_ce;
wire				ram_w_enable;
wire[`RegBus]		ram_r_data;
wire[`RegBus]		ram_addr;
wire[`RegBus]		ram_w_data;
wire[3:0] 			ram_sel;   
wire 				ram_ce; 

cpu cpu0(
	.clk(clk),
	.rst(rst),

	.rom_data_i(inst),
	.rom_ce_o(rom_ce),
	.rom_addr_o(inst_addr),

	.ram_r_data_i(ram_r_data),
	.ram_addr_o(ram_addr),
	.ram_w_data_o(ram_w_data),
	.ram_w_enable_o(ram_w_enable),
	.ram_sel_o(ram_sel),
	.ram_ce_o(ram_ce)
);

Inst_rom inst_rom0 (
	.ce(rom_ce),
	.addr(inst_addr),
	.inst(inst)
);

Data_ram data_ram0 (
	.clk(clk),
	.ce(ram_ce),
	.we(ram_w_enable),
	.addr(ram_addr),
	.sel(ram_sel),
	.data_i(ram_w_data),
	.data_o(ram_r_data)
);



endmodule*/