{ %CPU=x86_64,i386 }
{ %OPT=-O4 -OoNOFASTMATH }
{ Binary80 materialization must not pass through a host Double. }

program tpc24const80;

{$mode objfpc}
{$LEGACYPC24 ON}

{$if sizeof(Extended)=10}
type
  TExtendedBits = packed record
    Significand: QWord;
    SignExponent: Word;
  end;

const
  Coefficient = 0.99;
  Difference = 0.3 - 0.2;
  Stored: Extended = 0.99;

procedure Check(const Value: Extended; Significand: QWord;
  SignExponent: Word; TestNumber: Integer);
var
  Bits: TExtendedBits;
begin
  Move(Value, Bits, SizeOf(Bits));
  if (Bits.Significand <> Significand) or
     (Bits.SignExponent <> SignExponent) then
    Halt(TestNumber);
end;

var
  Value: Extended;
begin
  Value := Coefficient;
  Check(Value, QWord($fd70a3d70a3d70a4), $3ffe, 1);
  Value := Difference;
  Check(Value, QWord($cccccccccccccccd), $3ffb, 2);
  Check(Stored, QWord($fd70a3d70a3d70a4), $3ffe, 3);
  Value := 1.0000000000000000001;
  Check(Value, QWord($8000000000000001), $3fff, 4);
end.
{$else}
begin
end.
{$endif}
