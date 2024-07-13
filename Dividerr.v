//12000 2400 seperately
module Divider_12MHz_1000hz #(parameter modulo=12000) (
	input clk_12MHz,
	output reg clk_out
);
reg [26:0] cnt;
always @(posedge clk_12MHz)
begin
	if (cnt==modulo-1)
	begin
		clk_out=1;
		cnt=0;
	end
	else
	begin
		clk_out=0;
		cnt=cnt+1;
	end
end
endmodule	

module Divider_12MHz_5000hz #(parameter modulo=2400) (
	input clk_12MHz,
	output reg clk_out
);
reg [26:0] cnt;
always @(posedge clk_12MHz)
begin
	if (cnt==modulo-1)
	begin
		clk_out=1;
		cnt=0;
	end
	else
	begin
		clk_out=0;
		cnt=cnt+1;
	end
end
endmodule	