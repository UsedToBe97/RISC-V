// Attention: this may cause the speed of ID too slow to finish in a cycle
`define ID_BRANCHES
// Attention: this may be slower then the former one!!!
`define ID_JALR


`define ZeroWord		32'h00000000
`define WriteEnable	 	1'b1
`define WriteDisable	1'b0
`define ReadEnable		1'b1
`define ReadDisable	 	1'b0
`define InstValid		1'b1 
`define InstInvalid	 	1'b0
`define InstAddrBus	 	31: 0
`define InstBus		 	31: 0
`define InstAddrWidth	32
`define InstMemNum		131071
`define InstMemNumLog2	17

`define ChipEnable		1'b1
`define ChipDisable		1'b0

// ============= Data Ram ===============
`define DataAddrBus 31:0
`define DataBus 31:0
`define DataMemNum 131071
`define DataMemNumLog2 17
`define ByteWidth 7:0


// ============= Register File ===============
`define RegAddrBus		4:0
`define RegAddrWidth	5
`define RegBus			31:0
`define RegWidth		32
`define NOPRegAddr		5'b00000

`define AluOpBus		10:0
`define AluOutSelBus	2:0

`define EXOP_ADD		11'b00100110000 // Add and sub Overflows are ignored
`define EXOP_SUB 		11'b00100110001
`define EXOP_SLT		11'b00100110100
`define EXOP_SLTU		11'b00100110110 // compares the values as unsigned numbers (i.e., the immediate is rst sign-extended XLEN bits then treated as an unsigned number).
`define EXOP_XOR		11'b00100111000
`define EXOP_OR 		11'b00100111100
`define EXOP_AND		11'b00100111110
`define EXOP_SLL		11'b00100110010 // Shift value in rs1 by the shift amoount in rs2[4:0]
`define EXOP_SRL		11'b00100111010
`define EXOP_SRA		11'b00100111011
`define EXOP_AUIPC		11'b00101110000

`define EXOP_JAL 		11'b11011110000
`define EXOP_JALR		11'b11001110000
`define EXOP_BEQ 		11'b11000110000
`define EXOP_BNE 		11'b11000110010
`define EXOP_BLT 		11'b11000111000
`define EXOP_BGE 		11'b11000111010
`define EXOP_BLTU		11'b11000111100
`define EXOP_BGEU		11'b11000111110

`define EXOP_LB 		11'b00000110000
`define EXOP_LH 		11'b00000110010
`define EXOP_LW 		11'b00000110100
`define EXOP_LBU		11'b00000111000
`define EXOP_LHU		11'b00000111010

`define EXOP_SB		11'b01000110000
`define EXOP_SH		11'b01000110010
`define EXOP_SW		11'b01000110100

`define EXOP_NOP		11'b00000000000

// AluSel
`define EXRES_LOGIC	3'b001
`define EXRES_SHIFT	3'b010
`define EXRES_ARITH	3'b011
`define EXRES_CTRL  	3'b100
`define	EXRES_LD_ST	3'b101
`define EXRES_NOP		3'b000


`define PC_addr     5'h20
// ============ ID instruction related ===============
// opcode related
`define OP_LUI      7'b0110111
`define OP_AUIPC    7'b0010111
`define OP_JAL      7'b1101111
`define OP_JALR     7'b1100111
`define OP_BRANCH   7'b1100011
`define OP_LOAD     7'b0000011
`define OP_STORE    7'b0100011
`define OPI		7'b0010011
`define OP       7'b0110011
`define OP_MISC_MEM 7'b0001111

// funct3
// JALR
`define FUNCT3_JALR 3'b000
// BRANCH
`define FUNCT3_BEQ  3'b000
`define FUNCT3_BNE  3'b001
`define FUNCT3_BLT  3'b100
`define FUNCT3_BGE  3'b101
`define FUNCT3_BLTU 3'b110
`define FUNCT3_BGEU 3'b111
// LOAD
`define FUNCT3_LB   3'b000
`define FUNCT3_LH   3'b001
`define FUNCT3_LW   3'b010
`define FUNCT3_LBU  3'b100
`define FUNCT3_LHU  3'b101
// STORE
`define FUNCT3_SB   3'b000
`define FUNCT3_SH   3'b001
`define FUNCT3_SW   3'b010
// OPI
`define FUNCT3_ADDI      3'b000
`define FUNCT3_SLTI      3'b010
`define FUNCT3_SLTIU     3'b011
`define FUNCT3_XORI      3'b100
`define FUNCT3_ORI       3'b110
`define FUNCT3_ANDI      3'b111
`define FUNCT3_SLLI      3'b001
`define FUNCT3_SRLI_SRAI 3'b101
// OP
`define FUNCT3_ADD_SUB 3'b000
`define FUNCT3_SLL     3'b001
`define FUNCT3_SLT     3'b010
`define FUNCT3_SLTU    3'b011
`define FUNCT3_XOR     3'b100
`define FUNCT3_SRL_SRA 3'b101
`define FUNCT3_OR      3'b110
`define FUNCT3_AND     3'b111
// MISC-MEM
`define FUNCT3_FENCE  3'b000
`define FUNCT3_FENCEI 3'b001

// funct7
`define FUNCT7_SLLI 1'b0
// SRLI_SRAI
`define FUNCT7_SRLI 1'b0
`define FUNCT7_SRAI 1'b1
// ADD_SUB
`define FUNCT7_ADD  1'b0
`define FUNCT7_SUB  1'b1
`define FUNCT7_SLL  1'b0
`define FUNCT7_SLT  1'b0
`define FUNCT7_SLTU 1'b0
`define FUNCT7_XOR  1'b0
// SRL_SRA
`define FUNCT7_SRL 1'b0
`define FUNCT7_SRA 1'b1
`define FUNCT7_OR  1'b0
`define FUNCT7_AND 1'b0
