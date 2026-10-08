{ %target=wasip1,wasip1threads }
{ %OPT=-O2 }
program twasidynlibs;

{$mode objfpc}{$H+}

uses DynLibs;

begin
  if LoadLibrary(RawByteString('optional.wasm'))<>NilHandle then Halt(1);
  if SafeLoadLibrary(UnicodeString('optional.wasm'))<>NilHandle then Halt(2);
  if GetProcedureAddress(NilHandle,'optional')<>nil then Halt(3);
  if GetProcedureAddress(NilHandle,TOrdinalEntry(1))<>nil then Halt(4);
  if UnloadLibrary(NilHandle) then Halt(5);
  if FreeLibrary(NilHandle) then Halt(6);
  if GetLoadErrorStr<>'Dynamic library loading is not supported on WASI.' then Halt(7);
  WriteLn('ok');
end.
