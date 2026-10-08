{ %OPT=-O2 }
program tsetmembershipbounds;
{$mode objfpc}{$inline off}
type
  TSmall = set of 0..29;
  TOffset = set of 32..95;
function SmallContains(B: Byte; const S: TSmall): Boolean;
begin Result:=B in S end;
function OffsetContains(I: LongInt; const S: TOffset): Boolean;
begin Result:=I in S end;
var
  Small: TSmall;
  Offset: TOffset;
  I: LongInt;
begin
  Small:=[0,7,29];
  Offset:=[32,63,95];
  for I:=0 to 255 do
    if SmallContains(I,Small)<>((I=0) or (I=7) or (I=29)) then Halt(1);
  for I:=-32 to 287 do
    if OffsetContains(I,Offset)<>((I=32) or (I=63) or (I=95)) then Halt(2);
  if OffsetContains(High(LongInt),Offset) or
     OffsetContains(Low(LongInt),Offset) then Halt(3);
end.
