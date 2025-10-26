module SegDisplay(
	input clk,
	input rst_n,
	input [24:0] num,
	input [2:0] numLength,
	input sign,
	input [2:0]CurrentState,
	input mode,
	input demo,
	input [3:0] dotPos, //预留不显示，设置成10
	output reg[7:0] se,
	output [7:0] oSEG
);

reg [5:0] digit;
reg [24:0] tmp;
reg [2:0] digitCount; //当前位 
integer i;



SEG SDS0(.num(digit),.oSEG(oSEG));

always @(posedge clk or negedge rst_n)
begin 
	if (!rst_n)
	begin
		digitCount<=0;
		digit<=0;
		for (i=0;i<=7;i=i+1)
			se[i]<=0;
	end
	else begin 
		if (CurrentState==3'b001) //idle状态
		begin
			digitCount<=0;
			digit<=0;
			for (i=0;i<=7;i=i+1)
				se[i]<=1;
		end
		else if (CurrentState==3'b010) //userInput状态
		begin 
			if (!sign) begin
				if (!mode)
				begin
					tmp=num;
					for (i=0;i<=7;i=i+1)
						se[i]<=1;
					se[digitCount]=0;
					for (i=0;i<digitCount;i=i+1)
					begin
						tmp=tmp/10;
					end
					digit=tmp%10;
					if (digitCount+1==numLength)
						digitCount<=0;
					else
						digitCount<=digitCount+1;
				end
				else begin //小数输出模式，这里是自定义位
					tmp=num;
					for (i=0;i<=7;i=i+1)
						se[i]<=1;
					se[digitCount]=0;
					for (i=0;i<digitCount;i=i+1)
					begin
						tmp=tmp/10;
					end
					digit=tmp%10;
					if (digitCount==dotPos)
					digit=digit+16; //16-25
					if ((digitCount+1==numLength&&dotPos!=numLength)||(digitCount==numLength))
						digitCount<=0;
					else
						digitCount<=digitCount+1;
				end
			end
			else begin //有符号（随括号）
				if (!mode) begin
					tmp=num;
					for (i=0;i<=7;i=i+1)
						se[i]<=1;
					se[digitCount]=0;
					for (i=0;i<digitCount;i=i+1)
					begin
						tmp=tmp/10;
					end
					if (digitCount<numLength)
						digit=tmp%10;
					else
						digit=10;
					if (digitCount==numLength)
						digitCount=0;
					else
						digitCount=digitCount+1;
				end
			end
		end
		else if (CurrentState==3'b100)//calculated状态
		begin
			if (!sign) begin
				if (!mode&&!demo)
				begin
					tmp=num;
					for (i=0;i<=7;i=i+1)
						se[i]<=1;
					se[digitCount]=0;
					for (i=0;i<digitCount;i=i+1)
					begin
						tmp=tmp/10;
					end
					digit=tmp%10;
					if (digitCount+1==numLength)
						digitCount<=0;
					else
						digitCount<=digitCount+1;
				end
				else begin //小数输出模式，固定2位
					tmp=num;
					for (i=0;i<=7;i=i+1)
						se[i]<=1;
					se[digitCount]=0;
					for (i=0;i<digitCount;i=i+1)
					begin
						tmp=tmp/10;
					end
					digit=tmp%10;
					if (digitCount==2)
					digit=digit+16; //16-25
					if (numLength>=3)
					begin
						if (digitCount+1==numLength)
							digitCount<=0;
						else
							digitCount<=digitCount+1;
					end
					else
					begin
						if (digitCount==2)
							digitCount<=0;
						else
							digitCount<=digitCount+1;
					end
				end
			end
			else begin //负号显示
				if (!mode) begin
					tmp=num;
					for (i=0;i<=7;i=i+1)
						se[i]<=1;
					se[digitCount]=0;
					for (i=0;i<digitCount;i=i+1)
					begin
						tmp=tmp/10;
					end
					if (digitCount<numLength)
						digit=tmp%10;
					else
						digit=10;
					if (digitCount==numLength)
						digitCount=0;
					else
						digitCount=digitCount+1;
				end
				else begin
					tmp=num;
					for (i=0;i<=7;i=i+1)
						se[i]<=1;
					se[digitCount]=0;
					for (i=0;i<digitCount;i=i+1)
					begin
						tmp=tmp/10;
					end
					if (tmp<0)
						tmp=0;
					digit=tmp%10;
					if (digitCount==2)
					digit=digit+16; //16-25
					if (numLength>=3)
					begin
						if (digitCount==numLength)
						begin
							digitCount=0;
							digit=10;
						end
						else
							digitCount=digitCount+1;
					end
					else
					begin
						if (digitCount==2)
							digitCount=0;
						else
							digitCount=digitCount+1;
					end
				end
			end
		end
	end
end

endmodule