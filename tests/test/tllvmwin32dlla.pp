{ %TARGET=win32 }
{ %CPU=i386 }
{ %OPT=-O2 -OoNOFASTMATH }
{ %NORUN }
{ %NEEDEDAFTER }
library tllvmwin32dlla;

{$mode objfpc}{$H+}

threadvar
  Counter: LongInt;

function NextValue: LongInt; stdcall;
var
  S: AnsiString;
begin
  SetLength(S, 1000);
  S[1000] := 'x';
  Inc(Counter);
  Result := Counter;
  if S[1000] <> 'x' then Result := -1;
end;

exports NextValue name 'NextValue';

begin
end.
