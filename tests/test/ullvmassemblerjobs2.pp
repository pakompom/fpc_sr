unit ullvmassemblerjobs2;
interface
function SecondValue(N: LongInt): LongInt;
implementation
uses ullvmassemblerjobs1;
function SecondValue(N: LongInt): LongInt;
begin
  if N=0 then
    SecondValue:=3
  else
    SecondValue:=FirstValue(N-1)+4;
end;
end.
