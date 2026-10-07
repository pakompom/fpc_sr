{ %OPT=-O2 }
program tllvmmemops;

{$mode objfpc}
{$inline on}

procedure Check(Condition: Boolean);
begin
  if not Condition then
    Halt(1);
end;

function ToSingle(Bits: LongWord): Single;
begin
  Move(Bits, Result, SizeOf(Result));
end;

function ToBits(Value: Single): LongWord;
begin
  Move(Value, Result, SizeOf(Result));
end;

procedure SmallFill(var Value: QWord);
begin
  FillChar(Value, SizeOf(Value), $a5);
end;

var
  Data: array[0..15] of Byte;
  Value: QWord;
  Count: SizeInt;
  Offset: SizeInt;
  Found: PByte;
  i: Integer;
begin
  Check(ToBits(ToSingle($3f800000)) = $3f800000);
  Check(ToBits(ToSingle($80000000)) = $80000000);
  Check(ToBits(ToSingle($7fc00042)) = $7fc00042);
  SmallFill(Value);
  Check(Value = QWord($a5a5a5a5a5a5a5a5));

  for i := 0 to High(Data) do
    Data[i] := i;
  Move(Data[0], Data[1], 15);
  Check(Data[0] = 0);
  for i := 1 to High(Data) do
    Check(Data[i] = i - 1);

  for i := 0 to High(Data) do
    Data[i] := i;
  Move(Data[1], Data[0], 15);
  for i := 0 to High(Data) - 1 do
    Check(Data[i] = i + 1);
  Check(Data[15] = 15);

  Move(Data, Data, SizeOf(Data));
{$ifndef CPUI8086}
  { The 16-bit RTL uses an unsigned count; other targets accept SizeInt. }
  Count := -1;
  Move(Data[0], Data[1], Count);
  FillChar(Data, Count, 0);
{$endif}
  for i := 0 to High(Data) - 1 do
    Check(Data[i] = i + 1);
  Move(PByte(nil)^, PByte(nil)^, 0);
  FillChar(PByte(nil)^, 0, 0);

  { IndexByte's libc implementation returns a pointer into the searched data. }
  for i := 0 to High(Data) do
    Data[i] := i;
  Offset := IndexByte(Data, SizeOf(Data), 9);
  Check(Offset = 9);
  Found := @Data[Offset];
  Found^ := 42;
  Check(Data[9] = 42);
  Check(IndexByte(Data, SizeOf(Data), 9) = -1);
  Check(IndexByte(Data, SizeOf(Data), 42) = Offset);
  Check(IndexByte(PByte(nil)^, 0, 42) = -1);
{$ifndef CPUI8086}
  { A length of -1 searches until the first match, including via rawmemchr. }
  Count := -1;
  Check(IndexByte(Data, Count, 42) = Offset);
{$endif}
  WriteLn('ok');
end.
