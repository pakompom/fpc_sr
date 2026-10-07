{ %CPU=aarch64,x86_64 }
{ %OPT=-O2 -OoNOFASTMATH }
{$ifdef CPULLVM}
program tllvmabs;

{$mode objfpc}
{$inline off}

type
  TDoubleBits = record
    case Boolean of
      False: (Value: Double);
      True: (Bits: QWord);
  end;
  TSingleBits = record
    case Boolean of
      False: (Value: Single);
      True: (Bits: LongWord);
  end;

const
  DoubleInputs: array[0..7] of QWord = (
    $0000000000000000, $8000000000000000,
    $bff8000000000000, $8000000000000001,
    $fff0000000000000, $7ff8000000000042,
    $fff8000000000042, $fff0000000000042);
  SingleInputs: array[0..7] of LongWord = (
    $00000000, $80000000, $bfc00000, $80000001,
    $ff800000, $7fc00042, $ffc00042, $ff800042);

var
  Calls: Integer;

function AbsoluteDouble(Value: Double): Double;
begin
  Result := Abs(Value);
end;

function AbsoluteSingle(Value: Single): Single;
begin
  Result := Abs(Value);
end;

function NextValue: Double;
begin
  Inc(Calls);
  Result := -2;
end;

{$ifdef CPUAARCH64}
function ReadStatus: QWord; assembler; nostackframe;
asm
  mrs x0, fpsr
end;

procedure WriteStatus(Value: QWord); assembler; nostackframe;
asm
  msr fpsr, x0
end;
{$endif}

var
  InputDouble, OutputDouble: TDoubleBits;
  InputSingle, OutputSingle: TSingleBits;
  i: Integer;
{$ifdef CPUAARCH64}
  SavedStatus: QWord;
{$endif}
begin
{$ifdef CPUAARCH64}
  SavedStatus := ReadStatus;
{$endif}
  for i := 0 to High(DoubleInputs) do
    begin
      InputDouble.Bits := DoubleInputs[i];
      InputSingle.Bits := SingleInputs[i];
{$ifdef CPUAARCH64}
      WriteStatus($10); { Preserve an existing inexact flag. }
{$endif}
      OutputDouble.Value := AbsoluteDouble(InputDouble.Value);
      OutputSingle.Value := AbsoluteSingle(InputSingle.Value);
      if OutputDouble.Bits <> (InputDouble.Bits and $7fffffffffffffff) then
        Halt(1);
      if OutputSingle.Bits <> (InputSingle.Bits and $7fffffff) then
        Halt(2);
{$ifdef CPUAARCH64}
      if ReadStatus <> $10 then
        Halt(3);
{$endif}
    end;
{$ifdef CPUAARCH64}
  WriteStatus(SavedStatus);
{$endif}
  if (Abs(NextValue) <> 2) or (Calls <> 1) then
    Halt(4);
  WriteLn('ok');
end.
{$else}
program tllvmabs;
begin
  WriteLn('ok');
end.
{$endif}
