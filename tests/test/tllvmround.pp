{ %CPU=aarch64 }
{ %OPT=-O2 -OoNOFASTMATH }
program tllvmround;

{$mode objfpc}
{$inline off}

type
  TDoubleBits = record
    case Boolean of
      False: (Value: Double);
      True: (Bits: QWord);
  end;

function ReadFPCR: QWord; assembler; nostackframe;
asm
  mrs x0, fpcr
end;

procedure WriteFPCR(Value: QWord); assembler; nostackframe;
asm
  msr fpcr, x0
end;

function ReadFPSR: QWord; assembler; nostackframe;
asm
  mrs x0, fpsr
end;

procedure WriteFPSR(Value: QWord); assembler; nostackframe;
asm
  msr fpsr, x0
end;

function Rounded(Value: Double): Int64;
begin
  Result := Round(Value);
end;

function Truncated(Value: Double): Int64;
begin
  Result := Trunc(Value);
end;

function Integral(Value: Double): Double;
begin
  Result := Int(Value);
end;

procedure DiscardRound(Value: Double);
var
  Unused: Int64;
begin
  Unused := Round(Value);
end;

procedure Check(Condition: Boolean);
begin
  if not Condition then
    Halt(1);
end;

procedure CheckInteger(Bits: QWord; Expected: Int64; Flags: QWord);
var
  Input: TDoubleBits;
  Actual: Int64;
begin
  Input.Bits := Bits;
  WriteFPSR(0);
  Actual := Rounded(Input.Value);
  Check((Actual = Expected) and (ReadFPSR = Flags));
  WriteFPSR(0);
  Actual := Truncated(Input.Value);
  Check((Actual = Expected) and (ReadFPSR = Flags));
end;

const
  Positive: array[0..3] of Int64 = (2, 2, 1, 1);
  Negative: array[0..3] of Int64 = (-2, -1, -2, -1);
var
  SavedControl, SavedStatus: QWord;
  Mode: Integer;
  Value, Actual: TDoubleBits;
begin
  SavedControl := ReadFPCR;
  SavedStatus := ReadFPSR;
  try
    for Mode := 0 to 3 do
      begin
        { Mask exceptions; select each rounding direction with FZ/DN off. }
        WriteFPCR(QWord(Mode) shl 22);
        Value.Bits := $3ff8000000000000; { 1.5 }
        WriteFPSR(0);
        Check(Rounded(Value.Value) = Positive[Mode]);
        Check(ReadFPSR = $10); { inexact }
        Value.Bits := $bff8000000000000; { -1.5 }
        WriteFPSR(0);
        Check(Rounded(Value.Value) = Negative[Mode]);
        Check(ReadFPSR = $10);
        WriteFPSR(0);
        Check(Truncated(Value.Value) = -1);
        Check(ReadFPSR = $10);
        WriteFPSR(0);
        Actual.Value := Integral(Value.Value);
        Check((Actual.Value = -1) and (ReadFPSR = 0));
        WriteFPSR(0);
        DiscardRound(Value.Value);
        Check(ReadFPSR = $10);
        CheckInteger($43dfffffffffffff, 9223372036854774784, 0);
        CheckInteger($43e0000000000000, High(Int64), 1);
        CheckInteger($c3e0000000000000, Low(Int64), 0);
        CheckInteger($7ff0000000000000, High(Int64), 1);
        CheckInteger($fff0000000000000, Low(Int64), 1);
        CheckInteger($7ff8000000000042, 0, 1); { quiet NaN }
        CheckInteger($7ff0000000000042, 0, 1); { signaling NaN }
        Value.Bits := $8000000000000000; { negative zero }
        Actual.Value := Integral(Value.Value);
        Check(Actual.Bits = Value.Bits);
      end;
  finally
    WriteFPCR(SavedControl);
    WriteFPSR(SavedStatus);
  end;
  WriteLn('ok');
end.
