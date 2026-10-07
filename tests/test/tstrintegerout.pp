{ %OPT=-O2 }
program tstrintegerout;

{$mode objfpc}

const
  SignedValues: array[0..6] of Int64 =
    (Low(Int64), -2147483648, -1, 0, 1, 2147483647, High(Int64));
  UnsignedValues: array[0..4] of QWord =
    (0, 1, 4294967295, QWord(1) shl 63, High(QWord));
  Widths: array[0..7] of LongInt = (-1, 0, 1, 19, 20, 21, 255, 256);

procedure Check(Condition: Boolean);
begin
  if not Condition then
    Halt(1);
end;

procedure FormatSigned(Value: Int64; Width: LongInt;
  out Raw: RawByteString; out UTF8: UTF8String);
begin
  Str(Value:Width, Raw);
  Str(Value:Width, UTF8);
end;

procedure FormatUnsigned(Value: QWord; Width: LongInt;
  out Raw: RawByteString; out UTF8: UTF8String);
begin
  Str(Value:Width, Raw);
  Str(Value:Width, UTF8);
end;

var
  Expected: ShortString;
  Raw, AliasValue: RawByteString;
  UTF8: UTF8String;
  I, J: LongInt;
begin
  for J := Low(Widths) to High(Widths) do
    begin
      for I := Low(SignedValues) to High(SignedValues) do
        begin
          SetLength(Raw, 30);
          FillChar(Pointer(Raw)^, 30, Ord('x'));
          AliasValue := Raw;
          Str(SignedValues[I]:Widths[J], Expected);
          FormatSigned(SignedValues[I], Widths[J], Raw, UTF8);
          Check((Raw = Expected) and (UTF8 = Expected));
          Check((StringCodePage(Raw) = 0) and (StringCodePage(UTF8) = 65001));
          Check((StringRefCount(Raw) = 1) and (StringRefCount(UTF8) = 1));
          Check((Length(AliasValue) = 30) and (AliasValue[1] = 'x'));
          Check(StringRefCount(AliasValue) = 1);
        end;
      for I := Low(UnsignedValues) to High(UnsignedValues) do
        begin
          Str(UnsignedValues[I]:Widths[J], Expected);
          FormatUnsigned(UnsignedValues[I], Widths[J], Raw, UTF8);
          Check((Raw = Expected) and (UTF8 = Expected));
          Check((StringCodePage(Raw) = 0) and (StringCodePage(UTF8) = 65001));
          Check((StringRefCount(Raw) = 1) and (StringRefCount(UTF8) = 1));
        end;
    end;
  WriteLn('ok');
end.
