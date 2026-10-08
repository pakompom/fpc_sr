{ %CPU=aarch64,arm,x86_64,i386,wasm32 }
{ %OPT=-O4 -OoNOFASTMATH }
program tdelphinewsyntax;
{$mode delphi}
{$modeswitch typeinquiry}
{$DELPHIORDER ON}{$DELPHIINTEGER32 ON}{$LEGACYPC24 ON}
{$INLINE OFF}{$R-}
uses udelphinewsyntax;
var
  Calls: LongInt;
  Trace: AnsiString;
  Current, Next, Selected: Pointer;
  OldComposed, NewComposed: TComposedEntries;
  OldAlias, NewAlias: TAliasEntries;
  OldVariant, NewVariant: TVariantEntries;
  Choose: Boolean;
  D: Double;
  B: Byte;

function ByteValue: Byte;
begin
  Inc(Calls);
  Result := B;
end;

function RealValue: Double;
begin
  Inc(Calls);
  Result := D;
end;

type
  { The type checker may lower these operands into ordering/PC24 blocks,
    but must discard every side effect and retain the source result type. }
  TWide = type of (ByteValue + ByteValue);
  TReal = type of (RealValue + RealValue);

function ComposedBase: PComposedEntries;
begin Trace := Trace + 'B'; Result := Current end;
function AliasBase: PAliasEntries;
begin Trace := Trace + 'B'; Result := Current end;
function VariantBase: PVariantEntries;
begin Trace := Trace + 'B'; Result := Current end;
function ChooseIndex: Integer;
begin Trace := Trace + 'I'; Current := Next; Result := 0 end;

procedure Reset(OldValue, NewValue: Pointer);
begin Current := OldValue; Next := NewValue; Trace := '' end;
procedure Check(OK: Boolean; Code: LongInt);
begin
  if not OK then
    begin
      Writeln('failure ', Code);
      Halt(Code);
    end;
end;

begin
  Check(Calls = 0, 1);
  Check(SizeOf(TWide) = 4, 2);
  Check(SizeOf(TReal) = SizeOf(Double), 3);
  B := 255;
  D := 16777216;
  Choose := True;
  Check((if Choose then ByteValue + 1 else ByteValue - 1) = 256, 4);
  Check(Calls = 1, 5);
  Check((if Choose then RealValue + 1 else RealValue - 1) = D, 6);
  Check(Calls = 2, 7);
  Check((case B of 255: RealValue + 1; else RealValue - 1 end) = D, 8);
  Check(Calls = 3, 9);
  { Short-circuiting must not hoist either branch's ordering captures. }
  Check(not (False and ((if Choose then ByteValue else ByteValue) = 0)), 10);
  Check(Calls = 3, 11);

  { Composition adds aliases, not more storage. In the Delphi32 source
    model every entry is five bytes, even on targets with eight-byte
    pointers. This reproduces the packed-record schedule already covered
    by tdelphiorderlayout, including aliases in a variant and in a PPU. }
  Reset(@OldComposed, @NewComposed);
  Selected := @ComposedBase()^[ChooseIndex];
  Check((Trace = 'IB') and (Selected = @NewComposed[0]), 12);
  Reset(@OldAlias, @NewAlias);
  Selected := @AliasBase()^[ChooseIndex];
  Check((Trace = 'IB') and (Selected = @NewAlias[0]), 13);
  Reset(@OldVariant, @NewVariant);
  Selected := @VariantBase()^[ChooseIndex];
  Check((Trace = 'IB') and (Selected = @NewVariant[0]), 14);
  NewComposed[0].Value := 42;
  Check(NewComposed[0].Child.Value = 42, 15);

  { Inline trees from the helper retain their defining arithmetic modes. }
  {$DELPHIORDER OFF}{$DELPHIINTEGER32 OFF}{$LEGACYPC24 OFF}{$INLINE ON}
  Check(RoundedChoice(Choose, D) = D, 16);
  Check(WideChoice(Choose, B) = 256, 17);
  Writeln('ok');
end.
