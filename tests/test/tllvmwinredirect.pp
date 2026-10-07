{ %TARGET=win64 }
{ %OPT=-O2 }
program tllvmwinredirect;

{$mode objfpc}

function ProcessId: LongWord; stdcall; forward;
function ProcessId: LongWord; stdcall;
  external 'kernel32.dll' name 'GetCurrentProcessId';

begin
  { A forward declaration followed by a DLL import needs a synthetic body
    whose Pascal identifier must not contain the decorated import name. }
  if ProcessId = 0 then Halt(1);
  WriteLn('ok');
end.
