program tcaseutf8fpwidestring;

{$mode objfpc}{$H+}{$codepage utf8}

uses
  unicodeducet, fpwidestring, SysUtils;

procedure Check(const Source, Lower, Upper: UTF8String);
var
  Value: AnsiString;
begin
  Value:=AnsiLowerCase(AnsiString(Source));
  if (Length(Value)<>Length(Lower)) or (Value<>Lower) then
    Halt(1);
  Value:=AnsiUpperCase(AnsiString(Source));
  if (Length(Value)<>Length(Upper)) or (Value<>Upper) then
    Halt(2);
end;

var
  Buffer: array[0..7] of AnsiChar;
begin
  SetMultiByteConversionCodePage(CP_UTF8);
  Check('','','');
  Check('English','english','ENGLISH');
  Check('ÄäАа','ääаа','ÄÄАА');
  Check('K','k','K');
  { An embedded zero belongs to the input; only the conversion terminator is excluded. }
  Check(#0,#0,#0);
  Check('A'#0'b','a'#0'b','A'#0'B');
  StrPCopy(Buffer,'English');
  if (AnsiStrLower(Buffer)<>@Buffer[0]) or (StrComp(Buffer,'english')<>0) then
    Halt(3);
  if (AnsiStrUpper(Buffer)<>@Buffer[0]) or (StrComp(Buffer,'ENGLISH')<>0) then
    Halt(4);
end.
