{ %CPU=x86_64,i386 }
{ %OPT=-O2 -OoNOFASTMATH }
program tpc24extended;

{$mode objfpc}

{$ifdef FPC_HAS_TYPE_EXTENDED}
type
  TExtendedBits = packed record
    Significand: QWord;
    SignExponent: Word;
  end;

function FromBits(Significand: QWord; SignExponent: Word): Extended;
var
  Bits: TExtendedBits;
begin
  Bits.Significand := Significand;
  Bits.SignExponent := SignExponent;
  Move(Bits, Result, SizeOf(Bits));
end;

procedure Check(Condition: Boolean; Number: LongInt);
begin
  if not Condition then
    begin
      WriteLn('failure ', Number);
      Halt(Number);
    end;
end;

{$LEGACYPC24 ON}
function Add(a, b: Extended): Extended;
begin
  Result := a + b;
end;

function Subtract(a, b: Extended): Extended;
begin
  Result := a - b;
end;

function Multiply(a, b: Extended): Extended;
begin
  Result := a * b;
end;

function Divide(a, b: Extended): Extended;
begin
  Result := a / b;
end;

function Square(a: Extended): Extended;
begin
  Result := Sqr(a);
end;

function Root(a: Extended): Extended;
begin
  Result := Sqrt(a);
end;

function Fraction(a: Extended): Extended;
begin
  Result := Frac(a);
end;

function Exponential(a: Extended): Extended;
begin
  Result := Exp(a);
end;

function TailComparison(a: Extended): Boolean;
begin
  Result := a < 1.0000000000000000001;
end;
{$LEGACYPC24 OFF}

var
  AboveMidpoint, Up, Wide, Tail: Extended;
  ControlWord: Word;
{$endif}
begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
  ControlWord := Get8087CW;
  { The low binary80 bit changes the answer at a binary32 midpoint. }
  AboveMidpoint := FromBits($8000008000000001, $3fff);
  Up := FromBits($8000010000000000, $3fff);
  Tail := FromBits($8000000000000000, $3fc0);
  Check(Multiply(AboveMidpoint, 1) = Up, 1);
  Check(Add(FromBits($8000008000000000, $3fff), Tail) = Up, 2);
  Check(Subtract(3, 2) = 1, 3);
  Check(Divide(3, 2) = 1.5, 4);
  Check(Square(3) = 9, 5);
  Check(Root(9) = 3, 6);
  Check(Fraction(-2.75) = -0.75, 7);
  Check(TailComparison(1), 8);
  Check(not TailComparison(FromBits($8000000000000001, $3fff)), 9);
  { Native Extended retains its exponent range on the cold x87 path. }
  Wide := FromBits($8000000000000000, $43ff);
  Check(Multiply(Wide, 2) = FromBits($8000000000000000, $4400), 10);
  Check(Get8087CW = ControlWord, 11);
  Check(Exponential(1) = FromBits($adf8540000000000, $4000), 12);
  Check(Exponential(10000) = FromBits($f7502d0000000000, $7859), 13);
  Check(Exponential(-10000) = FromBits($847ef80000000000, $07a4), 14);
  Check(Get8087CW = ControlWord, 15);
{$endif}
  WriteLn('ok');
end.
