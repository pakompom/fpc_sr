{ %TARGET=win32 }
{ %CPU=i386 }
{ %OPT=-O2 -OoNOFASTMATH }
program tllvmwin32eh;

{$mode objfpc}{$H+}{$inline off}

uses SysUtils;

const
  WorkerCount = 4;
  Iterations = 100;
var
  Threads: array[1..WorkerCount] of TThreadID;
  Failures, Caught, Cleaned: LongInt;
  Missing: PLongInt;
  Shared: AnsiString;

procedure ReadMissing(P: PLongInt);
var
  S: AnsiString;
  Value: LongInt;
begin
  S := Shared;
  try
    Value := P^;
    if (Value = 1234) or (Length(S) = 0) then
      AtomicIncrement(Failures);
  finally
    AtomicIncrement(Cleaned);
  end;
end;

function Worker(P: Pointer): PtrInt;
var
  I: LongInt;
begin
  for I := 1 to Iterations do
    begin
      try
        ReadMissing(Missing);
        AtomicIncrement(Failures);
      except
        on E: EAccessViolation do AtomicIncrement(Caught);
        else AtomicIncrement(Failures);
      end;
      try
        try
          raise ERangeError.Create('worker');
        except
          on E: ERangeError do
            begin
              if E.Message <> 'worker' then AtomicIncrement(Failures);
              raise;
            end;
        end;
      except
        on E: ERangeError do AtomicIncrement(Caught);
        else AtomicIncrement(Failures);
      end;
    end;
  Result := 0;
end;

var
  I: LongInt;
begin
  SetLength(Shared, 31);
  for I := 1 to WorkerCount do
    begin
      Threads[I] := BeginThread(@Worker, nil);
      if Threads[I] = 0 then Halt(1);
    end;
  for I := 1 to WorkerCount do
    begin
      if WaitForThreadTerminate(Threads[I], 0) <> 0 then Halt(2);
      CloseThread(Threads[I]);
    end;
  if (Failures <> 0) or (Caught <> WorkerCount * Iterations * 2) or
     (Cleaned <> WorkerCount * Iterations) or (StringRefCount(Shared) <> 1) then
    begin
      WriteLn(Failures, ' ', Caught, ' ', Cleaned, ' ', StringRefCount(Shared));
      Halt(3);
    end;
  WriteLn('ok');
end.
