module SEG(
	input [5:0] num,
	output reg[7:0] oSEG
);


always @(num)
begin
	case (num)
		0:oSEG=7'b0111111;
		1:oSEG=7'b0000110;
		2:oSEG=7'b1011011;
		3:oSEG=7'b1001111;
		4:oSEG=7'b1100110;
		5:oSEG=7'b1101101;
		6:oSEG=7'b1111100;
		7:oSEG=7'b0000111;
		8:oSEG=7'b1111111;
		9:oSEG=7'b1101111;
		//10:oSEG=7'b1110111;
		//11:oSEG=7'b1111100;
		//12:oSEG=7'b0111001;
		//13:oSEG=7'b1011110;
		//14:oSEG=7'b1111001;
		//15:oSEG=7'b1110001;
		10:oSEG=7'b1000000; //负号
		16:oSEG=8'b10111111;
		17:oSEG=8'b10000110;
		18:oSEG=8'b11011011;
		19:oSEG=8'b11001111;
		20:oSEG=8'b11100110;
		21:oSEG=8'b11101101;
		22:oSEG=8'b11111100;
		23:oSEG=8'b10000111;
		24:oSEG=8'b11111111;
		25:oSEG=8'b11101111;
		default:oSEG=7'b1111111;
	endcase
end

endmodule