unit udelphinewsyntax;
{$mode delphi}
{$modeswitch recordcomposition}
{$modeswitch typeinquiry}
{$DELPHIORDER ON}{$DELPHIINTEGER32 ON}{$LEGACYPC24 ON}
{$INLINE ON}
interface
type
  TChild = packed record
    Link: Pointer;
    Value: Byte;
  end;
  TComposed = record
    contains Child: TChild;
  end;
  TAlias = record
    Child: TChild;
    contains alias Child;
  end;
  TVariant = record
    case Boolean of
      False: (contains Child: TChild);
      True: (Other: Byte);
  end;
  TComposedEntries = array[0..1] of TComposed;
  TAliasEntries = array[0..1] of TAlias;
  TVariantEntries = array[0..1] of TVariant;
  PComposedEntries = ^TComposedEntries;
  PAliasEntries = ^TAliasEntries;
  PVariantEntries = ^TVariantEntries;

function RoundedChoice(Choose: Boolean; Value: Double): Double; inline;
function WideChoice(Choose: Boolean; Value: Byte): LongInt; inline;

implementation
function RoundedChoice(Choose: Boolean; Value: Double): Double;
begin
  Result := if Choose then Value + 1 else Value - 1;
end;

function WideChoice(Choose: Boolean; Value: Byte): LongInt;
begin
  Result := if Choose then Value + 1 else Value - 1;
end;
end.
