{ %CPU=x86_64 }
{ %OPT=-O3 -CpX86-64-V2 -CfX86-64-V2 }
program tllvmx86v2;
{$mode objfpc}
uses CPU;

function Bits(Value: QWord): LongInt; noinline;
begin
  Result:=PopCnt(Value);
end;

function CountAbove(Values: PInt64; Count: LongInt; Limit: Int64): LongInt; noinline;
var I: LongInt;
begin
  Result:=0;
  for I:=0 to Count-1 do
    if Values[I]>Limit then Inc(Result);
end;

var
  Values: array[0..63] of Int64;
  I: LongInt;
begin
  if SSE42Support and PopCntSupport then
    begin
      for I:=0 to 63 do Values[I]:=I-32;
      Values[0]:=Low(Int64);
      Values[63]:=High(Int64);
      if CountAbove(@Values[0],Length(Values),-5)<>36 then Halt(1);
      for I:=0 to 63 do
        if Bits(QWord(1) shl I)<>1 then Halt(2);
      if Bits(High(QWord))<>64 then Halt(3);
      WriteLn('ok');
    end
  else
    WriteLn('CPU does not support x86-64-v2');
end.
