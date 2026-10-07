{ %TARGET=win64 }
{ %OPT=-O2 }
program tllvmwinwideinit;

{$mode objfpc}{$H+}

uses SysUtils;

type
  TNames = record
    Count: LongInt;
    Names: array[0..1] of WideString;
  end;
var
  GlobalName: WideString = 'Prison';
  Values: TNames = (Count: 2; Names: ('one', 'two'));
begin
  { The BSTR data starts after a length prefix; each destination includes
    the complete offset of its enclosing record and array fields. }
  if (GlobalName <> 'Prison') or (Values.Count <> 2) or
     (Values.Names[0] <> 'one') or (Values.Names[1] <> 'two') then Halt(1);
  GlobalName := GlobalName + ' planet';
  Values.Names[1] := Values.Names[0];
  if (GlobalName <> 'Prison planet') or (Values.Names[1] <> 'one') then Halt(2);
  WriteLn('ok');
end.
