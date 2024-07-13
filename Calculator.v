module Calculator(
	input clk,
	input rst_n,
	input [3:0] col,
	input lParenthesis,rParenthesis,
	input key_dot,
	input mode_sw,
	output [3:0] row,
	output [7:0] se,
	output [7:0] oSEG,
	output bz,
	output reg led,
	output reg [7:0] opIndicator,
	output reg exceptionIndicator,
	output reg parenthesisIndicator
);

parameter idle=3'b001,userInput=3'b010,calculated=3'b100;
parameter BITWidth=20;
wire signed [5:0] key_in;
reg [2:0] CurrentState,NextState;
reg signed [BITWidth-1:0] CurrentNumber,PreviousNumber; //当前输入的数，[打拍更新法（已作废）]
reg [2:0] NumberLength;//为了回退和显示方便维护数的十进制长度（已改为传递长度参数）
//reg [2:0] CurrentNumberLength;
//reg [BITWidth-1:0] CurrentNumberSubtract;
reg inputNumberUpdated,inputOpUpdated;
reg dotUpdated;

reg signed [BITWidth-1:0] NumberStack[7:0]; 
//reg [2:0] NumberStackNumLength[7:0];
reg [5:0] OpStack[7:0];   
reg [3:0] NumberStackSize,OpStackSize;
reg [3:0] RealOpSize;
reg [3:0] InternalOpSize;
reg [3:0] dotPos[1:0]; //小数点位置（输入)

reg signed [BITWidth-1:0] Number1,Number2,NumberRes;
reg [5:0] OpFetch;

reg signbit;
reg zeroPressed;//供处理前导0

//reg calculatedMutexLock;

integer i;//供复位清空栈使用

reg inputCalc; //
reg ALUError;
reg DelayClear;//上一输入右括号（高有效）
reg MinusExclusive;//消除溢出警报

wire clk_1000hz;
Divider_12MHz_1000hz FDC0 (.clk_12MHz(clk),.clk_out(clk_1000hz)); //单个按键消抖

wire dot; //高电平有效
Debounce_Single DCD0(.clk_1000hz(clk_1000hz),.key(key_dot),.isPressed(dot),.rst_n(rst_n));

wire LeftP,RightP; //左右括号（消抖后）

Debounce_Single DC0 (.clk_1000hz(clk_1000hz),.key(lParenthesis),.isPressed(LeftP),.rst_n(rst_n));
Debounce_Single DC1 (.clk_1000hz(clk_1000hz),.key(rParenthesis),.isPressed(RightP),.rst_n(rst_n));

Keyboard CK0(.clk(clk),.rst_n(rst_n),.col(col),.row(row),.num(key_in));
SegDisplay CSD0 (.clk(clk),.rst_n(rst_n),
.num(PreviousNumber),.numLength(NumberLength),.dotPos(dotPos[NumberStackSize]),
.CurrentState(CurrentState),.se(se),.oSEG(oSEG),.sign(signbit),.mode(mode_sw));

//在时序电路中处理数据（当前数字）避免出现竞争
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		MinusExclusive<=0;
		DelayClear<=0;
		InternalOpSize<=0;
		RealOpSize<=0;
		inputOpUpdated<=1'b1;
		opIndicator<=8'b11111111;
		parenthesisIndicator<=1'b1;
		ALUError<=0;
		led<=0;
		CurrentState<=idle;
		PreviousNumber<=0;
		CurrentNumber<=0;
		NumberStackSize<=0;
		OpStackSize<=0;
		//calculatedMutexLock<=0;
		inputCalc<=0;
		NumberLength<=0;
		signbit<=0;
		zeroPressed<=0;
		//清空栈
		for (i=0;i<=7;i=i+1)
		begin
			NumberStack[i]<=0;
			//NumberStackNumLength[i]<=0;
			OpStack[i]<=0;
		end
		dotPos[0]<=10;
		dotPos[1]<=10;
	end
	else begin
		if (!mode_sw) begin //整数连续四则运算模式
				if (CurrentNumber[BITWidth-1]==1) //补码是负数转成绝对值
				begin
					PreviousNumber<=~CurrentNumber+1;
					signbit<=1;
				end
				else begin
					PreviousNumber<=CurrentNumber;
					signbit<=0;
				end
				if (PreviousNumber>=10000000)
					NumberLength=8;
				else if (PreviousNumber>=1000000)
					NumberLength=7;
				else if (PreviousNumber>=100000)
					NumberLength=6;
				else if (PreviousNumber>=10000)
					NumberLength=5;
				else if (PreviousNumber>=1000)
					NumberLength=4;
				else if (PreviousNumber>=100)
					NumberLength=3;
				else if (PreviousNumber>=10)
					NumberLength=2;
				else if (PreviousNumber>=1)
					NumberLength=1;
				else if (zeroPressed)
					NumberLength=1;
				else
					NumberLength=0;
				if (CurrentState==idle) 
				begin
					led<=8'b00000000;
					CurrentNumber<=0;
				end
				else if (CurrentState==userInput) begin
					led<=1;
					//PreviousNumber<=CurrentNumber;
					if (LeftP) begin //左括号直接加（提醒：若直接在数后（而不是操作符）加左括号可能是非法的）
						if (!inputOpUpdated) begin 
							parenthesisIndicator<=1'b0;
							inputOpUpdated<=1;
							OpStackSize=OpStackSize+1;
							OpStack[OpStackSize]=1;//左括号-1
							InternalOpSize<=0;
						end
					end
					else if (RightP) begin //右括号说明要与左括号匹配，进行相应的运算及一系列运算
						if (!inputOpUpdated||inputCalc) begin
							if (!inputOpUpdated) begin
								inputOpUpdated<=1;
								NumberStackSize=NumberStackSize+1;
								NumberStack[NumberStackSize]=CurrentNumber;
								//拿到后面运算符CurrentNumber=0;
								DelayClear<=1;
							end
							//对比当前运算符和栈顶运算符优先级，并且要将相应的左括号给弹出
							if (OpStackSize>0) begin
								case (OpStack[OpStackSize])
									1:begin
										inputCalc=0;//遇到左括号就停止了
										parenthesisIndicator<=1'b1;
									end
									10: begin
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1+Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
										CurrentNumber=NumberRes;
										inputCalc=1;
										InternalOpSize=InternalOpSize-1;
									end
									11: begin
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1-Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
										CurrentNumber=NumberRes;
										inputCalc=1;
										InternalOpSize=InternalOpSize-1;
									end
									13: begin
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1*Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
										CurrentNumber=NumberRes;
										inputCalc=1;
										InternalOpSize=InternalOpSize-1;
									end
									15: begin
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1/Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
										CurrentNumber=NumberRes;
										inputCalc=1;
										InternalOpSize=InternalOpSize-1;
									end
								endcase
								OpStackSize=OpStackSize-1;
							end
						end	
					end
					else if (key_in==16) begin 
						inputOpUpdated<=0;//若连续按下多次运算符，是按照运算符之间输入的是0处理
						inputNumberUpdated<=0;
						inputCalc<=0;
						//CurrentNumberSubtract=1;
					end
					else if (key_in<10) begin //处理输入的是数位
						opIndicator<=8'b11111111;
						if (!inputNumberUpdated) begin
							inputNumberUpdated<=1;
							CurrentNumber=CurrentNumber*'sd10+key_in;
							zeroPressed<=1;
							//CurrentNumberLength<=CurrentNumberLength+1;
						end
					end
					else if (key_in==14) begin //输入的是回退键
						if (!inputOpUpdated)
						begin
							inputOpUpdated<=1;
							/* 这段代码用于从左向右退位
							for (i=0;i<CurrentNumberLength;i=i+1)
								CurrentNumberSubtract=10*CurrentNumberSubtract;
							CurrentNumber=CurrentNumber-(CurrentNumber/CurrentNumberSubtract)*CurrentNumberSubtract;
							*/
							CurrentNumber=CurrentNumber/'sd10; //正常意义下的退位
							//CurrentNumberLength=CurrentNumberLength-1;
							//NumberStackNumLength[NumberStackSize]=CurrentNumberLength;
						end
					end
					else if (key_in!=12) begin //处理输入的是运算符
						case (key_in)
							10:opIndicator<=8'b11111100;
							11:begin opIndicator<=8'b11110011; MinusExclusive<=1; end
							13:opIndicator<=8'b11001111;
							15:opIndicator<=8'b00111111;
						endcase
						signbit<=0;
						zeroPressed<=0;
						if (!inputOpUpdated||inputCalc) begin
							if (!inputOpUpdated)
							begin
								inputOpUpdated<=1;
								if (!DelayClear) begin
								   NumberStackSize=NumberStackSize+1;
									NumberStack[NumberStackSize]=CurrentNumber;
								end
								DelayClear=0;
								//NumberStackNumLength[NumberStackSize]=CurrentNumberLength;
								CurrentNumber=0;
								//CurrentNumberLength=0;
							end
							//对比当前运算符和栈顶运算符优先级，编写时只有+-*/没有括号和其他，检查边界！！！
							//现加入括号对执行条件进行修改，引入新计数器而非符号栈指针
							inputCalc=0;
							if (parenthesisIndicator==0) begin //只处理括号内
								if (InternalOpSize>1) begin
									if ((key_in==10||key_in==11)) //遇到+-,要把*/都处理
									begin
										if (OpStack[OpStackSize]==13) // *，这两个应是while，在下面加入变量inputCalc
										begin
											OpStackSize=OpStackSize-1;
											InternalOpSize=InternalOpSize-1;
											Number2=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											Number1=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											NumberRes=Number1*Number2;
											NumberStackSize=NumberStackSize+1;
											NumberStack[NumberStackSize]=NumberRes;
										end
										else if (OpStack[OpStackSize]==15) // /
										begin
											OpStackSize=OpStackSize-1;
											InternalOpSize=InternalOpSize-1;
											Number2=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											Number1=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											NumberRes=Number1/Number2;
											NumberStackSize=NumberStackSize+1;
											NumberStack[NumberStackSize]=NumberRes;
										end
										else if (OpStack[OpStackSize]==10) // + -也要及时处理，不然负数就出错
										begin
											OpStackSize=OpStackSize-1;
											InternalOpSize=InternalOpSize-1;
											Number2=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											Number1=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											NumberRes=Number1+Number2;
											NumberStackSize=NumberStackSize+1;
											NumberStack[NumberStackSize]=NumberRes;	
										end
										else if (OpStack[OpStackSize]==11) //注意这只支持两个数操作，想要更多得加括号
										begin
											OpStackSize=OpStackSize-1;
											InternalOpSize=InternalOpSize-1;
											Number2=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											Number1=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											NumberRes=Number1-Number2;
											NumberStackSize=NumberStackSize+1;
											NumberStack[NumberStackSize]=NumberRes;	
										end
										if (InternalOpSize>0)
											inputCalc=1;
										else 
											inputCalc=0;
									end
									else if (key_in==15) //除法也得单列防止被截0
									begin
										if (OpStack[OpStackSize]==13) //乘法得先算完
										begin
											OpStackSize=OpStackSize-1;
											InternalOpSize=InternalOpSize-1;
											Number2=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											Number1=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											NumberRes=Number1*Number2;
											NumberStackSize=NumberStackSize+1;
											NumberStack[NumberStackSize]=NumberRes;
										end
										if (OpStack[OpStackSize]==13)
											inputCalc=1;
										else
											inputCalc=0;
									end
									else if (key_in==13)
									begin
										if (OpStack[OpStackSize]==15) //除法得先算完
										begin
											OpStackSize=OpStackSize-1;
											InternalOpSize=InternalOpSize-1;
											Number2=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											Number1=NumberStack[NumberStackSize];
											NumberStackSize=NumberStackSize-1;
											NumberRes=Number1/Number2;
											NumberStackSize=NumberStackSize+1;
											NumberStack[NumberStackSize]=NumberRes;
										end
										if (OpStack[OpStackSize]==15)
											inputCalc=1;
										else
											inputCalc=0;
									end
								end
							end
							else if (RealOpSize>0) begin
								if ((key_in==10||key_in==11)) //遇到+-,要把*/都处理
								begin
									if (OpStack[OpStackSize]==13) // *，这两个应是while，在下面加入变量inputCalc
									begin
										OpStackSize=OpStackSize-1;
										RealOpSize=RealOpSize-1;
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1*Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
									end
									else if (OpStack[OpStackSize]==15) // /
									begin
										OpStackSize=OpStackSize-1;
										RealOpSize=RealOpSize-1;
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1/Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
									end
									else if (OpStack[OpStackSize]==10) // + -也要及时处理，不然负数就出错
									begin
										OpStackSize=OpStackSize-1;
										RealOpSize=RealOpSize-1;
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1+Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;	
									end
									else if (OpStack[OpStackSize]==11) //注意这只支持两个数操作，想要更多得加括号
									begin
										OpStackSize=OpStackSize-1;
										RealOpSize=RealOpSize-1;
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1-Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;	
									end
									if (RealOpSize>0)
										inputCalc=1;
									else 
										inputCalc=0;
								end
								else if (key_in==15) //除法也得单列防止被截0
								begin
									if (OpStack[OpStackSize]==13) //乘法得先算完
									begin
										OpStackSize=OpStackSize-1;
										RealOpSize=RealOpSize-1;
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1*Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
									end
									if (OpStack[OpStackSize]==13)
										inputCalc=1;
									else
										inputCalc=0;
								end
								else if (key_in==13)
								begin
									if (OpStack[OpStackSize]==15) //除法得先算完
									begin
										OpStackSize=OpStackSize-1;
										RealOpSize=RealOpSize-1;
										Number2=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										Number1=NumberStack[NumberStackSize];
										NumberStackSize=NumberStackSize-1;
										NumberRes=Number1/Number2;
										NumberStackSize=NumberStackSize+1;
										NumberStack[NumberStackSize]=NumberRes;
									end
									if (OpStack[OpStackSize]==15)
										inputCalc=1;
									else
										inputCalc=0;
								end
							end
							if (inputCalc==0)
							begin
								OpStackSize=OpStackSize+1;
								if (!parenthesisIndicator) 
									InternalOpSize=InternalOpSize+1;
								else
									RealOpSize=RealOpSize+1;
								OpStack[OpStackSize]=key_in;
							end
						end
					end
					else if (key_in==12) begin //等号出现也要直接将数入栈，排除最后输入是括号的情况
						if (!inputOpUpdated) begin
							inputOpUpdated<=1;
							if (!DelayClear) begin
								NumberStackSize=NumberStackSize+1;
								NumberStack[NumberStackSize]=CurrentNumber;
							end
							CurrentNumber=0;
						end
					end
				end
				else if (CurrentState==calculated) begin			
					if (OpStackSize>0) begin
						//calculatedMutexLock=1;
						OpFetch=OpStack[OpStackSize];
						OpStackSize=OpStackSize-1;
						led=0;
						Number2=NumberStack[NumberStackSize];
						NumberStackSize=NumberStackSize-1;
						Number1=NumberStack[NumberStackSize];
						NumberStackSize=NumberStackSize-1;
						case (OpFetch) 
							10:NumberRes=Number1+Number2;
							11:NumberRes=Number1-Number2; 
							13:NumberRes=Number1*Number2; 
							15:NumberRes=Number1/Number2;
							default: NumberRes=999;
						endcase
						if (!MinusExclusive&&NumberRes[BITWidth-1]==1)
							ALUError<=1;
						CurrentNumber=NumberRes;
						NumberStackSize=NumberStackSize+1;
						NumberStack[NumberStackSize]=NumberRes;
						//NumberStackNumLength[NumberStackSize]+NumberStackNumLength[NumberStackSize+1];
						//calculatedMutexLock=0;
						//CurrentNumberLength=NumberStackNumLength[NumberStackSize];
					end
					else 
						CurrentNumber=NumberStack[NumberStackSize];	
				end
			CurrentState<=NextState;
		end
		else begin //二元运算模式（拓展至支持小数点）
			if (CurrentNumber[BITWidth-1]==1) //补码是负数转成绝对值
			begin
				PreviousNumber<=~CurrentNumber+'sd1;
				signbit<=1;
			end
			else begin
				PreviousNumber<=CurrentNumber;
				signbit<=0;
			end
			if (PreviousNumber>=10000000)
				NumberLength=8;
			else if (PreviousNumber>=1000000)
				NumberLength=7;
			else if (PreviousNumber>=100000)
				NumberLength=6;
			else if (PreviousNumber>=10000)
				NumberLength=5;
			else if (PreviousNumber>=1000)
				NumberLength=4;
			else if (PreviousNumber>=100)
				NumberLength=3;
			else if (PreviousNumber>=10)
				NumberLength=2;
			else if (PreviousNumber>=1)
				NumberLength=1;
			else if (zeroPressed)
				NumberLength=1;
			else
				NumberLength=0;
			if (CurrentState==idle) 
			begin
				led<=0;
				CurrentNumber=0;
			end
			else if (CurrentState==userInput) begin
				led<=1;
				//小数点输入
				if (dot&&!dotUpdated) begin
					dotUpdated<=1;
					dotPos[NumberStackSize]=0;
				end
				if (!dot)
					dotUpdated<=0;
				//矩阵键盘输入
				if (key_in==16) begin 
					inputOpUpdated<=0;//若连续按下多次运算符，是按照运算符之间输入的是0处理
					inputNumberUpdated<=0;
					inputCalc<=0;
				end
				else if (key_in<10) begin //处理输入的是数位
					opIndicator<=8'b11111111;
					if (!inputNumberUpdated) begin
						if (dotPos[NumberStackSize]!=10)
							dotPos[NumberStackSize]<=dotPos[NumberStackSize]+1;
						inputNumberUpdated<=1;
						CurrentNumber=CurrentNumber*'sd10+key_in;
						zeroPressed<=1;
						//CurrentNumberLength<=CurrentNumberLength+1;
						end
					end
				else if (key_in==14) begin //输入的是回退键
					if (!inputOpUpdated)
					begin
						if (dotPos[NumberStackSize]==0)
							dotPos[NumberStackSize]=10; //小数点删除，设置为10
						else begin
							dotPos[NumberStackSize]=dotPos[NumberStackSize]-1;
							CurrentNumber=CurrentNumber/'sd10; //正常意义下的退位
						end
						//CurrentNumberLength<=CurrentNumberLength-1;
						inputOpUpdated<=1;
						
					end
				end
				else if (key_in!=12) begin //处理输入的是运算符
					case (key_in)
						10:opIndicator<=8'b11111100;
						11:opIndicator<=8'b11110011;
						13:opIndicator<=8'b11001111;
						15:opIndicator<=8'b00111111;
					endcase
					zeroPressed<=0;
					if ((!inputOpUpdated||inputCalc)) begin
						if (!inputOpUpdated)
						begin
							inputOpUpdated<=1;
							//对小数点进行修正
							if (dotPos[NumberStackSize]==10)
								CurrentNumber=CurrentNumber*'sd100;
							else if (dotPos[NumberStackSize]==1)
								CurrentNumber=CurrentNumber*'sd10;
							else if (dotPos[NumberStackSize]==3)
								CurrentNumber=CurrentNumber/'sd10;
							else if (dotPos[NumberStackSize]==4)
								CurrentNumber=CurrentNumber/'sd100;
							else if (dotPos[NumberStackSize]==5)
								CurrentNumber=CurrentNumber/'sd1000;
							else if (dotPos[NumberStackSize]==6)
								CurrentNumber=CurrentNumber/'sd10000;
							
							NumberStackSize=NumberStackSize+1;
							//针对各种运算修正
							if (NumberStackSize==1&&key_in==15) //除法精度
								CurrentNumber=CurrentNumber*'sd100;
							NumberStack[NumberStackSize]=CurrentNumber;
							CurrentNumber=0;
							if (!(NumberStackSize==2&&mode_sw)) begin
								OpStackSize=OpStackSize+1;
								OpStack[OpStackSize]=key_in;
							end
						end
					end
				end
				else if (key_in==12) begin //等号出现也要直接将数入栈
					if (!inputOpUpdated) begin
						inputOpUpdated<=1;
						//对小数点进行修正
						if (dotPos[NumberStackSize]==10)
							CurrentNumber=CurrentNumber*'sd100;
						else if (dotPos[NumberStackSize]==1)
							CurrentNumber=CurrentNumber*'sd10;
						else if (dotPos[NumberStackSize]==3)
							CurrentNumber=CurrentNumber/'sd10;
						else if (dotPos[NumberStackSize]==4)
							CurrentNumber=CurrentNumber/'sd100;
						else if (dotPos[NumberStackSize]==5)
							CurrentNumber=CurrentNumber/'sd1000;
						else if (dotPos[NumberStackSize]==6)
							CurrentNumber=CurrentNumber/'sd10000;
						NumberStackSize=NumberStackSize+1;
						NumberStack[NumberStackSize]=CurrentNumber;
						CurrentNumber=0;
					end
				end
		   end
			else if (CurrentState==calculated) begin
				if (OpStackSize>0) begin
					OpFetch=OpStack[OpStackSize];
					OpStackSize=OpStackSize-1;
					led=0;
					Number2=NumberStack[NumberStackSize];
					NumberStackSize=NumberStackSize-1;
					
					Number1=NumberStack[NumberStackSize];
					NumberStackSize=NumberStackSize-1;
					case (OpFetch) 
						10:NumberRes=Number1+Number2;
						11:NumberRes=Number1-Number2; 
						13:NumberRes=Number1*Number2/'sd100; 
						15:NumberRes=Number1/Number2;
						default: NumberRes=0;
					endcase
					if (OpFetch!=11&&NumberRes[BITWidth-1]==1)
						ALUError<=1;
					CurrentNumber=NumberRes;
					NumberStackSize=NumberStackSize+1;
					NumberStack[NumberStackSize]=NumberRes;
				end	
			end
		end
		CurrentState<=NextState;
	end
end

//注释掉的PreviousNumber方法虽然仿真没问题，但上板有严重时序问题！！！
always @(CurrentState or key_in or ALUError) //这样子key_in更新后不用处理，CurrentState变化到相应状态再处理
begin
	//CurrentNumber=PreviousNumber;
	case (CurrentState)
		idle:begin
			exceptionIndicator=1;
			if (key_in>=10||LeftP)
				NextState=userInput;
			else
				NextState=userInput;
			//CurrentNumber=0;
		end
		userInput:begin
			exceptionIndicator=1;
			if (key_in==16)
				NextState=userInput;
			else if (key_in==12)
				NextState=calculated;
			else begin
				if (key_in>=10)
				begin
					if (mode_sw&&NumberStackSize==2)
						NextState=calculated; //二元运算模式
					else
						NextState=userInput;
				end
				else begin
					//CurrentNumber=PreviousNumber*10+key_in;
					if (mode_sw&&NumberStackSize==2)
						NextState=calculated; //二元运算模式
					else if ((key_in==0&&CurrentNumber==0&&OpStack[OpStackSize]==15)||CurrentNumber[BITWidth-1]==1||ALUError)
					begin
						NextState=calculated;
						exceptionIndicator=0;
					end
					else
						NextState=userInput;
				end
			end
		end
		calculated:begin	
			if (ALUError)
				exceptionIndicator=0;
			NextState=calculated;
		end
		default:NextState=idle;
	endcase
end

endmodule
			
