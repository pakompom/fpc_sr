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
function ChooseIndex: Integer;
begin Trace:=Trace+'I'; Current:=Next; Result:=0 end;

procedure Reset(OldValue,NewValue: Pointer);
begin Current:=OldValue; Next:=NewValue; Trace:='' end;
procedure Check(const Expected: AnsiString; Storage: Pointer; Code: Integer);
begin
  if (Trace<>Expected) or (Selected<>Storage) then Halt(Code);
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
end.
