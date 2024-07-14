module Debounce #(parameter N=5)
( 
	input clk_500hz,
	input rst_n,
	input [N*N-1:0] keyboard,
	output reg [N*N-1:0] isPressed
);

reg [N*N-1:0] DFF [19:0];

always @(posedge clk_500hz or negedge rst_n) 
begin:DB0
	integer i,j;
	if (!rst_n)
	begin
		for (i=0;i<=19;i=i+1)
			for (j=0;j<=N*N-1;j=j+1)
				DFF[i][j]=1;
		for (i=0;i<=N*N-1;i=i+1)
			isPressed[i]=0;
	end
	else begin
		for (i=1;i<=19;i=i+1)
			DFF[i]<=DFF[i-1];
		DFF[0]<=keyboard;
		isPressed=keyboard;
		for (i=1;i<=N-1;i=i+1) //按下电平是0，isPressed是1
			isPressed=isPressed|DFF[i];
		isPressed=~isPressed;
	end
end

endmodule