{ %CPU=x86_64,i386,aarch64,arm,wasm32 }
{ %OPT=-O2 }
program tllvmmemory;

{$mode objfpc}

{ System-only program: dynamic lengths also exercise any memory libcalls
  introduced by LLVM, without another unit supplying the link dependency. }
var
  Buffer, Expected, Original: array[0..8191] of Byte;
  Count, I: SizeInt;
  Bits: LongWord;
  Value: Single;

procedure ResetBuffers;
var
  J: SizeInt;
begin
  for J:=0 to High(Buffer) do
    begin
      Original[J]:=Byte(J*7);
      Buffer[J]:=Original[J];
      Expected[J]:=Original[J];
    end;
end;

procedure Check(Code: LongInt);
var
  J: SizeInt;
begin
  for J:=0 to High(Buffer) do
    if Buffer[J]<>Expected[J] then
      Halt(Code);
end;

function ReadUnaligned(const Source): LongWord;
begin
  Move(Source,Result,SizeOf(Result));
end;

function ClearUnused: LongInt;
var
  Scratch: array[0..31] of Byte;
begin
  FillChar(Scratch,SizeOf(Scratch),0);
  Result:=17;
end;

begin
  { This remains a runtime length even under whole-program optimization. }
  Count:=4093+ParamCount;
  if Count>4096 then
    Halt(1);

  ResetBuffers;
  Move(Buffer[3],Buffer[7],Count);
  for I:=0 to Count-1 do
    Expected[7+I]:=Original[3+I];
  Check(2);

  ResetBuffers;
  Move(Buffer[7],Buffer[3],Count);
  for I:=0 to Count-1 do
    Expected[3+I]:=Original[7+I];
  Check(3);

  Move(Buffer[3],Buffer[3],Count);
  Check(4);

  ResetBuffers;
  FillChar(Buffer[3],Count,Byte($A5));
  for I:=0 to Count-1 do
    Expected[3+I]:=$A5;
  Check(5);

  for Count:=-2 to 0 do
    begin
      Move(Buffer[3],Buffer[7],Count);
      FillChar(Buffer[7],Count,Byte(0));
    end;
  Move(Buffer[3],Buffer[7],Low(SizeInt));
  FillChar(Buffer[7],Low(SizeInt),Byte(0));
  Check(6);
  Move(PByte(nil)^,PByte(nil)^,0);
  Move(PByte(nil)^,PByte(nil)^,-1);
  FillChar(PByte(nil)^,0,Byte(0));
  FillChar(PByte(nil)^,-1,Byte(0));

  { Fixed-size, byte-aligned operations must still preserve every bit. }
  Bits:=$3F800000;
  Move(Bits,Buffer[1],SizeOf(Bits));
  if ReadUnaligned(Buffer[1])<>Bits then
    Halt(7);
  Move(Bits,Value,SizeOf(Value));
  if Value<>1.0 then
    Halt(8);
  if ClearUnused<>17 then
    Halt(9);
end.
