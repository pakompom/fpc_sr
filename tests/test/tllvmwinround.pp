{ %TARGET=win64 }
{ %CPU=x86_64 }
{ %OPT=-O2 -OoNOFASTMATH }
program tllvmwinround;

{$mode objfpc}{$inline off}

type
  TBits = record
    case Boolean of
      False: (Value: Double);
      True: (Bits: QWord);
  end;

function NativeRound(Value: Double): Int64; assembler; nostackframe;
asm
  cvtsd2si %xmm0,%rax
end;

function NativeTrunc(Value: Double): Int64; assembler; nostackframe;
asm
  cvttsd2si %xmm0,%rax
end;

function Rounded(Value: Double): Int64;
begin
  Result := Round(Value);
end;

function Truncated(Value: Double): Int64;
begin
  Result := Trunc(Value);
end;

const
  Inputs: array[0..11] of QWord = (
    $0, $8000000000000000, $3ff8000000000000, $bff8000000000000,
    $43dfffffffffffff, $43e0000000000000, $c3e0000000000000,
    $7ff0000000000000, $fff0000000000000, $7ff8000000000042,
    $7ff0000000000042, $1);
var
  Saved, Control, Flags: DWord;
  Mode, I: Integer;
  Value: TBits;
  Expected, Actual: Int64;
begin
  Saved := GetSSECSR;
  for Mode := 0 to 3 do
    for I := Low(Inputs) to High(Inputs) do
      begin
        Value.Bits := Inputs[I];
        { Mask exceptions, disable FTZ/DAZ, select each rounding direction. }
        Control := $1f80 or (DWord(Mode) shl 13);
        SetSSECSR(Control);
        Expected := NativeRound(Value.Value);
        Flags := GetSSECSR;
        SetSSECSR(Control);
        Actual := Rounded(Value.Value);
        if (Expected <> Actual) or (Flags <> GetSSECSR) then Halt(1);
        SetSSECSR(Control);
        Expected := NativeTrunc(Value.Value);
        Flags := GetSSECSR;
        SetSSECSR(Control);
        Actual := Truncated(Value.Value);
        if (Expected <> Actual) or (Flags <> GetSSECSR) then Halt(2);
      end;
  SetSSECSR(Saved);
  WriteLn('ok');
end.
