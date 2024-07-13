module Scan #(parameter N=4)
(
	input clk_5000hz,
	input rst_n,
	input [N-1:0] col,
	output reg [N-1:0] row,
	output reg [N*N-1:0] keyboard_in
);
reg [3:0] row_idx;
always @(posedge clk_5000hz or negedge rst_n) //扫描一行
begin
	if (!rst_n)
	begin:SB0
		integer i;
		row_idx=0;
		for (i=0;i<=N-1;i=i+1)
			row[i]=1;
		for (i=0;i<=N*N-1;i=i+1)
			keyboard_in[i]=1;
	end
	else begin:SB1
		integer i;
		for (i=0;i<=N-1;i=i+1)
			row[i]=1;
		row[row_idx]=0; //拉低行线
		for (i=0;i<=N-1;i=i+1)
			keyboard_in[row_idx*N+i]=col[i];
		if (row_idx==N-1)
			row_idx=0;
		else
			row_idx=row_idx+1;
	end
end	
endmodule