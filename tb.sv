`timescale 1ns/1ps
module tb;
  logic enable;
  ARM arm (enable);
  initial begin
  //$monitor ("time =%0t, ImmSrc %2b, Memtoreg %1b, RegSrc %2b, RegWrite %1b, ALUControl%2b, ALUSrc%2b", $time, arm.ImmSrc, arm.MemtoReg, arm.RegSrc, arm.RegWrite, arm.ALUControl, arm.ALUSrc);
  //$monitor ("time = %0t, CLk = 0%b", $time, arm.CLK);
  $monitor ("time =%0t, CondEx = %b, R1=%0d, R2=%0d, R3=%0d, R4=%0d, data7=%0d", $time, arm.Condition.CondEx, $signed(arm.datapath.reg_f.RAM[1]), $signed(arm.datapath.reg_f.RAM[2]), $signed(arm.datapath.reg_f.RAM[3]), $signed(arm.datapath.reg_f.RAM[4]), $signed(arm.datapath.Dmem.RAM[10]));
  $dumpfile("test1.vcd");
  $dumpvars(0, tb);
  enable=0;
  #1 enable =1;
  #100 enable = 0;
  $finish;
  end
endmodule
