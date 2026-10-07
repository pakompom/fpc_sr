{ %OPT=-O2 }
{ %SKIPTARGET=$nothread }
program tllvmatomicthreads;

{$mode objfpc}

uses
{$ifdef unix}
  cthreads,
{$endif}
  SysUtils;

var
  Counter: LongInt;
  Counter64: Int64;
  SharedAnsi: AnsiString;
  SharedUnicode: UnicodeString;

function Worker(P: Pointer): PtrInt;
var
  I: LongInt;
  A: AnsiString;
  U: UnicodeString;
begin
  for I := 1 to 10000 do
    begin
      AtomicIncrement(Counter);
      AtomicDecrement(Counter64);
      A := SharedAnsi;
      U := SharedUnicode;
      A := '';
      U := '';
    end;
  Result := 0;
end;

var
  Threads: array[0..3] of TThreadID;
  I: LongInt;
begin
  SetLength(SharedAnsi, 32);
  SetLength(SharedUnicode, 32);
  for I := Low(Threads) to High(Threads) do
    begin
      Threads[I] := BeginThread(@Worker, nil);
      if PtrUInt(Threads[I]) = 0 then Halt(1);
    end;
  for I := Low(Threads) to High(Threads) do
    begin
      if WaitForThreadTerminate(Threads[I], 0) <> 0 then Halt(1);
      CloseThread(Threads[I]);
    end;
  if (Counter <> 40000) or (Counter64 <> -40000) or
     (StringRefCount(SharedAnsi) <> 1) or
     (StringRefCount(SharedUnicode) <> 1) then
    Halt(1);
  WriteLn('ok');
end.
