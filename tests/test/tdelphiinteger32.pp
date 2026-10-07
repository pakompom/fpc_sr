{ %OPT=-O2 }
{ %RECOMPILE }

{ Delphi arithmetic width is independent of the target register size and of
  floating-point/evaluation-order compatibility. Explicit wider operands and
  the existing overflow/range checks must keep their meanings. }
program tdelphiinteger32;

{$mode delphi}
{$DELPHIINTEGER32 ON}
{$Q-}{$R-}
{$ifdef TEST_PC24}
  {$LEGACYPC24 ON}
  {$DELPHIORDER ON}
{$endif}

uses SysUtils, udelphiinteger32;

function Product(a, b: LongInt): Int64;
begin
  Result := a * b;
end;

function WideProduct(a, b: LongInt): Int64;
begin
  Result := Int64(a) * b;
end;

function Sum(a, b: LongInt): Int64;
begin
  Result := a + b;
end;

function Difference(a, b: LongInt): Int64;
begin
  Result := a - b;
end;

function Negative(a: LongInt): Int64;
begin
  Result := -a;
end;

function UnsignedSum(a, b: Cardinal): QWord;
begin
  Result := a + b;
end;

function UnsignedDifference(a, b: Cardinal): QWord;
begin
  Result := a - b;
end;

function UnsignedScale(a: Cardinal): QWord;
begin
  Result := a * 2;
end;

function MixedSum(a: LongInt; b: Cardinal): Int64;
begin
  Result := a + b;
end;

function NegativeUnsigned(a: Cardinal): Int64;
begin
  Result := -a;
end;

function Quotient(a, b: LongInt): Int64;
begin
  Result := a div b;
end;

function Remainder(a, b: LongInt): Int64;
begin
  Result := a mod b;
end;

function UnsignedQuotient(a, b: Cardinal): QWord;
begin
  Result := a div b;
end;

function ScaledProduct(a, b: LongInt): Double;
begin
  Result := a * b * 0.0001;
end;

function NativeSum(a, b: NativeInt): NativeInt;
begin
  Result := a + b;
end;

function SelectWidth(a: LongInt): Integer; overload;
begin
  Result := 32;
end;

function SelectWidth(a: Int64): Integer; overload;
begin
  Result := 64;
end;

function ArithmeticWidth(a, b: LongInt): Integer;
begin
  Result := SelectWidth(a * b);
end;

function SmallWidth(a, b: Byte): Integer;
begin
  Result := SelectWidth(a + b);
end;

function UnaryWidth(a: Byte): Integer;
begin
  Result := SelectWidth(+a);
end;

function ShiftRight(a: LongInt; Count: Integer): Int64;
begin
  Result := a shr Count;
end;

function Bitwise(a, b: LongInt): Int64;
begin
  Result := (a or b) xor (a and b);
end;

{$Q+}
function CheckedProduct(a, b: LongInt): Int64;
begin
  Result := a * b;
end;

function CheckedSum(a, b: LongInt): Int64;
begin
  Result := a + b;
end;

function CheckedNegative(a: LongInt): Int64;
begin
  Result := -a;
end;

function CheckedQuotient(a, b: LongInt): Int64;
begin
  Result := a div b;
end;

{$Q-}{$R+}
function CheckedAssignment(a: LongInt): SmallInt;
begin
  Result := a + 1;
end;

{$R-}{$DELPHIINTEGER32 OFF}
function DefaultProduct(a, b: LongInt): Int64;
begin
  Result := a * b;
end;

procedure CheckImportedWithModeOff;
begin
  if DelphiProduct(65536, 65536) <> 0 then Halt(28);
end;

{$DELPHIINTEGER32 ON}
var
  Value: Int64;
  Raised: Boolean;
  Bytes: array[0..3] of Byte;
  Address: PByte;
begin
  if Product(65536, 65536) <> 0 then Halt(1);
  if WideProduct(65536, 65536) <> Int64(4294967296) then Halt(2);
  if Sum(High(LongInt), 1) <> Low(LongInt) then Halt(3);
  if Difference(Low(LongInt), 1) <> High(LongInt) then Halt(4);
  if Negative(Low(LongInt)) <> Low(LongInt) then Halt(5);
  if UnsignedSum(High(Cardinal), 1) <> 0 then Halt(6);
  if UnsignedDifference(0, 1) <> High(Cardinal) then Halt(7);
  if UnsignedScale(High(Cardinal)) <> QWord(4294967294) then Halt(8);
  if MixedSum(-1, High(Cardinal)) <> Int64(4294967294) then Halt(9);
  if NegativeUnsigned(High(Cardinal)) <> -Int64(4294967295) then Halt(10);
  if Quotient(-17, 3) <> -5 then Halt(11);
  if Remainder(-17, 3) <> -2 then Halt(12);
  if UnsignedQuotient(High(Cardinal), 2) <> 2147483647 then Halt(13);
  if ScaledProduct(65536, 65536) <> 0 then Halt(14);
  if ArithmeticWidth(3, 7) <> 32 then Halt(15);
  if SmallWidth(3, 7) <> 32 then Halt(16);
  if UnaryWidth(3) <> 32 then Halt(17);
  if ShiftRight(-1, 33) <> High(LongInt) then Halt(18);
  if Bitwise(-1, 0) <> -1 then Halt(19);
  if SizeOf(NativeInt) = 8 then
    begin
      if NativeSum(High(LongInt), 1) <> Int64(2147483648) then Halt(20);
      if DefaultProduct(65536, 65536) <> Int64(4294967296) then Halt(21);
    end;
  Address := @Bytes[0];
  Inc(Address, 3);
  if PtrUInt(Address) - PtrUInt(@Bytes[0]) <> 3 then Halt(22);

  Raised := False;
  try
    Value := CheckedProduct(65536, 65536);
  except
    on EIntOverflow do Raised := True;
  end;
  if not Raised then Halt(23);
  Raised := False;
  try
    Value := CheckedSum(High(LongInt), 1);
  except
    on EIntOverflow do Raised := True;
  end;
  if not Raised then Halt(24);
  Raised := False;
  try
    Value := CheckedNegative(Low(LongInt));
  except
    on EIntOverflow do Raised := True;
  end;
  if not Raised then Halt(25);
  Raised := False;
  try
    Value := CheckedQuotient(Low(LongInt), -1);
  except
    on EIntOverflow do Raised := True;
  end;
  if not Raised then Halt(26);
  Raised := False;
  try
    Value := CheckedAssignment(32767);
  except
    on ERangeError do Raised := True;
  end;
  if not Raised then Halt(27);
  { A variable divisor uses IDIV in Delphi even when Q- is active. }
  Raised := False;
  try
    Value := Quotient(Low(LongInt), -1);
  except
    on EDivByZero do Raised := True;
  end;
  if not Raised then Halt(32);
  Raised := False;
  try
    Value := Remainder(Low(LongInt), -1);
  except
    on EDivByZero do Raised := True;
  end;
  if not Raised then Halt(33);
  CheckImportedWithModeOff;
  if DelphiProduct(65536, 65536) <> 0 then Halt(29);
  if SizeOf(NativeInt) = 8 then
    begin
      if udelphiinteger32.DefaultProduct(65536, 65536) <> Int64(4294967296) then Halt(30);
      if RestoredProduct(65536, 65536) <> Int64(4294967296) then Halt(31);
    end;
  Writeln('Passed');
end.
