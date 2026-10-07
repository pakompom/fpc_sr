{ %OPT=-O2 }
program tllvmunusedcaptured;

{$mode objfpc}
{$inline off}

uses SysUtils;

var
  Calls: LongInt;

{$push}
{$O-}
procedure DirtyStack;
var
  Pad: array[0..255] of PtrUInt;
begin
  FillChar(Pad, SizeOf(Pad), $55);
  if Pad[255] = 0 then
    Halt(1);
end;
{$pop}

procedure Outer;
var
  A: AnsiString;
  U: UnicodeString;

  procedure NeverCalled;
  begin
    WriteLn(Length(A), Length(U));
  end;

begin
  { Neither captured string is used by a called procedure. In particular,
    deciding which locals to finalize must not make their unused frame live
    after the compiler has decided whether to initialize it. }
  Inc(Calls);
end;

var
  I: LongInt;
begin
  for I := 1 to 100 do
    begin
      DirtyStack;
      Outer;
    end;
  if Calls <> 100 then
    Halt(1);
  WriteLn('ok');
end.
