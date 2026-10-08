{ %OPT=-O2 -OoNOFASTMATH }
program tllvmwasmeh;
{$mode objfpc}{$H+}
{$inline off}

{ Exercise native Wasm exception edges as well as Pascal object lifetime.
  Deliberately depends only on System so it also checks a standalone WASI RTL. }
type
  EBase = class(TObject)
    Code: LongInt;
    constructor Create(ACode: LongInt);
    destructor Destroy; override;
  end;
  EChild = class(EBase);
  EOther = class(EBase);

var
  Destroyed, Trace, I, Cleanups: LongInt;
  Saved: TObject;

constructor EBase.Create(ACode: LongInt);
begin
  inherited Create;
  Code := ACode;
end;

destructor EBase.Destroy;
begin
  Inc(Destroyed);
  inherited Destroy;
end;

procedure Check(Condition: Boolean; Number: LongInt);
begin
  if not Condition then
  begin
    WriteLn('llvm-wasm-eh: failed ', Number);
    Halt(Number);
  end;
end;

procedure RaiseChild(Code: LongInt);
begin
  raise EChild.Create(Code);
end;

function ExitThroughFinally: LongInt;
begin
  try
    Result := 42;
    Exit;
  finally
    Inc(Cleanups);
  end;
end;

procedure ManagedUnwind;
var
  S: AnsiString;
begin
  S := 'managed';
  S := S + '-local';
  Check(Length(S) = 13, 20);
  RaiseChild(7);
end;

begin
  Destroyed := 0;
  Trace := 0;
  Cleanups := 0;
  try
    RaiseChild(1);
  except
    on E: EOther do Check(False, 1);
    on E: EChild do Check(E.Code = 1, 2);
  end;
  Check(Destroyed = 1, 3);

  try
    try
      RaiseChild(2);
    finally
      Trace := Trace * 10 + 1;
    end;
  except
    on E: EBase do
    begin
      Check(E.Code = 2, 4);
      Trace := Trace * 10 + 2;
    end;
  end;
  Check((Destroyed = 2) and (Trace = 12), 5);

  try
    try
      RaiseChild(3);
    except
      on E: EChild do
      begin
        Saved := E;
        raise;
      end;
    end;
  except
    on E: EBase do Check((E = Saved) and (E.Code = 3), 6);
  end;
  Check(Destroyed = 3, 7);

  Check(ExitThroughFinally = 42, 8);
  for I := 1 to 4 do
    try
      if I = 1 then Continue;
      if I = 3 then Break;
    finally
      Inc(Cleanups);
    end;
  Check(Cleanups = 4, 9);

  try
    try
      { This try completes normally. Check a new exception from finally;
        replacing an already-pending exception has separate object-lifetime
        behavior in the existing RTL and is not asserted by this test. }
      Trace := 4;
    finally
      raise EOther.Create(5);
    end;
  except
    on E: EOther do Check(E.Code = 5, 10);
  end;
  Check((Destroyed = 4) and (Trace = 4), 11);

  try
    try
      RaiseChild(6);
    except
      { Replacement inside an except handler must destroy the old object. }
      on E: EChild do raise EOther.Create(7);
    end;
  except
    on E: EOther do Check(E.Code = 7, 12);
  end;
  Check(Destroyed = 6, 13);

  try
    ManagedUnwind;
  except
    on E: EBase do Check(E.Code = 7, 14);
  end;
  Check(Destroyed = 7, 15);

  try
    RaiseChild(8);
  except
    Trace := 99;
  end;
  Check((Trace = 99) and (Destroyed = 8), 16);
  WriteLn('llvm-wasm-eh: ok (8 exceptions, 4 nonlocal cleanups)');
end.
