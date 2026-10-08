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
  TEntries = array[0..1] of TEntry;
  TPackedEntries = array[0..1] of TPacked;
  TNestedEntries = array[0..1] of TNested;
  TVariantEntries = array[0..1] of TVariant;
  TRealEntries = array[0..1] of TReal;
  TPointerEntries = array[0..1] of TPointers;
  TMethodEntries = array[0..1] of TMethod;
  PEntries = ^TEntries;
  PPackedEntries = ^TPackedEntries;
  PNestedEntries = ^TNestedEntries;
  PVariantEntries = ^TVariantEntries;
  PRealEntries = ^TRealEntries;
  PPointerEntries = ^TPointerEntries;
  PMethodEntries = ^TMethodEntries;
implementation
end.
