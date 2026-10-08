{ %OPT=-j4 -O2 }
program tllvmassemblerjobs;

{ The object queue must coexist with mutually dependent implementations and
  finish all objects before linking. Non-LLVM backends use the serial fallback. }
uses ullvmassemblerjobs1, ullvmassemblerjobs2;

begin
  if FirstValue(4)<>13 then
    Halt(1);
  if SecondValue(4)<>15 then
    Halt(2);
  WriteLn('ok');
end.
