{ %OPT=-O4 -OoNOFASTMATH }
program tdelphiorderlayout;
{$ifdef FPC}{$mode delphi}{$DELPHIORDER ON}{$endif}
{$INLINE OFF}{$R-}
uses udelphiorderlayout;
var
  OldEntries,NewEntries: TEntries;
  OldPacked,NewPacked: TPackedEntries;
  OldNested,NewNested: TNestedEntries;
  OldVariant,NewVariant: TVariantEntries;
  OldReal,NewReal: TRealEntries;
  OldPointers,NewPointers: TPointerEntries;
  OldMethods,NewMethods: TMethodEntries;
  OldSetHead,NewSetHead: TSetHeadEntries;
  OldSetTail,NewSetTail: TSetTailEntries;
  OldSetThree,NewSetThree: TSetThreeEntries;
  OldSetOffset,NewSetOffset: TSetOffsetEntries;
  OldNativeSigned,NewNativeSigned: TNativeSignedEntries;
  OldNativeUnsigned,NewNativeUnsigned: TNativeUnsignedEntries;
  Current,Next,Selected: Pointer;
  Trace: AnsiString;

function EntryBase: PEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function PackedBase: PPackedEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function NestedBase: PNestedEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function VariantBase: PVariantEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function RealBase: PRealEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function PointerBase: PPointerEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function MethodBase: PMethodEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function SetHeadBase: PSetHeadEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function SetTailBase: PSetTailEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function SetThreeBase: PSetThreeEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function SetOffsetBase: PSetOffsetEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function NativeSignedBase: PNativeSignedEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function NativeUnsignedBase: PNativeUnsignedEntries;
begin Trace:=Trace+'B'; Result:=Current end;
function ChooseIndex: Integer;
begin Trace:=Trace+'I'; Current:=Next; Result:=0 end;

procedure Reset(OldValue,NewValue: Pointer);
begin Current:=OldValue; Next:=NewValue; Trace:='' end;
procedure Check(const Expected: AnsiString; Storage: Pointer; Code: Integer);
begin
  if (Trace<>Expected) or (Selected<>Storage) then Halt(Code);
end;

procedure CheckLocalTypes;
type
  { A user type with the same name is not System.NativeInt. }
  NativeInt = type Integer;
  TShadow = record Value: NativeInt; Link: Pointer end;
  TShadows = array[0..1] of TShadow;
  PShadows = ^TShadows;
  { A distinct type derived from an imported NativeInt alias must retain its
    source layout across both the PPU boundary and another type copy. }
  TLocalNative = type TNativeCopy;
  TLocal = record Value: TLocalNative; Link: Pointer end;
  TLocals = array[0..1] of TLocal;
  PLocals = ^TLocals;
var
  OldShadow,NewShadow: TShadows;
  OldLocal,NewLocal: TLocals;
  function ShadowBase: PShadows;
  begin Trace:=Trace+'B'; Result:=Current end;
  function LocalBase: PLocals;
  begin Trace:=Trace+'B'; Result:=Current end;
begin
  Reset(@OldShadow,@NewShadow);
  Selected:=@ShadowBase()^[ChooseIndex];
  Check('BI',@OldShadow[0],14);
  Reset(@OldLocal,@NewLocal);
  Selected:=@LocalBase()^[ChooseIndex];
  Check('IB',@NewLocal[0],15);
end;

begin
  { Source strides 8,5,8,8,16,8,8. The target ABI is free to use different
    strides. Expected traces verified with Delphi 2007, optimization off. }
  Reset(@OldEntries,@NewEntries);
  Selected:=@EntryBase()^[ChooseIndex];
  Check('BI',@OldEntries[0],1);
  Reset(@OldPacked,@NewPacked);
  Selected:=@PackedBase()^[ChooseIndex];
  Check('IB',@NewPacked[0],2);
  Reset(@OldNested,@NewNested);
  Selected:=@NestedBase()^[ChooseIndex];
  Check('BI',@OldNested[0],3);
  Reset(@OldVariant,@NewVariant);
  Selected:=@VariantBase()^[ChooseIndex];
  Check('BI',@OldVariant[0],4);
  Reset(@OldReal,@NewReal);
  Selected:=@RealBase()^[ChooseIndex];
  Check('IB',@NewReal[0],5);
  Reset(@OldPointers,@NewPointers);
  Selected:=@PointerBase()^[ChooseIndex];
  Check('BI',@OldPointers[0],6);
  Reset(@OldMethods,@NewMethods);
  Selected:=@MethodBase()^[ChooseIndex];
  Check('BI',@OldMethods[0],7);
  { Sets are byte-aligned; a three-byte range uses four bytes. Target set
    packing must not affect scheduling. NativeInt/NativeUInt are eight bytes
    in Delphi 2007 even on Win32. Source strides here are 5,5,5,4,16,16. }
  Reset(@OldSetHead,@NewSetHead);
  Selected:=@SetHeadBase()^[ChooseIndex];
  Check('IB',@NewSetHead[0],8);
  Reset(@OldSetTail,@NewSetTail);
  Selected:=@SetTailBase()^[ChooseIndex];
  Check('IB',@NewSetTail[0],9);
  Reset(@OldSetThree,@NewSetThree);
  Selected:=@SetThreeBase()^[ChooseIndex];
  Check('IB',@NewSetThree[0],10);
  Reset(@OldSetOffset,@NewSetOffset);
  Selected:=@SetOffsetBase()^[ChooseIndex];
  Check('BI',@OldSetOffset[0],11);
  Reset(@OldNativeSigned,@NewNativeSigned);
  Selected:=@NativeSignedBase()^[ChooseIndex];
  Check('IB',@NewNativeSigned[0],12);
  Reset(@OldNativeUnsigned,@NewNativeUnsigned);
  Selected:=@NativeUnsignedBase()^[ChooseIndex];
  Check('IB',@NewNativeUnsigned[0],13);
  CheckLocalTypes;
end.
