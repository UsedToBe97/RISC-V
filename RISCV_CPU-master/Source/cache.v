`timescale 1ns / 1ps
`include "common.vh"

module cacheram
#(
	parameter ADDR_WIDTH = 16,
	parameter DATA_BYTE_WIDTH = 4
)
(
	input CLK,
	input RST,
	
	output reg [8*DATA_BYTE_WIDTH-1:0]	r_data,
	input [ADDR_WIDTH-1:0]				r_addr,
	input 								r_flag,
	input [8*DATA_BYTE_WIDTH-1:0]		w_data,
	input [ADDR_WIDTH-1:0]				w_addr,
	input [DATA_BYTE_WIDTH-1:0]			w_mask,
	input 								w_flag
);
	
	reg [8*DATA_BYTE_WIDTH-1:0]	data[(1<<ADDR_WIDTH)-1:0];
	
	always @(posedge CLK) begin
		if(RST) begin
			r_data <= 0;
		end else begin
			if(r_flag)
				r_data <= data[r_addr];
			if(w_flag) begin
				if(w_mask[0])
					data[w_addr][7:0]	<= w_data[7:0];
				if(w_mask[1])
					data[w_addr][15:8]	<= w_data[15:8];
				if(w_mask[2])
					data[w_addr][23:16]	<= w_data[23:16];
				if(w_mask[3])
					data[w_addr][31:24]	<= w_data[31:24];
			end
		end
	end
endmodule

//Address (32-bit):
//	TAG INDEX WORD_SELECT 00
module cache
#(
	parameter WORD_SELECT_BIT 	= 3,	//block size: 2^3 * 4 = 32 bytes
	parameter INDEX_BIT			= 2,	//block count: 2^2 = 4
	parameter WAYS			= 4
)
(
	input CLK,
	input RST,
	
	//from cpu core
	input wire[1:0]			rw_flag_,	//[0] for read, [1] for write
	input wire[31:0]		addr_,
	output wire[31:0]		r_data,
	input wire[31:0]		w_data_,
	input wire[3:0]			w_mask_,
	output reg 			busy,
	output reg			done,
	
	input 			flush_flag,
	input [31:0]	flush_addr,
	
	//to memory
	output reg [1:0]	mem_rw_flag,
	output reg [31:0]	mem_addr,
	input wire[31:0]	mem_r_data,
	output reg [31:0]	mem_w_data,
	output reg [3:0]	mem_w_mask,
	input 	wire		mem_busy,
	input	wire		mem_done
);

	localparam TAG_BIT			= 32 - 2 - INDEX_BIT - WORD_SELECT_BIT;
	localparam BYTE_SELECT_BIT	= WORD_SELECT_BIT + 2;
	localparam SET_SELECT_BIT	= `CLOG2(WAYS); // the bit to choose way
	localparam NBLOCK 			= 1 << INDEX_BIT; // the number of sets
	localparam NWORD			= 1 << WORD_SELECT_BIT; 
	localparam BLOCK_SIZE 		= (1 << WORD_SELECT_BIT) * 4 * 8;
	
	
	
	reg [1:0]	pending_rw_flag;
	reg [31:0]	pending_addr;
	reg [31:0]	pending_w_data;
	reg [3:0]	pending_w_mask;
	
	wire [1:0]	rw_flag			= busy ? pending_rw_flag	: rw_flag_;
	wire [31:0]	addr			= busy ? pending_addr		: addr_;
	wire [31:0]	w_data_in	= busy ? pending_w_data : w_data_;
	wire [3:0]	w_mask_in	= busy ? pending_w_mask : w_mask_;
	
	
	
	wire [TAG_BIT-1:0] 			addr_tag 	= addr[31:31-TAG_BIT+1];
	wire [INDEX_BIT-1:0]		addr_index	= addr[BYTE_SELECT_BIT+INDEX_BIT-1:BYTE_SELECT_BIT];
	wire [WORD_SELECT_BIT-1:0]	addr_ws		= addr[WORD_SELECT_BIT+2-1:2];
	
	wire [TAG_BIT-1:0]			addr_flush_tag		= flush_addr[31:31-TAG_BIT+1];
	wire [INDEX_BIT-1:0]		addr_flush_index	= flush_addr[BYTE_SELECT_BIT+INDEX_BIT-1:BYTE_SELECT_BIT];
	
	//reg [7:0]					data[3:0][WAYS-1:0][NBLOCK-1:0][NWORD-1:0];
	//(*ramstyle = "block"*) reg [31:0]	data[WAYS-1:0][NBLOCK*NWORD-1:0];
	reg [TAG_BIT-1:0]			tag[WAYS-1:0][NBLOCK-1:0];
	reg 						valid[WAYS-1:0][NBLOCK-1:0];
	reg [SET_SELECT_BIT-1:0]	recuse[WAYS-1:0][NBLOCK-1:0];
	
	reg [SET_SELECT_BIT-1:0]	recent_use_counter[NBLOCK-1:0];
	
	wire [WAYS-1:0]			found_in_cache, found_in_cache_flush;
	wire [SET_SELECT_BIT-1:0]	one_hot_lookup[(1<<WAYS)-1:0];
	
	wire [SET_SELECT_BIT-1:0]	lru_tmp[(1<<SET_SELECT_BIT)*2-1:1];
	wire [SET_SELECT_BIT-1:0]	mru_tmp[(1<<SET_SELECT_BIT)*2-1:1];
	wire [SET_SELECT_BIT-1:0]	lru_id_tmp[(1<<SET_SELECT_BIT)*2-1:1];
	wire [SET_SELECT_BIT-1:0]	mru_id_tmp[(1<<SET_SELECT_BIT)*2-1:1];
	
	genvar i;
	generate
		for(i=0; i<(1<<WAYS); i=i+1) begin
			assign one_hot_lookup[i] = `CLOG2(i);
		end
		for(i=0; i<WAYS; i=i+1) begin
			assign found_in_cache[i] 		= valid[i][addr_index] && tag[i][addr_index] == addr_tag;
			assign found_in_cache_flush[i]	= valid[i][addr_flush_index] && tag[i][addr_flush_index] == addr_flush_tag;
		end
		for(i=0; i<WAYS; i=i+1) begin
			assign lru_tmp[i+(1<<SET_SELECT_BIT)]		= recent_use_counter[addr_index] - recuse[i][addr_index];
			assign mru_tmp[i+(1<<SET_SELECT_BIT)]		= recent_use_counter[addr_index] - recuse[i][addr_index];
			assign lru_id_tmp[i+(1<<SET_SELECT_BIT)]	= i;
			assign mru_id_tmp[i+(1<<SET_SELECT_BIT)]	= i;
		end
		for(i=WAYS; i<(1<<SET_SELECT_BIT); i=i+1) begin
			assign lru_tmp[i+(1<<SET_SELECT_BIT)]		= {SET_SELECT_BIT{1'b1}};
			assign mru_tmp[i+(1<<SET_SELECT_BIT)]		= 0;
			assign lru_id_tmp[i+(1<<SET_SELECT_BIT)]	= 0;
			assign mru_id_tmp[i+(1<<SET_SELECT_BIT)]	= 0;
		end
		for(i=1; i<(1<<SET_SELECT_BIT); i=i+1) begin
			assign lru_tmp[i]		= lru_tmp[i*2] >= lru_tmp[i*2+1] ? lru_tmp[i*2]		: lru_tmp[i*2+1];
			assign mru_tmp[i]		= mru_tmp[i*2] <  mru_tmp[i*2+1] ? mru_tmp[i*2]		: mru_tmp[i*2+1];
			assign lru_id_tmp[i]	= lru_tmp[i*2] >= lru_tmp[i*2+1] ? lru_id_tmp[i*2]	: lru_id_tmp[i*2+1];
			assign mru_id_tmp[i]	= mru_tmp[i*2] <  mru_tmp[i*2+1] ? mru_id_tmp[i*2]	: mru_id_tmp[i*2+1];
		end
	endgenerate
	
	wire [SET_SELECT_BIT-1:0]	lru_id, mru_id;
	
	assign lru_id = lru_id_tmp[1];
	assign mru_id = mru_id_tmp[1];
	
	task use_cache;
		input [WAYS-1:0]		cache_id;
		
		if(cache_id != mru_id) begin
			recent_use_counter[addr_index] <= recent_use_counter[addr_index] + 1;
			recuse[cache_id][addr_index] <= recent_use_counter[addr_index] + 1;
		end else if(recuse[cache_id][addr_index] != recent_use_counter[addr_index])
			$display("Assertion Failed: recuse[cache_id][addr_index] == recent_use_counter");
	endtask
	
	localparam STATE_IDLE					= 0;
	localparam STATE_WAIT_FOR_READ_PHASE_1	= 1;	//Before Critical Word Reach
	localparam STATE_WAIT_FOR_READ_PHASE_2	= 2;	//After Critical Word Reach
	localparam STATE_WAIT_FOR_WRITE			= 4;
	
	reg [2:0] state;
	reg [2:0] next_state;
	
	reg [SET_SELECT_BIT-1:0]	current_cache;
	reg [TAG_BIT-1:0]			current_tag;
	reg [INDEX_BIT-1:0]			current_block;
	reg [WORD_SELECT_BIT-1:0]	current_word;
	reg [WORD_SELECT_BIT-1:0]	critical_word;
	
	reg signed [SET_SELECT_BIT:0]	w_cache;	//set to -1 if not write
	reg [INDEX_BIT-1:0]				w_block;
	reg [WORD_SELECT_BIT-1:0]		w_word;
	reg [31:0]						w_data;
	//reg 						w_flag;
	reg [3:0]						w_mask;
	
	reg signed [SET_SELECT_BIT:0]	r_cache;		//set to -1 if not read
	reg [INDEX_BIT-1:0]				r_block;
	reg [WORD_SELECT_BIT-1:0]		r_word;
	//reg						r_flag;
	
	reg [SET_SELECT_BIT-1:0]	valid_cache;
	reg [INDEX_BIT-1:0]			valid_block;
	reg 						valid_flag;
	reg [TAG_BIT-1:0]			valid_tag;
	
	reg 						next_done;
	reg [WAYS-1:0]			next_current_cache;
	reg [TAG_BIT-1:0]			next_current_tag;
	reg [INDEX_BIT-1:0]			next_current_block;
	reg [WORD_SELECT_BIT-1:0]	next_current_word;
	reg [WORD_SELECT_BIT-1:0]	next_critical_word;
	
	wire [31:0]					RAM_r_data[WAYS-1:0];
	reg [SET_SELECT_BIT-1:0]	RAM_r_select;
	
	assign r_data = RAM_r_data[RAM_r_select];
	
	generate
		for(i=0; i<WAYS; i=i+1) begin
			wire RAM_r_flag = r_cache == i;
			wire RAM_w_flag = w_cache == i;
			cacheram #(.ADDR_WIDTH(INDEX_BIT+WORD_SELECT_BIT), .DATA_BYTE_WIDTH(4)) RAM(
				CLK, RST, RAM_r_data[i], {r_block, r_word}, RAM_r_flag,
				w_data, {w_block, w_word}, w_mask, RAM_w_flag); 
		end
	endgenerate
	
	always @(posedge CLK or posedge RST) begin
		if(RST) begin
			busy <= 0;
			pending_rw_flag		<= 0;
			pending_addr		<= 0;
			pending_w_data	<= 0;
			pending_w_mask 	<= 0;
		end else if(!busy) begin
			if(!next_done && rw_flag_ != 0) begin
				busy <= 1;
				pending_rw_flag		<= rw_flag_;
				pending_addr		<= addr_;
				pending_w_data	<= w_data_;
				pending_w_mask	<= w_mask_;
			end
		end else if(next_done)
			busy <= 0;
	end
	
	integer j, k;
	always @(posedge CLK/* or posedge RST*/) begin
		if(RST) begin
			done <= 0;
			for(j=0; j<WAYS; j=j+1)
				for(k=0; k<NBLOCK; k=k+1) begin
					recuse[j][k] <= 0;
					valid[j][k] <= 0;
				end
			for(j=0; j<NBLOCK; j=j+1)
				recent_use_counter[j] <= 0;
			state <= STATE_IDLE;
			current_cache <= 0;
			current_block <= 0;
			current_block <= 0;
			current_word <= 0;
			critical_word <= 0;
			RAM_r_select <= 0;
					
			//TODO
		end else begin
			if(!r_cache[SET_SELECT_BIT]) begin
				if(r_block != addr_index)
					$display("Assertion Failed: r_block == addr_index");
				RAM_r_select <= r_cache[SET_SELECT_BIT-1:0];
				use_cache(r_cache);
			end
			if(valid_flag) begin
				valid[valid_cache][valid_block] <= 1;
				tag[valid_cache][valid_block] <= valid_tag;
			end
			if(flush_flag)
				valid[one_hot_lookup[found_in_cache_flush]][addr_flush_index] <= 0;
			state <= next_state;
			done <= next_done;
			current_cache <= next_current_cache;
			current_tag <= next_current_tag;
			current_block <= next_current_block;
			current_word <= next_current_word;
			critical_word <= next_critical_word;
		end
	end
	
	always @(*) begin
		next_state = state;
		next_current_cache = current_cache;
		next_current_tag = current_tag;
		next_current_block = current_block;
		next_current_word = current_word;
		next_critical_word = critical_word;
		next_done = 0;
		
		r_cache = -1;
		r_block = 0;
		r_word = 0;
		
		w_cache = -1;
		w_block = 0;
		w_word = 0;
		w_mask = 0;
		w_data = 0;
		
		valid_cache = 0;
		valid_block = 0;
		valid_flag = 0;
		valid_tag = 0;
		
		mem_rw_flag = 0;
		mem_addr = 0;
		mem_w_data = 0;
		mem_w_mask = 0;
		
		case(state)
		STATE_IDLE: begin
			case(1'b1)
			rw_flag[0]: begin
				if(found_in_cache != 0) begin
					r_cache = one_hot_lookup[found_in_cache];
					r_block = addr_index;
					r_word = addr_ws;
					//r_flag = 1;
					next_done = 1;
				end else begin
					mem_rw_flag = 1;
					mem_addr = {addr_tag, addr_index, addr_ws, 2'b00};
					next_current_cache = lru_id;
					next_current_tag = addr_tag;
					next_current_block = addr_index;
					next_current_word = addr_ws;
					next_critical_word = addr_ws;
					next_state = STATE_WAIT_FOR_READ_PHASE_1;
					valid_cache = lru_id;
					valid_block = addr_index;
					valid_flag = 1;
					valid_tag = addr_tag;
				end
			end
			
			rw_flag[1]: begin
				if(found_in_cache != 0) begin
					w_cache = one_hot_lookup[found_in_cache];
					w_block = addr_index;
					w_word = addr_ws;
					w_data = w_data_in;
					w_mask = w_mask_in;
				end
				mem_rw_flag = 2;
				mem_addr = {addr_tag, addr_index, addr_ws, 2'b00};
				mem_w_data = w_data_in;
				mem_w_mask = w_mask_in;
				next_state = STATE_WAIT_FOR_WRITE;
				next_done = 1;
			end
			endcase
		end
		
		STATE_WAIT_FOR_READ_PHASE_1: begin
			if(mem_done) begin
				w_cache = current_cache;
				w_block = current_block;
				w_word = current_word;
				w_data = mem_r_data;
				w_mask = 4'b1111;
				//w_flag = 1;
				
				//next_done = 1;
				
				next_current_word = critical_word == 0 ? 1 : 0;
				mem_rw_flag = 1;
				mem_addr = {current_tag, current_block, next_current_word, 2'b00};
				next_state = STATE_WAIT_FOR_READ_PHASE_2;
			end
		end
		
		STATE_WAIT_FOR_READ_PHASE_2: begin
			if(mem_done) begin
				w_cache = current_cache;
				w_block = current_block;
				w_word = current_word;
				w_data = mem_r_data;
				w_mask = 4'b1111;
				//w_flag = 1;
				
				next_current_word = critical_word == current_word + 1 ? current_word + 2 : current_word + 1;
				if(next_current_word != 0) begin
					mem_rw_flag = 1;
					mem_addr = {current_tag, current_block, next_current_word, 2'b00};
				end else 
					next_state = STATE_IDLE;
			end
			if(rw_flag[0]) begin
				if(found_in_cache != 0) begin
					if(one_hot_lookup[found_in_cache] == current_cache && addr_index == current_block) begin
						if(addr_ws < current_word) begin
							r_cache = current_cache;
							r_block = current_block;
							r_word = addr_ws;
							//r_flag = 1;
							next_done = 1;
						end
					end else begin
						r_cache = one_hot_lookup[found_in_cache];
						r_block = addr_index;
						r_word = addr_ws;
						//r_flag = 1;
						next_done = 1;
					end
				end
			end
		end
		
		STATE_WAIT_FOR_WRITE: begin
			if(mem_done) begin
				next_state <= STATE_IDLE;
			end
		end
		endcase
	end
	
endmodule
