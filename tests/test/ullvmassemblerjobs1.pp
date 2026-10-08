unit ullvmassemblerjobs1;
interface
function FirstValue(N: LongInt): LongInt;
implementation
uses ullvmassemblerjobs2;
function FirstValue(N: LongInt): LongInt;
begin
  if N=0 then
    FirstValue:=1
  else
    FirstValue:=SecondValue(N-1)+2;
end;
end.
