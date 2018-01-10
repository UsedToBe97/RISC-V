`include "Defines.vh"

module ME(
	input wire rst,

	input wire				w_enable_i,
	input wire[`RegAddrBus]	w_addr_i,
	input wire[`RegBus]		w_data_i,

	output reg 				w_enable_o,
	output reg[`RegAddrBus]	w_addr_o,
	output reg[`RegBus]		w_data_o,

	output	reg				stall_req_o,

	input wire[`AluOpBus]	aluop_i,
	input wire[`RegBus]		mem_addr_i,

	output reg				mem_r_enable_o,
	input wire[`RegBus]		mem_r_data_i,
	output reg				mem_w_enable_o,
	output reg[3:0]			mem_w_mask_o,
	output reg[`RegBus]		mem_w_data_o,
	output reg[`RegBus]		mem_addr_o,

	input wire				mem_busy,
	input wire				mem_done // pulse
);

/*always @(*)
begin
	stall_req_o = 1'b0;
end*/

always @ (*)
begin
	if (rst)
	begin
		w_enable_o		=	`WriteDisable;
		w_addr_o		=	`NOPRegAddr;
		w_data_o		=	`ZeroWord;
		mem_r_enable_o	=	1'b0;
		mem_w_enable_o	=	`WriteDisable;
		mem_w_mask_o	=	4'b0000;
		mem_w_data_o	=	`ZeroWord;
		mem_addr_o		=	`ZeroWord;
		stall_req_o   	= 	1'b0;
	end
	else if (!aluop_i)
	begin
		w_enable_o		=	w_enable_i;
		w_addr_o		=	w_addr_i;
		w_data_o		=	w_data_i;
		mem_r_enable_o	=	1'b0;
		mem_w_enable_o	=	`WriteDisable;
		mem_w_mask_o	=	4'b0000;
		mem_w_data_o	=	`ZeroWord;
		mem_addr_o		=	`ZeroWord;
		stall_req_o   	= 	1'b0;
	end
	else begin
		w_enable_o		=	w_enable_i;
		w_addr_o		=	w_addr_i;
		w_data_o		=	w_data_i;
		mem_r_enable_o	=	1'b0;
		mem_w_enable_o	=	`WriteDisable;
		mem_w_mask_o	=	4'b0000;
		mem_w_data_o	=	`ZeroWord;
		mem_addr_o		=	`ZeroWord;
		if (mem_done)
		begin
			stall_req_o	= 1'b0;
			case (aluop_i)
				`EXOP_LB:
				begin
					case (mem_addr_i[1:0])
						2'b11:	begin
							w_data_o		<=	{{24{mem_r_data_i[31]}},mem_r_data_i[31:24]};
						end
						2'b10:	begin
							w_data_o		<=	{{24{mem_r_data_i[23]}},mem_r_data_i[23:16]};
						end
						2'b01:	begin
							w_data_o		<=	{{24{mem_r_data_i[15]}},mem_r_data_i[15:8]};
						end
						2'b00:	begin
							w_data_o		<=	{{24{mem_r_data_i[7]}},mem_r_data_i[7:0]};
						end
						default:	begin
							w_data_o	<=	`ZeroWord;
						end
					endcase
				end

				`EXOP_LH:
				begin
					case (mem_addr_i[1:0])
						2'b10:	begin
							w_data_o		<=	{{16{mem_r_data_i[31]}},mem_r_data_i[31:16]};
						end
						2'b00:	begin
							w_data_o		<=	{{16{mem_r_data_i[15]}},mem_r_data_i[15:0]};
						end
						default:	begin
							w_data_o	<=	`ZeroWord;
						end
					endcase
				end	
				`EXOP_LW:
				begin
					w_data_o		<=	mem_r_data_i;
				end
				`EXOP_LBU:
				begin
					case (mem_addr_i[1:0])
						2'b11:	begin
							w_data_o	<=	{{24{1'b0}},mem_r_data_i[31:24]};
						end
						2'b10:	begin
							w_data_o	<=	{{24{1'b0}},mem_r_data_i[23:16]};
						end
						2'b01:	begin
							w_data_o	<=	{{24{1'b0}},mem_r_data_i[15:8]};
						end
						2'b00:	begin
							w_data_o	<=	{{24{1'b0}},mem_r_data_i[7:0]};
						end
						default:	begin
							w_data_o	<=	`ZeroWord;
						end
					endcase				
				end

				`EXOP_LHU:
				begin
					//mem_w_enable_o	<=	`WriteDisable;
					case (mem_addr_i[1:0])
						2'b10:	begin
							w_data_o		<=	{{16{1'b0}},mem_r_data_i[31:16]};
						//	mem_w_mask_o	<=	4'b0000;
						end
						2'b00:	begin
							w_data_o		<=	{{16{1'b0}},mem_r_data_i[15:0]};
						//	mem_w_mask_o	<=	4'b0000;
						end
						default:	begin
							w_data_o		<=	`ZeroWord;
						//	mem_w_mask_o	<=	4'b0000;
						end
					endcase				
				end

				default:
				begin
					w_data_o		<=	w_data_i;
				end
			endcase
		end
		else if (!mem_busy) 
		begin
			case (aluop_i)
				`EXOP_LB, `EXOP_LH, `EXOP_LBU, `EXOP_LHU, `EXOP_LW:
				begin
					mem_r_enable_o 	<=	1'b1;
					mem_w_enable_o	<=	`WriteDisable;
					mem_addr_o		<=	{mem_addr_i[31:2], 2'h0};
					mem_w_data_o	<=	`ZeroWord;
					stall_req_o		<= 	1'b1;
				end

				`EXOP_SB:
				begin
					stall_req_o		<= 	1'b1;
					w_data_o		<= 	w_data_i;
					mem_r_enable_o	<=	1'b0;
					mem_w_enable_o	<=	`WriteEnable;
					mem_addr_o		<=	mem_addr_i;
					mem_w_data_o	<=	{w_data_i[7:0],w_data_i[7:0],w_data_i[7:0],w_data_i[7:0]};
					case (mem_addr_i[1:0])
						2'b00:	begin
							mem_w_mask_o	<=	4'b0001;
						end
						2'b01:	begin
							mem_w_mask_o	<=	4'b0010;
						end
						2'b10:	begin
							mem_w_mask_o	<=	4'b0100;
						end
						2'b11:	begin
							mem_w_mask_o	<=	4'b1000;	
						end
						default:	begin
							mem_w_mask_o	<=	4'b0000;
						end
					endcase				
				end
				
				`EXOP_SH:
				begin
					stall_req_o		<= 	1'b1;
					w_data_o		<= 	w_data_i;
					mem_r_enable_o	<=	1'b0;
					mem_w_enable_o	<=	`WriteEnable ;
					mem_addr_o		<=	mem_addr_i;
					mem_w_data_o		<=	{w_data_i[15:0],w_data_i[15:0]};
					case (mem_addr_i[1:0])
						2'b00:	begin
							mem_w_mask_o	<=	4'b0011;
						end
						2'b10:	begin
							mem_w_mask_o	<=	4'b1100;
						end
						default:	begin
							mem_w_mask_o	<=	4'b0000;
						end
					endcase		
				end

				`EXOP_SW:
				begin
					stall_req_o		<= 	1'b1;
					w_data_o		<= 	w_data_i;
					mem_r_enable_o	<=	1'b0;
					mem_w_enable_o	<=	`WriteEnable;
					mem_addr_o		<=	mem_addr_i;
					mem_w_data_o	<=	w_data_i;
					mem_w_mask_o	<=	4'b1111;	
				end

				default:
				begin
					stall_req_o		<= 	1'b0;
					w_enable_o		<=	1'b0;
					mem_r_enable_o	<=	1'b0;
					w_data_o		<=	w_data_i;
					mem_w_enable_o	<=	`WriteDisable;
					mem_addr_o		<=	`ZeroWord;
					mem_w_data_o	<=	`ZeroWord;
					mem_w_mask_o	<=	4'b0000;
				end
			endcase
		end
		else if (mem_busy)
		begin
			stall_req_o		<= 	1'b1;
		end
	end
end

endmodule