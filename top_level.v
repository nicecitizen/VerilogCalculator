module top_level(
	input clk,
	input rst_n,
	input [3:0] col,
	output [3:0] row,
	output [7:0] se,
	output [7:0] oSEG,
	output bz,
	output led
);

Calculator TC0 (.clk(clk),.rst_n(rst_n),.col(col),.row(row),.se(se),.oSEG(osEG),.led(led));

endmodule