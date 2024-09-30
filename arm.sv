`timescale 1ns/1ps
//top module
module ARM (input enable);

	logic CLK, PCS, RegW, MemW, PCSrc, RegWrite, MemWrite, MemtoReg, ALUSrc;
	logic [1:0] FlagW, Op, ImmSrc, RegSrc, ALUControl;
	logic [3:0] Cond, ALUflags, Rd;
	logic [5:0] Funct;

	clock_gen clock (enable, CLK);
	Decoder Decoder (Op, Rd, Funct, PCS, RegW, MemW, MemtoReg, ALUSrc, ImmSrc, RegSrc, ALUControl, FlagW);
	Condition Condition ( CLK, PCS, RegW, MemW, FlagW, Cond, ALUflags, PCSrc, RegWrite, MemWrite);
	datapath  datapath (CLK, PCSrc, ALUSrc, MemtoReg, MemWrite, RegWrite, ALUControl, ImmSrc, RegSrc, ALUflags, Cond, Rd, Op, Funct);
endmodule


module Condition (
	input CLK, PCS, RegW, MemW,
	input [1:0] FlagW,
	input [3:0] Cond, ALUflags,
	output logic PCSrc, RegWrite, MemWrite);

	logic [1:0] FlagWrite;
	logic CondEx,N,Z,C,V;
	logic [3:0] Flags;

	assign {N,Z,C,V} = Flags;//append together, MSB = N
	//Logic gates handling
	always_comb begin
		PCSrc = PCS & CondEx;
		RegWrite = RegW & CondEx;
		MemWrite = MemW & CondEx;
		FlagWrite = FlagW & {CondEx,CondEx};
	end	
	//Flags
	flop_en #(2) flop3_2 (CLK, rst, FlagWrite[1], ALUflags[3:2], Flags[3:2]);
	flop_en #(2) flop1_0 (CLK, rst, FlagWrite[0], ALUflags[1:0], Flags[1:0]);
	//Condition Check
	always_comb 
		case (Cond)
			4'b0000: CondEx = Z; //EQ
			4'b0001: CondEx =~Z; //NE
			4'b0010: CondEx = C; //CS/HS
			4'b0011: CondEx = ~C; //CC/LO
			4'b0100: CondEx = N; //MI
			4'b0101: CondEx = ~N; //PL
			4'b0110: CondEx = V; //VS
			4'b0111: CondEx = ~V; //VC
			4'b1000: CondEx = ~Z & C;//HI
			4'b1001: CondEx = Z | ~C;//LS
			4'b1010: CondEx = ~(N ^ V); //GE
			4'b1011: CondEx = N ^ V; //LT
			4'b1100: CondEx = ~Z & ~(N ^ V);//GT
			4'b1101: CondEx = Z | (N ^ V);//LE
			4'b1110: CondEx = 1'b1;
			default: CondEx = 1'bx;
		endcase
endmodule

module Decoder (
	input [1:0] Op,
	input [3:0] Rd,
	input [5:0] Funct,
	output logic PCS, RegW, MemW, MemtoReg, ALUSrc,
	output logic [1:0] ImmSrc, RegSrc, ALUControl, FlagW);

	logic Branch, ALUOp;
	
	//PCS/PC logic
	assign PCS = ((Rd==15) & RegW)|Branch;

	//Main Decoder
	always_comb begin
		Branch = Op[1] & ~Op[0];
		MemtoReg = ~Op[1] & Op[0];
		MemW = ~Op[1] & Op[0] & ~Funct[0];
		ALUSrc =(~Op[1] & Funct[5]) | (~Op[1] & Op[0]) | (Op[1 & ~Op[0]]);
		ImmSrc = Op;
		RegW = (~Op[1] & ~Op[0]) | (~Op[1] & Funct[0]);
		RegSrc[1] = ~Op[1] & Op[0];
		RegSrc[0] = Op[1] & ~Op[0];
		ALUOp = ~Op[1] & ~Op[0]; 
		ALUControl = 2'b00;
		FlagW = 2'b00;
	//ALU Decoder
		if (ALUOp) begin
			case (Funct[4:1])
				4'b0100: begin
					ALUControl = 2'b00;
					FlagW = Funct[0]? 2'b11 : 2'b00;
				end
				4'b0010: begin
					ALUControl = 2'b01;
					FlagW = Funct[0]? 2'b11 : 2'b00;
				end
				4'b0000: begin
					ALUControl = 2'b10;
					FlagW = Funct[0]? 2'b10 : 2'b00;
				end
				4'b1100: begin
					ALUControl = 2'b11;
					FlagW = Funct[0]? 2'b10 : 2'b00;
				end
			endcase
		end
	end
	
endmodule


module  datapath (
	input logic CLK, PCSrc, AluSRC, MemtoReg, MemWrite, RegWrite,
	input logic [1:0] ALUControl, ImmSrc, RegSrc,
	output logic [3:0] ALUflags,
	output logic [3:0] Cond, Rd,
	output logic [1:0] Op,
	output logic [5:0] Funct);

	logic [31:0] next_PC, PC, PCPlus4, PCPlus8, Instr, Extlmm, 
				ScrA, ScrB, ALUresult, WriteData, ReadData, Result;
	logic [3:0] RA1, RA2;

	assign Cond = Instr[31:28];
	assign Op = Instr[27:26];
	assign Funct = Instr[25:20];
	assign Rd = Instr[15:12];

	// Next PC logic
	Plus4 PC_4 (PC, PCPlus4);
	Multiplexer #(32) MUX_PC (PCSrc, Result, PCPlus4, next_PC);
	Program_counter #(32) PC_reg (CLK, rst, next_PC, PC);

	//Intruction handling
	Instr_mem Imem (PC, Instr);
	Multiplexer #(4) MUX_RA1 (RegSrc[0], 4'd15, Instr[19:16], RA1);
	Multiplexer #(4) MUX_RA2 (RegSrc[1], Instr[15:12], Instr[3:0], RA2);
	Plus4 PC_8 (PCPlus4, PCPlus8);
	Extend Extd (ImmSrc, Instr [23:0], Extlmm);

	//Reg file
	reg_file reg_f (CLK, RegWrite, RA1, RA2, Instr[15:12], 
					Result, PCPlus8, ScrA, WriteData);

	//ALU
	Multiplexer #(32) MUX_ALU (AluSRC, Extlmm, WriteData, ScrB);
	ALU ALU_M (ALUControl, ScrA, ScrB, ALUresult,ALUflags);

	//Data memory
	Data_mem Dmem (CLK,MemWrite,ALUresult,WriteData, ReadData);
	Multiplexer #(32) MUX_Dmem (MemtoReg, ReadData, ALUresult, Result);

endmodule

// Arithmetic, locigcal unit
module ALU 
			(input [1:0] ALUControl,
			input [31:0] A,B,
			output logic [31:0] ALUresult,
			output logic [3:0]ALUflags); 
	logic N,Z,C,V;
	logic [31:0] condinvb;
	logic [32:0] sum;
	// logic carryin; // ADC
	// assign carryin = ALUControl[2] ? carry : ALUControl[0]; // ADC
	assign condinvb = ALUControl[0] ? -B : B;
	assign sum = {1'b0,A} + {1'b0,condinvb}; //+ carryin; // ADC
	
	always_comb // non clocked
		casex (ALUControl)
			2'b0?: ALUresult = sum;
			2'b10: ALUresult = A&B;
			2'b11: ALUresult = A|B;
		endcase
	
	assign N=ALUresult[31]; //negative
	assign Z=(ALUresult==32'b00); //zero
	assign C=(sum[32]); // carry
	assign V=(ALUControl[1] == 1'b0) & ~(A[31] ^ B[31] ^ ALUControl[0]) & (A[31] ^ sum[31]);
	//overflow
	assign ALUflags={N,Z,C,V};//append together, MSB = N
endmodule


//Multiplexer 
module Multiplexer
	#(parameter WIDTH = 4) //input bit number
	(input signal,
	input [WIDTH-1:0] in_1,
	input [WIDTH-1:0] in_0,
	output logic [WIDTH-1:0] out);

	always @* // non clocked
		out <= signal? in_1:in_0;
endmodule

//+4
module Plus4 (
	input [31:0] in,
	output logic [31:0] out);
	always_comb // non clocked
		out = in+4;
endmodule

//Extender
module Extend (
	input [1:0] ImmSrc,
	input [23:0] in,
	output logic [31:0] out);

	always @*
	case (ImmSrc) //Immsrc table
		2'b00: out = {24'b0, in[7:0] }; //data processing
		2'b01: out = {20'b0, in[11:0] }; //STR LDR
		2'b10: out = {{6{in[23]}}, in[23:0], 2'b00}; //B
	endcase
	
endmodule


module clock_gen (	
	input      enable,
  	output reg clk);

  parameter FREQ = 100000;  // in kHZ
  parameter PHASE = 0; 		// in degrees
  parameter DUTY = 50;  	// in percentage

  real clk_pd  		= 1.0/(FREQ * 1e3) * 1e9; 	// convert frequenct to ns
  real clk_on  		= DUTY/100.0 * clk_pd; //on time
  real clk_off 		= (100.0 - DUTY)/100.0 * clk_pd; //off time
  real quarter 		= clk_pd/4;
  real start_dly     = quarter * PHASE/90;

  reg start_clk;

  // Initialize variables to zero
  initial begin
    clk <= 0;
    start_clk <= 0;
  end

  // When clock is enabled, delay driving the clock to one in order
  // to achieve the phase effect. start_dly is configured to the
  // correct delay for the configured phase. When enable is 0,
  // allow enough time to complete the current clock period
  always @ (posedge enable or negedge enable) begin
    if (enable) begin
      #(start_dly) start_clk = 1;
    end else begin
      #(start_dly) start_clk = 0;
    end
  end

  // Achieve duty cycle by a skewed clock on/off time and let this
  // run as long as the clocks are turned on.
  always @(posedge start_clk) begin
    if (start_clk) begin
      	clk = 1;

      	while (start_clk) begin
      		#(clk_on)  clk = 0;
    		#(clk_off) clk = 1;
        end

      	clk = 0;
    end
  end
endmodule

module Program_counter 
	#(parameter WIDTH =8) 
	(input logic clk, rst,
	input logic [WIDTH-1:0] next_PC,
	output logic [WIDTH-1:0] PC);
	always_ff @( posedge clk, posedge rst )
		if (rst) PC <= 0;
		else PC <= next_PC;
endmodule

module flop_en //used in condtional logic
	#(parameter WIDTH =8) 
	(input logic clk, rst, en,
	input logic [WIDTH-1:0] d,
	output logic [WIDTH-1:0] q);
	always_ff @( posedge clk, posedge rst )
		if (rst) q <= 0;
		else if (en==1) q <= d;
endmodule

module Instr_mem (	input logic [31:0] addr,
	output logic [31:0] rd);
	logic [31:0] RAM [63:0];
	initial 
		$readmemb("memfile.txt",RAM);	
		
	assign rd = RAM[addr[31:2]]; // word aligned, divided by 4, so that it allign with each RAM,
endmodule

module Data_mem (
	input logic clk, we,
	input logic [31:0] addr, wd,
	output logic [31:0] rd);

	logic [31:0] RAM [14:0];
	assign rd = RAM[addr[31:2]];
	always_ff @( posedge clk )
		if (we) RAM[addr[31:2]] <= wd;
endmodule

module reg_file (
	input logic clk, we3,
	input logic [3:0] a1,a2,a3,
	input logic [31:0] wd, r15,
	output logic [31:0] rd1, rd2);

	logic [31:0] RAM [14:0];
	assign rd1 = (a1 == 4'b1111) ? r15 : RAM[a1];
	assign rd2 = (a2 == 4'b1111) ? r15 : RAM[a2];
	always_ff @(posedge clk)
		if (we3) RAM[a3] <=wd;	//write
endmodule

