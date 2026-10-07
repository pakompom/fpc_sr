{ %OPT=-O2 -OoNOFASTMATH }
program tllvmehbarrier;

{$mode objfpc}
{$inline off}

uses SysUtils;

var
  InnerCount, OuterCount, CaughtCount: LongInt;
  Value: LongInt;
  Missing: PLongInt;
  Shared: AnsiString;

function ProtectedLoad(P: PLongInt): LongInt;
begin
  { There are no calls in this protected region. Its first instruction may
    fault, and the exception handler must remain reachable. }
  try
    Result := P^;
  except
    on E: EAccessViolation do
      Result := -1;
  end;
end;

procedure NestedCleanup(P: PLongInt);
var
  AliasValue: AnsiString;
begin
  AliasValue := Shared;
  try
    try
      Value := P^;
      if Length(AliasValue) <> 12 then
        Halt(7);
    finally
      Inc(InnerCount);
    end;
  finally
    Inc(OuterCount);
  end;
end;

procedure ExplicitRaise;
begin
  try
    raise Exception.Create('expected');
  finally
    Inc(OuterCount);
  end;
end;

var
  I: LongInt;
begin
  Value := 37;
  SetLength(Shared, 12);
  for I := 1 to 20 do
    begin
      if ProtectedLoad(@Value) <> 37 then
        Halt(1);
      if ProtectedLoad(Missing) <> -1 then
        Halt(2);
      try
        NestedCleanup(Missing);
        Halt(3);
      except
        on E: EAccessViolation do
          Inc(CaughtCount);
      end;
      if StringRefCount(Shared) <> 1 then
        Halt(4);
      try
        ExplicitRaise;
        Halt(5);
      except
        on E: Exception do
          Inc(CaughtCount);
      end;
    end;
  if (InnerCount <> 20) or (OuterCount <> 40) or (CaughtCount <> 40) then
    Halt(6);
  WriteLn('ok');
end.
