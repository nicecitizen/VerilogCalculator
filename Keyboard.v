 module Keyboard #(parameter N=4)
(
	input clk,
	input rst_n,
	input [N-1:0] col,
	//供仿真使用的时钟
	//input clk_500hz,clk_5000hz,
	output [N-1:0] row,
	//display test
	//output [7:0] se,
	//output [7:0] oSEG,
	//output led,
	//output bz,
	output reg [5:0] num //for test
	//output [N*N-1:0] isPressed
);

assign bz=0;

wire [N*N-1:0] keyboard_in;
wire [N*N-1:0] isPressed;
wire clk_1000hz,clk_5000hz;


Divider_12MHz_1000hz FD0 (.clk_12MHz(clk),.clk_out(clk_1000hz));
Divider_12MHz_5000hz FD1 (.clk_12MHz(clk),.clk_out(clk_5000hz));

Scan S0 (.clk_5000hz(clk_5000hz),.col(col),.row(row),.keyboard_in(keyboard_in),.rst_n(rst_n));
Debounce D0 (.clk_500hz(clk_1000hz),.keyboard(keyboard_in),.isPressed(isPressed),.rst_n(rst_n));

always @(isPressed)
begin
	case(isPressed)
		16'b0000000000000001:num=5'd0;
		16'b0000000000000010:num=5'd4;
		16'b0000000000000100:num=5'd8;
		16'b0000000000001000:num=5'd10; //+
		16'b0000000000010000:num=5'd1;
		16'b0000000000100000:num=5'd5;
		16'b0000000001000000:num=5'd9;
		16'b0000000010000000:num=5'd11; //-
		16'b0000000100000000:num=5'd2;
		16'b0000001000000000:num=5'd6;
		16'b0000010000000000:num=5'd12; //=
		16'b0000100000000000:num=5'd13; //*
		16'b0001000000000000:num=5'd3;
		16'b0010000000000000:num=5'd7;
		16'b0100000000000000:num=5'd14; //clear
		16'b1000000000000000:num=5'd15; // '/'
		default : num=5'd16; //空
	endcase	
end

//仅供输入测试，这个版本Display已移除
//Display Ds0(.num(num),.se(se[0]),.oSEG(oSEG));
//SegDisplay Ds1(.clk(clk),.rst_n(rst_n),.num(num),.se(se),.oSEG(oSEG));
endmodule