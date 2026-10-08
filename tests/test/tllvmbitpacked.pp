{ %OPT=-O2 }
program tllvmbitpacked;
{$mode objfpc}{$inline off}

{ The bit offset of an indexed packed field must have the LLVM integer
  operand's width, including with 32-bit pointers and a 64-bit ALU type. }
type
  TSmall = bitpacked array[0..31] of 0..31;
  TWide = bitpacked array[0..31] of 0..$1fffffff;
var
  Small: TSmall;
  Wide: TWide;
  Expected: array[0..31] of LongWord;
  I, Index: LongInt;
  Value: LongWord;
begin
  FillChar(Small,SizeOf(Small),0);
  FillChar(Wide,SizeOf(Wide),0);
  for I:=0 to 63 do
    begin
      Index:=(I*13) and 31;
      Value:=(LongWord(I)*$432157) and $1fffffff;
      Small[Index]:=Value and 31;
      Wide[Index]:=Value;
      Expected[Index]:=Value;
      if (Small[Index]<>(Value and 31)) or (Wide[Index]<>Value) then
        Halt(1);
    end;
  for I:=0 to 31 do
    if (Small[I]<>(Expected[I] and 31)) or (Wide[I]<>Expected[I]) then
      Halt(2);
  Writeln('ok');
end.
