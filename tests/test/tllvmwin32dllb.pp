{ %TARGET=win32 }
{ %CPU=i386 }
{ %OPT=-O2 -OoNOFASTMATH }
{ %NEEDLIBRARY }
{ %DELFILES=tllvmwin32dlla }
program tllvmwin32dllb;

{$mode objfpc}{$H+}

uses Windows;

type
  TNextValue = function: LongInt; stdcall;
const
  ThreadCount = 4;
  Iterations = 100;
var
  NextValue: TNextValue;
  Failures: LongInt;

function Worker(P: Pointer): PtrInt;
var
  I: LongInt;
begin
  for I := 1 to Iterations do
    if NextValue() <> I then AtomicIncrement(Failures);
  Result := 0;
end;

var
  Module: HMODULE;
  Threads: array[1..ThreadCount] of TThreadID;
  I, Cycle: LongInt;
begin
  { Exercise both loader callbacks and DLL_Entry, including repeated unload
    and reload. A DLL's TLS setup must use its own threadvar list and lock. }
  for Cycle := 1 to 10 do
    begin
      Module := LoadLibrary('tllvmwin32dlla.dll');
      if Module = 0 then Halt(1);
      Pointer(NextValue) := GetProcAddress(Module, 'NextValue');
      if not Assigned(NextValue) then Halt(2);
      if NextValue() <> 1 then Halt(3);
      for I := 1 to ThreadCount do
        begin
          Threads[I] := BeginThread(@Worker, nil);
          if Threads[I] = 0 then Halt(4);
        end;
      for I := 1 to ThreadCount do
        begin
          if WaitForThreadTerminate(Threads[I], 0) <> 0 then Halt(5);
          CloseThread(Threads[I]);
        end;
      if Failures <> 0 then Halt(6);
      if NextValue() <> 2 then Halt(7);
      if not FreeLibrary(Module) then Halt(8);
    end;
  WriteLn('ok');
end.
