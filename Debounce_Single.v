module Debounce_Single #(parameter N=5)
( 
	input clk_1000hz,
	input rst_n,
	input key,
	output reg isPressed
);

reg DFF [19:0];

always @(posedge clk_1000hz or negedge rst_n) 
begin:DB0
	integer i,j;
	if (!rst_n)
	begin
		for (i=0;i<=19;i=i+1)
			DFF[i]<=0;
			isPressed=0;
	end
	else begin
		for (i=1;i<=19;i=i+1)
			DFF[i]<=DFF[i-1];
		DFF[0]<=key;
		isPressed=key;
		for (i=1;i<=N-1;i=i+1) //按下电平是0，isPressed是1
			isPressed=isPressed|DFF[i];
		isPressed=~isPressed;
	end
end

endmodule