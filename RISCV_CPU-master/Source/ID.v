`include "Defines.vh"

module ID (
	input wire					rst,
	input wire[`InstAddrBus]	pc_i,
	input wire[`InstBus]		inst_i,

	input wire[`RegBus]		 	r1_data_i,
	input wire[`RegBus]		 	r2_data_i,

	output reg					r1_enable_o, 
	output reg					r2_enable_o, 
	output reg[`RegAddrBus]	 	r1_addr_o,
	output reg[`RegAddrBus]	 	r2_addr_o,

	output reg[`AluOpBus]		aluop_o,
	output reg[`AluOutSelBus]	alusel_o,
	output reg[`RegBus]		 	r1_data_o,
	output reg[`RegBus]		 	r2_data_o,
	output reg					w_enable_o,
	output reg[`RegAddrBus]	 	w_addr_o,

	input wire					ex_pre_ld,
	input wire 					ex_w_enable_i,
	input wire[`RegAddrBus]		ex_w_addr_i,
	input wire[`RegBus]			ex_w_data_i,

	input wire					me_w_enable_i,
	input wire[`RegAddrBus]		me_w_addr_i,
	input wire[`RegBus]			me_w_data_i,

	output wire					stall_req_o,
	output reg[`RegBus]			offset_o,

	output reg[`InstAddrBus]	pc_o,

	output reg					b_flag_o,
	output reg[`InstAddrBus]	b_target_addr_o
	
);


reg instvalid;
reg[`RegBus] imm;
reg pre_ld;
reg r1_stall_req;
reg r2_stall_req;

assign stall_req_o = r1_stall_req | r2_stall_req;

wire[6:0]		opcode;
wire[4:0]		rd, rs1, rs2;
wire[2:0]		funct3;
wire			funct7;
wire[11:0]		imm_I, imm_S;
wire[31:0]		imm_B, imm_U, imm_J;


assign opcode		=	inst_i[6:0];
assign rd			=	inst_i[11:7];
assign rs1			=	inst_i[19:15];
assign rs2			=	inst_i[24:20];
assign funct3		=	inst_i[14:12];
assign funct7		=	inst_i[30];
assign imm_I		=	inst_i[31:20];
assign imm_S		=	{inst_i[31:25], inst_i[11:7]};
assign imm_B		=	{{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8],1'h0};
assign imm_U		=	{inst_i[31:12], 12'h0};
assign imm_J		=	{{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21],1'h0};

wire				b_flag;
wire[`InstAddrBus]	b_target_res;

assign b_target_res = (opcode == `OP_JAL)? imm_J + pc_i: imm_B + pc_i;

`ifdef ID_BRANCHES
wire	lt_res;
wire	eq_res;
assign lt_res = ((aluop_o == `EXOP_BLT || aluop_o == `EXOP_BGE)? 
				$signed(r1_data_o) < $signed(r2_data_o):
				r1_data_o < r2_data_o);

assign eq_res = (r1_data_o == r2_data_o);
`endif

`ifdef ID_JALR
wire[`RegBus] sum_res;
assign sum_res = r1_data_o + {{20{imm_I[11]}}, imm_I};
`endif


always @(*)
begin
	case(opcode)
		`OP_JAL:
		begin
			b_flag_o		<=	1'b1;
			b_target_addr_o	<=	b_target_res;
		end
		`ifdef ID_JALR
		`OP_JALR:
		begin
			b_flag_o		<=	1'b1;
			b_target_addr_o	<=	sum_res;
		end
		`endif //ID_JALR

		`ifdef ID_BRANCHES 
		`OP_BRANCH:
		begin
			case (funct3)
				`FUNCT3_BEQ:
				begin
					b_flag_o		<=	eq_res;
					b_target_addr_o	<=	b_target_res;
				end
				`FUNCT3_BNE:
				begin
					b_flag_o		<=	~eq_res;
					b_target_addr_o	<=	b_target_res;
				end
				`FUNCT3_BLT, `FUNCT3_BLTU:
				begin
					b_flag_o		<=	lt_res;
					b_target_addr_o	<=	b_target_res;
				end
				`FUNCT3_BGE, `FUNCT3_BGEU:
				begin
					b_flag_o		<=	~lt_res;
					b_target_addr_o	<=	b_target_res;
				end
				  
				default:
				begin
					b_flag_o		<=	1'b0;
					b_target_addr_o	<=	`ZeroWord;
				end
			endcase
		end
		// end
		`endif //ID_BRANCHES
		default:
		begin
			b_flag_o		<=	1'b0;
			b_target_addr_o	<=	`ZeroWord;
		end
	endcase
end


always @ (*)
begin
	if (rst)
	begin
		aluop_o			<=	`EXOP_NOP;
		alusel_o		<=	`EXRES_NOP;
		r1_enable_o		<=	1'b0;
		r2_enable_o		<=	1'b0;
		r1_addr_o		<=	`NOPRegAddr;
		r2_addr_o		<=	`NOPRegAddr;
		w_enable_o		<= 	`WriteDisable;
		w_addr_o		<= 	`NOPRegAddr;
		instvalid		<=	`InstValid;
		imm 			<=	`ZeroWord;

		pre_ld		<=	1'b0;
		
	end

	else
	begin
		pc_o			<=	pc_i;
		case(opcode)
			`OP_LUI:
			begin
				aluop_o			<=	`EXOP_OR;
				alusel_o		<=	`EXRES_LOGIC;
				r1_enable_o		<=	1'b0;
				r2_enable_o		<=	1'b0;
				r1_addr_o		<=	rs1;
				r2_addr_o		<=	rs2;
				imm				<=	imm_U;
				w_enable_o		<=	`WriteEnable;
				w_addr_o		<=	rd;
				instvalid		<=	`InstValid;

				pre_ld		<=	1'b0;
			end

			`OP_AUIPC:
			begin
				aluop_o			<=	`EXOP_AUIPC;
				alusel_o		<=	`EXRES_ARITH;
				r1_enable_o		<=	1'b0;
				r2_enable_o		<=	1'b0;
				r1_addr_o		<=	rs1;
				r2_addr_o		<=	rs2;
				imm				<=	imm_U;
				w_enable_o		<=	`WriteEnable;
				w_addr_o		<=	rd;
				instvalid		<=	`InstValid;

				pre_ld		<=	1'b0;
			end

			`OP_JAL:
			begin
				aluop_o			<=	`EXOP_JAL;
				alusel_o		<=	`EXRES_CTRL;
				r1_enable_o		<=	1'b0;
				r2_enable_o		<=	1'b0;
				r1_addr_o		<=	rs1;
				r2_addr_o		<=	rs2;
				imm				<=	imm_J;
				w_enable_o		<=	`WriteEnable;
				w_addr_o		<=	rd;
				instvalid		<=	`InstValid;

				pre_ld		<=	1'b0;
				
			end

			`OP_JALR:
			begin
				aluop_o			<=	`EXOP_JALR;
				alusel_o		<=	`EXRES_CTRL;
				r1_enable_o		<=	1'b1;
				r2_enable_o		<=	1'b0;
				r1_addr_o		<=	rs1;
				r2_addr_o		<=	rs2;
				imm				<=	{{20{imm_I[11]}}, imm_I};
				w_enable_o		<=	`WriteEnable;
				w_addr_o		<=	rd;
				instvalid		<=	`InstValid;

				pre_ld		<=	1'b0;
			end

			`OP_BRANCH:
			begin
				case(funct3)
					`FUNCT3_BEQ:
					begin
						aluop_o			<=	`EXOP_BEQ;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	imm_B;
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	`ZeroWord;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					`FUNCT3_BNE:
					begin
						aluop_o			<=	`EXOP_BNE;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	imm_B;
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	`ZeroWord;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					`FUNCT3_BLT:
					begin
						aluop_o			<=	`EXOP_BLT;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	imm_B;
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	`ZeroWord;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					`FUNCT3_BGE:
					begin
						aluop_o			<=	`EXOP_BGE;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	imm_B;
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	`ZeroWord;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					`FUNCT3_BLTU:
					begin
						aluop_o			<=	`EXOP_BLTU;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	imm_B;
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	`ZeroWord;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					`FUNCT3_BGEU:
					begin
						aluop_o			<=	`EXOP_BGEU;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	imm_B;
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	`ZeroWord;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					default:
					begin
						aluop_o			<=	`EXOP_NOP;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b0;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	`NOPRegAddr;
						r2_addr_o		<=	`NOPRegAddr;
						w_enable_o		<= 	`WriteDisable;
						w_addr_o		<= 	`NOPRegAddr;
						instvalid		<=	`InstValid;
						imm 			<=	`ZeroWord;

						pre_ld		<=	1'b0;
					end
				endcase
			end

			`OP_LOAD:
			begin
				case (funct3)
					`FUNCT3_LB:
					begin
						aluop_o			<=	`EXOP_LB;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b1;
					end 
					
					`FUNCT3_LH:
					begin
						aluop_o			<=	`EXOP_LH;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b1;
					end

					`FUNCT3_LW:
					begin
						aluop_o			<=	`EXOP_LW;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b1;
					end

					`FUNCT3_LBU:
					begin
						aluop_o			<=	`EXOP_LBU;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b1;
					end

					`FUNCT3_LHU:
					begin
						aluop_o			<=	`EXOP_LHU;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b1;
					end

					default:
					begin
						aluop_o			<=	`EXOP_NOP;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b0;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	`NOPRegAddr;
						r2_addr_o		<=	`NOPRegAddr;
						w_enable_o		<= 	`WriteDisable;
						w_addr_o		<= 	`NOPRegAddr;
						instvalid		<=	`InstValid;
						imm 			<=	`ZeroWord;

						pre_ld		<=	1'b0;
					end 
				endcase
			end

			`OP_STORE:
			begin
				case (funct3)
				  	`FUNCT3_SB: 
					begin
						aluop_o			<=	`EXOP_SB;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_S[11]}}, imm_S[11: 0]};
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b0;
					end

					`FUNCT3_SH:
					begin
						aluop_o			<=	`EXOP_SH;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_S[11]}}, imm_S[11: 0]};
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b0;
					end

					`FUNCT3_SW:
					begin
						aluop_o			<=	`EXOP_SW;
						alusel_o		<=	`EXRES_LD_ST;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b1;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_S[11]}}, imm_S[11: 0]};
						w_enable_o		<=	`WriteDisable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;

						pre_ld		<=	1'b0;
					end

				  	default:
					begin
						aluop_o			<=	`EXOP_NOP;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b0;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	`NOPRegAddr;
						r2_addr_o		<=	`NOPRegAddr;
						w_enable_o		<= 	`WriteDisable;
						w_addr_o		<= 	`NOPRegAddr;
						instvalid		<=	`InstValid;
						imm 			<=	`ZeroWord;

						pre_ld		<=	1'b0;
					end
				endcase
			end

			`OPI:
			begin
				case(funct3)
					`FUNCT3_ADDI:
					begin
						aluop_o			<=	`EXOP_ADD;
						alusel_o		<=	`EXRES_ARITH;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end

					`FUNCT3_SLTI:
					begin
						aluop_o			<=	`EXOP_SLT;
						alusel_o		<=	`EXRES_ARITH;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end

					`FUNCT3_SLTIU:
					begin
						aluop_o			<=	`EXOP_SLTU;
						alusel_o		<=	`EXRES_ARITH;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{{20{imm_I[11]}}, imm_I[11: 0]};	
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					
					`FUNCT3_XORI:
					begin
						aluop_o			<=	`EXOP_XOR;
						alusel_o		<=	`EXRES_LOGIC;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{20'h0, imm_I};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end

					`FUNCT3_ORI: // ORI
					begin
						aluop_o			<=	`EXOP_OR;
						alusel_o		<=	`EXRES_LOGIC;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{20'h0, imm_I};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end

					`FUNCT3_ANDI:
					begin
						aluop_o			<=	`EXOP_AND;
						alusel_o		<=	`EXRES_LOGIC;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{20'h0, imm_I};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end
					
					`FUNCT3_SLLI:
					begin
						aluop_o			<=	`EXOP_SLL;
						alusel_o		<=	`EXRES_SHIFT;
						r1_enable_o		<=	1'b1;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	rs1;
						r2_addr_o		<=	rs2;
						imm				<=	{27'h0, rs2};
						w_enable_o		<=	`WriteEnable;
						w_addr_o		<=	rd;
						instvalid		<=	`InstValid;
						pre_ld		<=	1'b0;
					end

					`FUNCT3_SRLI_SRAI:
					begin
						case (funct7)
							`FUNCT7_SRLI:
							begin
								aluop_o		<=	`EXOP_SRL;
								alusel_o	<=	`EXRES_SHIFT;
								r1_enable_o	<=	1'b1;
								r2_enable_o	<=	1'b0;
								r1_addr_o	<=	rs1;
								r2_addr_o	<=	rs2;
								imm			<=	{27'h0, rs2};
								w_enable_o	<=	`WriteEnable;
								w_addr_o	<=	rd;
								instvalid	<=	`InstValid;
								pre_ld	<=	1'b0;
							end

							`FUNCT7_SRAI:
							begin
								aluop_o		<=	`EXOP_SRA;
								alusel_o	<=	`EXRES_SHIFT;
								r1_enable_o	<=	1'b1;
								r2_enable_o	<=	1'b0;
								r1_addr_o	<=	rs1;
								r2_addr_o	<=	rs2;
								imm			<=	{27'h0, rs2};
								w_enable_o	<=	`WriteEnable;
								w_addr_o	<=	rd;
								instvalid	<=	`InstValid;
								pre_ld	<=	1'b0;
							end

						 	default:
							begin
								aluop_o			<=	`EXOP_NOP;
								alusel_o		<=	`EXRES_NOP;
								r1_enable_o		<=	1'b0;
								r2_enable_o		<=	1'b0;
								r1_addr_o		<=	`NOPRegAddr;
								r2_addr_o		<=	`NOPRegAddr;
								w_enable_o		<= 	`WriteDisable;
								w_addr_o		<= 	`NOPRegAddr;
								instvalid		<=	`InstValid;
								imm 			<=	`ZeroWord;

								pre_ld		<=	1'b0;
							end
						endcase
					end

					default:
					begin
						aluop_o			<=	`EXOP_NOP;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b0;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	`NOPRegAddr;
						r2_addr_o		<=	`NOPRegAddr;
						w_enable_o		<= 	`WriteDisable;
						w_addr_o		<= 	`NOPRegAddr;
						instvalid		<=	`InstValid;
						imm 			<=	`ZeroWord;

						pre_ld		<=	1'b0;
					end
				endcase
			end
			
			`OP:
			begin
				case (funct3)
					`FUNCT3_ADD_SUB:
					begin
						case (funct7)
							`FUNCT7_ADD:
							begin
								aluop_o		<=	`EXOP_ADD;
								alusel_o	<=	`EXRES_ARITH;
								r1_enable_o	<=	1'b1;
								r2_enable_o	<=	1'b1;
								r1_addr_o	<=	rs1;
								r2_addr_o	<=	rs2;
								imm			<=	`ZeroWord;
								w_enable_o	<=	`WriteEnable;
								w_addr_o	<=	rd;
								instvalid	<=	`InstValid;
								pre_ld	<=	1'b0;
							end

							`FUNCT7_SUB:
							begin
								aluop_o		<=	`EXOP_SUB;
								alusel_o	<=	`EXRES_ARITH;
								r1_enable_o	<=	1'b1;
								r2_enable_o	<=	1'b1;
								r1_addr_o	<=	rs1;
								r2_addr_o	<=	rs2;
								imm			<=	`ZeroWord;
								w_enable_o	<=	`WriteEnable;
								w_addr_o	<=	rd;
								instvalid	<=	`InstValid;
								pre_ld	<=	1'b0;
							end
							default:
							begin
								aluop_o			<=	`EXOP_NOP;
								alusel_o		<=	`EXRES_NOP;
								r1_enable_o		<=	1'b0;
								r2_enable_o		<=	1'b0;
								r1_addr_o		<=	`NOPRegAddr;
								r2_addr_o		<=	`NOPRegAddr;
								w_enable_o		<= 	`WriteDisable;
								w_addr_o		<= 	`NOPRegAddr;
								instvalid		<=	`InstValid;
								imm 			<=	`ZeroWord;

								pre_ld		<=	1'b0;
							end
						endcase
					end

					`FUNCT3_SLL:
					begin
						aluop_o		<=	`EXOP_SLL;
						alusel_o	<=	`EXRES_SHIFT;
						r1_enable_o	<=	1'b1;
						r2_enable_o	<=	1'b1;
						r1_addr_o	<=	rs1;
						r2_addr_o	<=	rs2;
						imm			<=	`ZeroWord;
						w_enable_o	<=	`WriteEnable;
						w_addr_o	<=	rd;
						instvalid	<=	`InstValid;
						pre_ld	<=	1'b0;
					end

					`FUNCT3_SLT:
					begin
						aluop_o		<=	`EXOP_SLT;
						alusel_o	<=	`EXRES_ARITH;
						r1_enable_o	<=	1'b1;
						r2_enable_o	<=	1'b1;
						r1_addr_o	<=	rs1;
						r2_addr_o	<=	rs2;
						imm			<=	`ZeroWord;
						w_enable_o	<=	`WriteEnable;
						w_addr_o	<=	rd;
						instvalid	<=	`InstValid;
						pre_ld	<=	1'b0;
					end

					`FUNCT3_SLTU:
					begin
						aluop_o		<=	`EXOP_SLTU;
						alusel_o	<=	`EXRES_ARITH;
						r1_enable_o	<=	1'b1;
						r2_enable_o	<=	1'b1;
						r1_addr_o	<=	rs1;
						r2_addr_o	<=	rs2;
						imm			<=	`ZeroWord;
						w_enable_o	<=	`WriteEnable;
						w_addr_o	<=	rd;
						instvalid	<=	`InstValid;
						pre_ld	<=	1'b0;
					end

					`FUNCT3_XOR:
					begin
						aluop_o		<=	`EXOP_XOR;
						alusel_o	<=	`EXRES_LOGIC;
						r1_enable_o	<=	1'b1;
						r2_enable_o	<=	1'b1;
						r1_addr_o	<=	rs1;
						r2_addr_o	<=	rs2;
						imm			<=	`ZeroWord;
						w_enable_o	<=	`WriteEnable;
						w_addr_o	<=	rd;
						instvalid	<=	`InstValid;
						pre_ld	<=	1'b0;
					end
					`FUNCT3_SRL_SRA:
					begin
					   case (funct7)
                            `FUNCT7_SRL:
                            begin
                                aluop_o		<=	`EXOP_SRL;
                                alusel_o	<=	`EXRES_SHIFT;
                                r1_enable_o	<=	1'b1;
                                r2_enable_o	<=	1'b1;
                                r1_addr_o	<=	rs1;
                                r2_addr_o	<=	rs2;
                                imm			<=	`ZeroWord;
                                w_enable_o	<=	`WriteEnable;
                                w_addr_o	<=	rd;
                                instvalid	<=	`InstValid;
                                pre_ld	<=	1'b0;
                                
                                
                            end
    
                            `FUNCT7_SRA:
                            begin
                                aluop_o		<=	`EXOP_SRA;
                                alusel_o	<=	`EXRES_SHIFT;
                                r1_enable_o	<=	1'b1;
                                r2_enable_o	<=	1'b1;
                                r1_addr_o	<=	rs1;
                                r2_addr_o	<=	rs2;
                                imm			<=	`ZeroWord;
                                w_enable_o	<=	`WriteEnable;
                                w_addr_o	<=	rd;
                                instvalid	<=	`InstValid;
                                pre_ld	<=	1'b0;
                            end

							default:
							begin
								aluop_o			<=	`EXOP_NOP;
								alusel_o		<=	`EXRES_NOP;
								r1_enable_o		<=	1'b0;
								r2_enable_o		<=	1'b0;
								r1_addr_o		<=	`NOPRegAddr;
								r2_addr_o		<=	`NOPRegAddr;
								w_enable_o		<= 	`WriteDisable;
								w_addr_o		<= 	`NOPRegAddr;
								instvalid		<=	`InstValid;
								imm 			<=	`ZeroWord;

								pre_ld		<=	1'b0;
							end
                        endcase
					end
					
					`FUNCT3_OR:
					begin
						aluop_o		<=	`EXOP_OR;
						alusel_o	<=	`EXRES_LOGIC;
						r1_enable_o	<=	1'b1;
						r2_enable_o	<=	1'b1;
						r1_addr_o	<=	rs1;
						r2_addr_o	<=	rs2;
						imm			<=	`ZeroWord;
						w_enable_o	<=	`WriteEnable;
						w_addr_o	<=	rd;
						instvalid	<=	`InstValid;
						pre_ld	<=	1'b0;
					end

					`FUNCT3_AND:
					begin
						aluop_o		<=	`EXOP_AND;
						alusel_o	<=	`EXRES_LOGIC;
						r1_enable_o	<=	1'b1;
						r2_enable_o	<=	1'b1;
						r1_addr_o	<=	rs1;
						r2_addr_o	<=	rs2;
						imm			<=	`ZeroWord;
						w_enable_o	<=	`WriteEnable;
						w_addr_o	<=	rd;
						instvalid	<=	`InstValid;
						pre_ld	<=	1'b0;
					end
					default:
					begin
						aluop_o			<=	`EXOP_NOP;
						alusel_o		<=	`EXRES_NOP;
						r1_enable_o		<=	1'b0;
						r2_enable_o		<=	1'b0;
						r1_addr_o		<=	`NOPRegAddr;
						r2_addr_o		<=	`NOPRegAddr;
						w_enable_o		<= 	`WriteDisable;
						w_addr_o		<= 	`NOPRegAddr;
						instvalid		<=	`InstValid;
						imm 			<=	`ZeroWord;

						pre_ld		<=	1'b0;
					end
				endcase
			end
			
			default:
			begin
				aluop_o		<=	`EXOP_NOP;
				alusel_o	<=	`EXRES_NOP;
				r1_enable_o	<=	1'b0;
				r2_enable_o	<=	1'b0;
				r1_addr_o	<=	rs1;
				r2_addr_o	<=	rs2;
				imm			<=	`ZeroWord;
				w_enable_o	<= 	`WriteDisable;
				w_addr_o	<= 	rd;
				instvalid	<=	`InstInvalid;
				pre_ld	<=	1'b0;
				
			end
		endcase
	end
end

always @ (*)
begin
	if (rst)
	begin
		r1_data_o		<=	`ZeroWord;
		r1_stall_req	<= 1'b0;
	end		
	else if (r1_enable_o && ex_pre_ld && ex_w_addr_i == r1_addr_o)
		r1_stall_req	<= 1'b1;
	else if (r1_enable_o && ex_w_enable_i && ex_w_addr_i == r1_addr_o)
	begin
		r1_data_o		<=	ex_w_data_i;
		r1_stall_req	<= 1'b0;
	end		
	else if (r1_enable_o && me_w_enable_i && me_w_addr_i == r1_addr_o)
	begin
		r1_data_o		<=	me_w_data_i;
		r1_stall_req	<= 1'b0;
	end	
	else if (r1_enable_o)
	begin
		r1_data_o		<=	r1_data_i;
		r1_stall_req	<= 1'b0;
	end		
	else if (!r1_enable_o)
	begin
		r1_data_o		<=	imm;
		r1_stall_req	<= 1'b0;
	end		
	else
	begin
		r1_data_o	<=	`ZeroWord;
		r1_stall_req	<= 1'b0;
	end		
end

always @ (*)
begin
	if (rst)
	begin
		r2_data_o		<=	`ZeroWord;
		r2_stall_req	<=	1'b0;
	end
	else if (r2_enable_o && ex_pre_ld && ex_w_addr_i == r2_addr_o)
	begin
		r2_stall_req	<=	1'b1;
	end		
	else if (r2_enable_o && ex_w_enable_i && ex_w_addr_i == r2_addr_o)
	begin
		r2_data_o 		<=	ex_w_data_i;
		r2_stall_req	<=	1'b0;
	end		
	else if (r2_enable_o && me_w_enable_i && me_w_addr_i == r2_addr_o)
	begin
		r2_data_o		<=	me_w_data_i;
		r2_stall_req	<=	1'b0;
	end		
	else if (r2_enable_o)
	begin
		r2_data_o		<=	r2_data_i;
		r2_stall_req	<=	1'b0;
	end		
	else if (!r2_enable_o)
	begin
		r2_data_o		<=	imm;
		r2_stall_req	<=	1'b0;
	end
	else
	begin
		r2_data_o		<=	`ZeroWord;
		r2_stall_req	<=	1'b0;
	end		
end

always @(*)
begin
	if (rst)
	begin
		offset_o	<=	`ZeroWord;
	end
	else
	begin
		offset_o	<=	imm;
	end
end


endmodule
