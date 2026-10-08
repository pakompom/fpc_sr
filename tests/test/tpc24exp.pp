{ %CPU=aarch64,arm,x86_64,i386,wasm32 }
{ %OPT=-O4 -OoNOFASTMATH }
program tpc24exp;
{$mode objfpc}
{$inline off}

uses Math;

type
  TDoubleBits = record
    case Boolean of
      False: (Value: Double);
      True: (Bits: QWord);
  end;

var
  Calls: Integer;

function Input(Value: Double): Double;
begin
  Inc(Calls);
  Result := Value;
end;

{$LEGACYPC24 ON}
{$DELPHIORDER ON}
function Evaluate(Value: Double): Double;
begin
  Result := Exp(Input(Value));
end;

function Speed(Value: Double): Integer;
begin
  Result := Round(500 * Exp(Value));
end;

procedure Check(Value: Double; Expected: QWord; Number: Integer);
var B: TDoubleBits;
begin
  B.Value := Value;
  if B.Bits <> Expected then
    begin
      WriteLn('failure ', Number);
      Halt(Number);
    end;
end;

{$LEGACYPC24 OFF}
function Ordinary(Value: Double): Double;
begin
  Result := Exp(Value);
end;

{$LEGACYPC24 ON}
var B: TDoubleBits;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  Calls := 0;
  Check(Evaluate(-0.254892289638519287109375), $3FE8CCCCC0000000, 1);
  if Calls <> 1 then Halt(2);
  if Speed(-0.254892289638519287109375) <> 388 then Halt(3);
  Check(Evaluate(1), $4005BF0A80000000, 4);
  Check(Evaluate(-1), $3FD78B5640000000, 5);
  { Literal calls must follow the same precision stages as variables. }
  Check(Exp(1.0), $4005BF0A80000000, 6);
  Check(Exp(-0.254892289638519287109375), $3FE8CCCCC0000000, 7);
  { The final result has 24 significant bits, not Single's exponent range. }
  Check(Evaluate(700), $7F0D946760000000, 8);
  Check(Exp(700.0), $7F0D946760000000, 9);
  Check(Evaluate(-745), $0000000000000001, 10);
  Check(Evaluate(-746), 0, 11);
  Check(Evaluate(10000), $7FF0000000000000, 12);
  Check(Evaluate(-10000), 0, 13);
  Check(Evaluate(0), $3FF0000000000000, 14);
  B.Bits := QWord($8000000000000000);
  Check(Evaluate(B.Value), $3FF0000000000000, 15);
  B.Bits := QWord($7FF0000000000000);
  if not IsNan(Evaluate(B.Value)) then Halt(16);
  B.Bits := QWord($FFF0000000000000);
  if not IsNan(Evaluate(B.Value)) then Halt(17);
  B.Bits := QWord($7FF8000000000042);
  if not IsNan(Evaluate(B.Value)) then Halt(18);
  B.Bits := QWord($7FEFFFFFFFFFFFFF);
  Check(Evaluate(B.Value), $7FF0000000000000, 19);
  Check(Evaluate(-B.Value), 0, 20);
  Check(Exp(-1e400), 0, 21);
  Check(Exp(1e400), $7FF0000000000000, 22);
  Check(Exp(1e-400), $3FF0000000000000, 23);
  { PC24 argument reduction must retain the low bits of log2(e). }
  B.Bits := QWord($3FD62E441F53A0E2);
  Check(Evaluate(B.Value), $3FF6A09EE0000000, 24);
  { Retain the Extended literal until argument reduction. Its nearest Double
    lies on the other side of the reduction's rounding boundary. }
  Check(Exp(0.3465736109373683918890261812517650241716182790696620941162109375),
    $3FF6A09E80000000, 25);
  B.Bits := QWord($3FD62E4315287CEE);
  Check(Evaluate(B.Value), $3FF6A09E60000000, 26);
  { Ordinary Exp uses the platform's math implementation, whose last bit can
    differ. It must retain Double precision rather than receive PC24 rounding. }
  if Abs(Ordinary(1)-2.7182818284590452354)>1e-15 then Halt(27);
  Check(Evaluate(710), $7FF0000000000000, 28);
end.
