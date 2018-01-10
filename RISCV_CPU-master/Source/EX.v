`include "Defines.vh"

module EX(
	input wire rst,
	
	input wire[`InstAddrBus]	pc_i, 
	input wire[`AluOpBus]		aluop_i,
	input wire[`AluOutSelBus]	alusel_i,
	input wire[`RegBus]			r1_data_i,
	input wire[`RegBus]			r2_data_i,
	input wire					w_enable_i,
	input wire[`RegAddrBus]		w_addr_i,

	output reg 					w_enable_o,
	output reg[`RegAddrBus]		w_addr_o,
	output reg[`RegBus]			w_data_o,

	output reg					stall_req_o,
	input wire[`RegBus]			offset_i,

	//output reg 					b_flag_o,
	//output reg[`InstAddrBus]	b_target_addr_o,

	output wire[`AluOpBus]		aluop_o,
	output wire[`RegBus]		mem_addr_o,
	// data to store  ->  w_data_o

	output wire					is_ld
);



reg[`RegBus]		logic_res;
reg[`RegBus]		shift_res;
reg[`RegBus]		arith_res;
reg[`RegBus]		CTRL_res;

wire[`RegBus]		sum_res;
wire				lt_res;
wire[`InstAddrBus]	pc_plus_4;
wire[`InstAddrBus]	pc_plus_offset;



assign sum_res = (aluop_i == `EXOP_SUB ? 
						r1_data_i - r2_data_i: r1_data_i + r2_data_i);

assign lt_res = ((aluop_i == `EXOP_SLT || aluop_i == `EXOP_BLT ||
				aluop_i == `EXOP_BGE)? 
				$signed(r1_data_i) < $signed(r2_data_i):
				r1_data_i < r2_data_i);


assign pc_plus_4 = pc_i + 4;
assign pc_plus_offset = pc_i + offset_i;

assign aluop_o = ((aluop_i == `EXOP_LB) || 
				(aluop_i == `EXOP_LH) ||
				(aluop_i == `EXOP_LW) ||
				(aluop_i == `EXOP_LBU)||
				(aluop_i == `EXOP_LHU)||
				(aluop_i == `EXOP_SB) ||
				(aluop_i == `EXOP_SH) ||
				(aluop_i == `EXOP_SW) ) ? aluop_i : 0;

assign mem_addr_o = r1_data_i + offset_i;

assign is_ld = ((aluop_i == `EXOP_LB) || 
				(aluop_i == `EXOP_LH) ||
				(aluop_i == `EXOP_LW) ||
				(aluop_i == `EXOP_LBU)||
				(aluop_i == `EXOP_LHU)) ? 1'b1 : 1'b0;


always @ (*)
begin
	if (rst) 
	begin
		CTRL_res	=	`ZeroWord;
	end
	else
	begin
		CTRL_res		=	`ZeroWord;
		
		case (aluop_i)
			`EXOP_JAL:
			begin
				CTRL_res			=	pc_plus_4;
			end
			
			`EXOP_JALR:
			begin
				CTRL_res			=	pc_plus_4;
			end
		endcase
	end
end


always @ (*) 
begin
	if (rst) 
	begin
		arith_res	<=	`ZeroWord;
	end
	else 
	begin
		case (aluop_i)
			`EXOP_SLT, `EXOP_SLTU:
			begin
				arith_res	<=	{31'h0, lt_res};
			end

			`EXOP_ADD, `EXOP_SUB: 
			begin
				arith_res	<=	sum_res;			
			end
			
			`EXOP_AUIPC:
			begin
			  	arith_res	<=	pc_plus_offset;
			end

			default: 
			begin
				arith_res	<=	`ZeroWord;
			end
		endcase
	end
end



always @ (*)
begin
	if (rst)
		logic_res	<=	`ZeroWord;
	else 
	begin
		case (aluop_i)
			`EXOP_OR:
			begin
				logic_res	<=	r1_data_i | r2_data_i;
			end
			
			`EXOP_XOR:
			begin
				logic_res	<=	r1_data_i ^ r2_data_i;
			end

			`EXOP_AND:
			begin
				logic_res	<=	r1_data_i & r2_data_i;
			end


			default:
			begin
				logic_res	<=	`ZeroWord;
			end
		endcase
	end	
end

always @ (*)
begin
	if (rst)
		shift_res	<=	`ZeroWord;
	else 
	begin
		case (aluop_i)
			`EXOP_SLL:
			begin
				shift_res	<=	r1_data_i << r2_data_i[4:0];
			end
			`EXOP_SRL:
			begin
				shift_res	<=	r1_data_i  >> r2_data_i[4:0];
			end
			`EXOP_SRA:
			begin
				shift_res	<=	({32{r1_data_i[31]}} << (6'd32 - {1'b0,r2_data_i[4:0]})) | r1_data_i >> r2_data_i[4:0];
			end


			default:
			begin
				shift_res	<=	`ZeroWord;
			end
		endcase
	end	
end



always @ (*)
begin
	if (rst)
	begin
		w_enable_o		<=	`WriteDisable;
		w_addr_o		<=	`ZeroWord;
		w_data_o		<=	`ZeroWord;
	end
	else if (w_enable_i && w_addr_i == `ZeroWord)
	begin
		w_enable_o		<=	`WriteDisable;
		w_addr_o		<=	`ZeroWord;
		w_data_o		<=	`ZeroWord;
	end
	else
	begin
		w_enable_o	<=	w_enable_i;
		w_addr_o	<=	w_addr_i;
		case (alusel_i)
			`EXRES_LOGIC:
			begin
				w_data_o	<=	logic_res;
			end
			`EXRES_SHIFT:
			begin
				w_data_o	<=	shift_res;
			end
			`EXRES_ARITH:
			begin
				w_data_o	<=	arith_res;
			end
			`EXRES_CTRL:
			begin
				w_data_o	<=	CTRL_res;
			end
			`EXRES_LD_ST:
			begin
				w_data_o	<=	r2_data_i;
			end
			default:
			begin
				w_data_o	<=	`ZeroWord;
			end
		endcase
	end
end





endmodule
