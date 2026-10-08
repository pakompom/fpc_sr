unit udelphiorderlayout;
{ Deliberately compiled without DELPHIORDER. Importers still need the source
  layout, including packing and variant branches, from this unit's PPU. }
{$ifdef FPC}{$mode delphi}{$endif}
{$A8}
interface
type
  TEntry = record Value: Integer; Link: Pointer end;
  TPacked = packed record Value: Byte; Link: Pointer end;
  TNested = record Entry: TEntry end;
  TVariant = record
    Value: Integer;
    case Boolean of
      False: (Link: Pointer);
      True: (Bytes: array[0..3] of Byte);
  end;
  TReal = record Value: Extended end;
  TPointers = array[0..1] of Pointer;
  TMethod = procedure of object;
  TSetHead = record Value: Byte; Bits: set of 0..31 end;
  TSetTail = record Bits: set of 0..31; Value: Byte end;
  TSetThree = record Value: Byte; Bits: set of 0..16 end;
  {$ifdef FPC}{$PACKSET 4}{$endif}
  TOffsetSet = set of 17..31;
  TOffsetSetCopy = type TOffsetSet;
  {$ifdef FPC}{$PACKSET DEFAULT}{$endif}
  TSetOffset = record Value: Word; Bits: TOffsetSetCopy end;
  TNativeAlias = NativeInt;
  TNativeCopy = type TNativeAlias;
  TNativeSigned = record Value: TNativeCopy; Link: Pointer end;
  TNativeUnsigned = record Value: NativeUInt; Link: Pointer end;
  TEntries = array[0..1] of TEntry;
  TPackedEntries = array[0..1] of TPacked;
  TNestedEntries = array[0..1] of TNested;
  TVariantEntries = array[0..1] of TVariant;
  TRealEntries = array[0..1] of TReal;
  TPointerEntries = array[0..1] of TPointers;
  TMethodEntries = array[0..1] of TMethod;
  TSetHeadEntries = array[0..1] of TSetHead;
  TSetTailEntries = array[0..1] of TSetTail;
  TSetThreeEntries = array[0..1] of TSetThree;
  TSetOffsetEntries = array[0..1] of TSetOffset;
  TNativeSignedEntries = array[0..1] of TNativeSigned;
  TNativeUnsignedEntries = array[0..1] of TNativeUnsigned;
  PEntries = ^TEntries;
  PPackedEntries = ^TPackedEntries;
  PNestedEntries = ^TNestedEntries;
  PVariantEntries = ^TVariantEntries;
  PRealEntries = ^TRealEntries;
  PPointerEntries = ^TPointerEntries;
  PMethodEntries = ^TMethodEntries;
  PSetHeadEntries = ^TSetHeadEntries;
  PSetTailEntries = ^TSetTailEntries;
  PSetThreeEntries = ^TSetThreeEntries;
  PSetOffsetEntries = ^TSetOffsetEntries;
  PNativeSignedEntries = ^TNativeSignedEntries;
  PNativeUnsignedEntries = ^TNativeUnsignedEntries;
implementation
end.
