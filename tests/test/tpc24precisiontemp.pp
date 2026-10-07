{ %CPU=aarch64,x86_64 }
{ %OPT=-O4 -OoNOFASTMATH }
{$ifdef CPULLVM}
program tpc24precisiontemp;

{$mode objfpc}
{$LEGACYPC24 ON}
{$DELPHIORDER ON}
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
  Inputs: array[0..7] of QWord = (
    $0000000000000000, $8000000000000000,
    $3ff0000000000000, $bff0000000000000,
    $3ff0000008000000, $3ff0000010000000,
    $36a0000000000000, $4630000000000000);
  ScaleInputs: array[0..13] of QWord = (
    $0000000000000000, $8000000000000000,
    $3ff0000010000000, $bff0000010000000,
    $3690000000000000, $380fffffe0000000,
    $47effffff0000000, $0000000000000001,
    $7fefffffffffffff, $ffefffffffffffff,
    $7ff0000000000000, $fff0000000000000,
    $7ff8000000000042, $fff0000000000042);

var
  Trace: Integer;

function First(Value: Double): Double;
begin
  Trace := Trace * 10 + 1;
  Result := Value;
end;

function Second(Value: Double): Double;
begin
  Trace := Trace * 10 + 2;
  Result := Value;
end;

function Chain(Value: Double): Double;
begin
  Result := First(Value) * 200 * 0.005;
end;

function OrderedSum(Value: Double): Double;
begin
  Result := First(Value) * 200 * 0.005 + Second(Value);
end;

{$DELPHIORDER OFF}
function Reference(Value: Double): Double;
begin
  Result := Value * 200 * 0.005;
end;
{$DELPHIORDER ON}

function Half(Value: Word): Double;
begin
  Result := Value / 2;
end;

function WidePlusOne(Value: LongInt): Single;
begin
  Result := Value + 1.0;
end;

function Scale(Value: Double; Operation: Integer): Single;
begin
  case Operation of
    0: Result := Value * 2.0;
    1: Result := Value * -0.5;
    2: Result := Value / 2.0;
    3: Result := Value / -0.5;
    4: Result := 2.0 * Value;
    5: Result := Value * Double(1.0e-323);
    6: Result := Value / Double(1.0e-323);
    7: Result := Value * Double(8.98846567431158e307);
  end;
end;

{$LEGACYPC24 OFF}
function ReferenceScale(Value: Double; Operation: Integer): Single;
begin
  { The reference retains the strict Double operation and Single conversion. }
  case Operation of
    0: Result := Single(Value * 2.0);
    1: Result := Single(Value * -0.5);
    2: Result := Single(Value / 2.0);
    3: Result := Single(Value / -0.5);
    4: Result := Single(2.0 * Value);
    5: Result := Single(Value * Double(1.0e-323));
    6: Result := Single(Value / Double(1.0e-323));
    7: Result := Single(Value * Double(8.98846567431158e307));
  end;
end;
{$LEGACYPC24 ON}

{$ifdef CPUAARCH64}
function ReadControl: QWord; assembler; nostackframe;
asm
  mrs x0, fpcr
end;

procedure WriteControl(Value: QWord); assembler; nostackframe;
asm
  msr fpcr, x0
end;

function ReadStatus: QWord; assembler; nostackframe;
asm
  mrs x0, fpsr
end;

procedure WriteStatus(Value: QWord); assembler; nostackframe;
asm
  msr fpsr, x0
end;
{$endif}

function SelectType(Value: Single): Integer; overload;
begin
  Result := 1;
end;

function SelectType(Value: Double): Integer; overload;
begin
  Result := 2;
end;

var
  Input, Actual, Expected: TDoubleBits;
  ActualScale, ExpectedScale: TSingleBits;
  I, Operation, Mode: Integer;
{$ifdef CPUAARCH64}
  SavedControl, SavedStatus, ActualStatus: QWord;
{$endif}
begin
  for I := 0 to High(Inputs) do
    begin
      Input.Bits := Inputs[I];
      Trace := 0;
      Actual.Value := Chain(Input.Value);
      Expected.Value := Reference(Input.Value);
      if (Actual.Bits <> Expected.Bits) or (Trace <> 1) then
        Halt(1);
    end;
  Trace := 0;
  if (OrderedSum(1) <> 2) or (Trace <> 12) then
    Halt(2);
  if (Half(65535) <> 32767.5) or (Half(1) <> 0.5) then
    Halt(3);
  if WidePlusOne(16777217) <> 16777218 then
    Halt(4);
  if SelectType(Chain(1)) <> 2 then
    Halt(5);
{$ifdef CPUAARCH64}
  SavedControl := ReadControl;
  SavedStatus := ReadStatus;
{$endif}
  for Mode := 0 to 3 do
    begin
{$ifdef CPUAARCH64}
      WriteControl(QWord(Mode) shl 22);
{$endif}
      for I := 0 to High(ScaleInputs) do
        for Operation := 0 to 7 do
          begin
            Input.Bits := ScaleInputs[I];
{$ifdef CPUAARCH64}
            WriteStatus($10);
{$endif}
            ActualScale.Value := Scale(Input.Value, Operation);
{$ifdef CPUAARCH64}
            ActualStatus := ReadStatus;
            WriteStatus($10);
{$endif}
            ExpectedScale.Value := ReferenceScale(Input.Value, Operation);
            if ActualScale.Bits <> ExpectedScale.Bits then
              Halt(6);
{$ifdef CPUAARCH64}
            if ActualStatus <> ReadStatus then
              Halt(7);
{$endif}
          end;
    end;
{$ifdef CPUAARCH64}
  WriteControl(SavedControl);
  WriteStatus(SavedStatus);
{$endif}
  WriteLn('ok');
end.
{$else}
program tpc24precisiontemp;
begin
  WriteLn('ok');
end.
{$endif}
