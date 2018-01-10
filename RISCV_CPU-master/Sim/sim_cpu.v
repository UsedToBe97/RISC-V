`timescale 1ns/1ps


module SimCPU();

reg clk;
reg rst;
wire Rx,Tx;
wire button = ~rst;

initial
begin
	clk= 1'b1;
	forever #10 clk = ~clk;
end

initial
begin
	rst = 1'b1;
	#5000	rst		= 	1'b0;
	#90000000 	rst		= 	1'b1;
	#10000000	$stop;
end

Riscv_cpu Riscv_cpu0(
	.EXCLK(clk),
	.button(button),
	.Tx(Tx),
	.Rx(Rx)
);

sim_memory sm(
	.CLK(clk),
	.RST(rst),
	.Tx(Rx),
	.Rx(Tx)
);


endmodule