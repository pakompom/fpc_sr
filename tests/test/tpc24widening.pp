{ %CPU=x86_64,i386,aarch64,arm,wasm32 }
{ %OPT=-O2 -OoNOFASTMATH }
program tpc24widening;
{$mode delphi}{$EXCESSPRECISION ON}{$inline off}
uses Math;

type
  TBits = record
    case Boolean of
      False: (Value: Double);
      True: (Bits: QWord);
  end;
const
  Inputs: array[0..11] of QWord = (
    $0000000000000000, $8000000000000000,
    $3ff0000010000000, $bff0000010000000,
    $3690000000000000, $380fffffe0000000,
    $47effffff0000000, $0000000000000001,
    $7ff0000000000000, $fff0000000000000,
    $7ff8000000000042, $fff0000000000042);
var
  Trace: Integer;

function Consume(Value: Double): Double;
begin
  Result := Value;
end;

{$LEGACYPC24 ON}{$DELPHIORDER ON}
function Scale(Value: Double): Double;
begin
  Result := Value * 2;
end;

function Argument(Value: Double): Double;
begin
  Result := Consume(Value * 2);
end;

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

function Ordered(Value: Double): Double;
begin
  Result := First(Value) * 2 + Second(0);
end;

function SelectType(Value: Single): Integer; overload;
begin
  Result := 1;
end;

function SelectType(Value: Double): Integer; overload;
begin
  Result := 2;
end;

{$LEGACYPC24 OFF}{$EXCESSPRECISION OFF}
function Reference(Value: Double): Double;
begin
  Result := Double(Single(Value * 2));
end;

var
  Input, Actual, Expected: TBits;
  SavedMode: TFPURoundingMode;
  Mode: TFPURoundingMode;
  I: Integer;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  SavedMode := GetRoundMode;
  for Mode := Low(Mode) to High(Mode) do
    begin
      SetRoundMode(Mode);
      for I := Low(Inputs) to High(Inputs) do
        begin
          Input.Bits := Inputs[I];
          Expected.Value := Reference(Input.Value);
          Actual.Value := Scale(Input.Value);
          if Actual.Bits <> Expected.Bits then Halt(1);
          Actual.Value := Argument(Input.Value);
          if Actual.Bits <> Expected.Bits then Halt(2);
        end;
    end;
  SetRoundMode(SavedMode);
  Trace := 0;
  if (Ordered(1) <> 2) or (Trace <> 12) then Halt(3);
  if SelectType(Scale(1)) <> 2 then Halt(4);
end.
