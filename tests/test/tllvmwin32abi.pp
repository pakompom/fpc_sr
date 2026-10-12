{ %TARGET=win32 }
{ %CPU=i386 }
{ %OPT=-O2 -OoNOFASTMATH }
program tllvmwin32abi;
{$mode objfpc}{$asmmode att}{$inline off}

type
  TSmall = packed record A, B, C: Byte end;
  TPair = record A, B: LongInt end;
  TFloatRecord = record Value: Single end;
  TRegFunction = function(A, B, C, D, E: LongInt): LongInt; register;

{ Handwritten native entry points check LLVM's caller against the existing
  Delphi/FPC ABI, including register order and callee stack cleanup. }
function NativeRegister(A, B, C, D, E: LongInt): LongInt; register; assembler; nostackframe;
asm
  imull $3,%edx
  addl %edx,%eax
  imull $5,%ecx
  addl %ecx,%eax
  movl 8(%esp),%edx
  imull $7,%edx
  addl %edx,%eax
  movl 4(%esp),%edx
  imull $11,%edx
  addl %edx,%eax
end;

function PascalRegister(A, B, C, D, E: LongInt): LongInt; register;
begin
  Result := A + 3*B + 5*C + 7*D + 11*E;
end;

function NativeCaller(F: TRegFunction): LongInt; assembler; nostackframe;
asm
  pushl %ebx
  movl %eax,%ebx
  pushl $4
  pushl $5
  movl $1,%eax
  movl $2,%edx
  movl $3,%ecx
  call *%ebx
  popl %ebx
end;

function NativeStdcall(A, B, C: LongInt): LongInt; stdcall; assembler; nostackframe;
asm
  movl 4(%esp),%eax
  imull $3,8(%esp),%edx
  addl %edx,%eax
  imull $5,12(%esp),%edx
  addl %edx,%eax
end;

function NativePascal(A, B, C: LongInt): LongInt; pascal; assembler; nostackframe;
asm
  movl 12(%esp),%eax
  imull $3,8(%esp),%edx
  addl %edx,%eax
  imull $5,4(%esp),%edx
  addl %edx,%eax
end;

function NativeCdecl(A: LongInt; B: Int64; C: Double): Int64; cdecl; assembler; nostackframe;
asm
  movl 8(%esp),%eax
  movl 12(%esp),%edx
  addl 4(%esp),%eax
  adcl $0,%edx
end;

function NativeMixed(A: LongInt; B: Double; C: LongInt; D: Extended; E: LongInt): Extended; register; assembler; nostackframe;
asm
  { Integer arguments occupy EAX/EDX/ECX; floating arguments occupy the stack
    in reverse order. The ten-byte Extended occupies twelve stack bytes. }
  fldt 4(%esp)
  fldl 16(%esp)
  faddp %st,%st(1)
end;

function PascalInt64(A, B: Int64): Int64;
begin
  Result := A - B;
end;

function EchoPair(Value: TPair): TPair; cdecl;
begin
  Result.A := Value.B + 17;
  Result.B := Value.A - 19;
end;

function FloatRecord: TFloatRecord;
begin
  Result.Value := 1.25;
end;

function NativeFloatBits: LongWord; assembler; nostackframe;
asm
  call FloatRecord
end;

{ The native i386 backend cannot return non-power-of-two record sizes. }
{$ifdef CPULLVM}
function EchoSmall(Value: TSmall): TSmall; cdecl;
begin
  Result.A := Value.C;
  Result.B := Value.B;
  Result.C := Value.A;
end;
{$endif CPULLVM}

function SumSmall(Value: TSmall): LongInt; stdcall;
begin
  Result := Value.A + 3*Value.B + 5*Value.C;
end;

function InlineHigh(Value: QWord): LongWord;
begin
  asm
    movl Value+4,%eax
    movl %eax,Result
  end;
end;

function CompValue(A: Comp; B: LongInt): Comp;
begin
  Result := A + B;
end;

function CurrencyValue(A: Currency; B: LongInt): Currency;
begin
  Result := A + B;
end;

function ExtendedValue(A: Extended; B: LongInt): Extended;
begin
  Result := A + B;
end;

var
  I: LongInt;
  Pair: TPair;
  Small: TSmall;
  F: TRegFunction;
begin
  F := @PascalRegister;
  for I := 1 to 100 do
    begin
      if NativeRegister(1,2,3,4,5) <> 105 then Halt(1);
      if F(1,2,3,4,5) <> 105 then Halt(2);
      if NativeCaller(F) <> 105 then Halt(10);
      if NativeStdcall(1,2,3) <> 22 then Halt(3);
      if NativePascal(1,2,3) <> 22 then Halt(4);
      if NativeCdecl(7,Int64($123456789abcdef0),3.5) <> Int64($123456789abcdef7) then Halt(5);
      if PascalInt64(Int64($123456789abcdef0),17) <> Int64($123456789abcdeDF) then Halt(6);
      Pair.A := 23;
      Pair.B := 29;
      Pair := EchoPair(Pair);
      if (Pair.A <> 46) or (Pair.B <> 4) then Halt(7);
      Small.A := 1;
      Small.B := 2;
      Small.C := 3;
      if SumSmall(Small) <> 22 then Halt(8);
{$ifdef CPULLVM}
      Small := EchoSmall(Small);
      if (Small.A <> 3) or (Small.B <> 2) or (Small.C <> 1) then Halt(11);
{$endif CPULLVM}
      if NativeFloatBits <> $3fa00000 then Halt(12);
      if ExtendedValue(1.25,2) <> 3.25 then Halt(9);
      if CompValue(123456789,2) <> 123456791 then Halt(13);
      if CurrencyValue(1.25,2) <> 3.25 then Halt(14);
      if InlineHigh(QWord($123456789abcdef0)) <> $12345678 then Halt(15);
      if NativeMixed(1,1.25,2,2.5,3) <> 3.75 then Halt(16);
    end;
  WriteLn('ok');
end.
