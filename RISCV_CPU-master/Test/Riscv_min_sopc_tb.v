`timescale 1ns/1ps
`include "Riscv_min_sopc.v"

module Riscv_min_sopc_tb();

  reg     CLOCK_50;
  reg     rst;
  
       
  initial begin
    CLOCK_50 = 1'b0;
    forever #10 CLOCK_50 = ~CLOCK_50;
  end
      
  initial begin
    rst = 1'b1;
    #195 rst= 1'b0;
    #4100 $stop;
  end
       
  Riscv_min_sopc Riscv_min_sopc0(
		.clk(CLOCK_50),
		.rst(rst)	
	);

endmodule