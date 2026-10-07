{ %OPT=-O2 }
program tllvmstringfinalize;

{$mode objfpc}
{$inline off}

uses SysUtils;

type
  PAnsiValue = ^AnsiString;
  PUnicodeValue = ^UnicodeString;

var
  AnsiValue: AnsiString;
  UnicodeValue: UnicodeString;
  AnsiSlot: AnsiString;
  UnicodeSlot: UnicodeString;
  TargetCount: LongInt;
  FinallyCount: LongInt;

procedure Check(Condition: Boolean);
begin
  if not Condition then
    Halt(1);
end;

function AnsiAlias: AnsiString;
begin
  Result := AnsiValue;
end;

function UnicodeAlias: UnicodeString;
begin
  Result := UnicodeValue;
end;

function AnsiTarget: PAnsiValue;
begin
  Inc(TargetCount);
  Result := @AnsiSlot;
end;

function UnicodeTarget: PUnicodeValue;
begin
  Inc(TargetCount);
  Result := @UnicodeSlot;
end;

procedure Replace(out A: AnsiString; out U: UnicodeString; Fail: Boolean);
begin
  Check((A = '') and (U = ''));
  if Fail then
    raise Exception.Create('out parameters');
  A := AnsiValue;
  U := UnicodeValue;
end;

procedure Exercise(Kind: LongInt);
var
  A, B: AnsiString;
  U, V: UnicodeString;
begin
  try
    if Kind = 0 then
      Exit;
    A := AnsiAlias;
    U := UnicodeAlias;
    if Kind = 1 then
      raise Exception.Create('first pair');
    B := AnsiAlias;
    V := UnicodeAlias;
    Check((A = B) and (U = V));
    if Kind = 2 then
      raise Exception.Create('second pair');
    A := '';
    V := '';
  finally
    Inc(FinallyCount);
  end;
end;

var
  I, Kind, Caught: LongInt;
begin
  SetLength(AnsiValue, 10);
  SetLength(UnicodeValue, 10);
  for I := 1 to 10 do
    begin
      AnsiValue[I] := AnsiChar(Ord('a') + I);
      UnicodeValue[I] := WideChar($100 + I);
    end;
  Caught := 0;
  for I := 1 to 100 do
    for Kind := 0 to 3 do
      begin
        try
          Exercise(Kind);
        except
          on E: Exception do
            begin
              Check(Kind in [1, 2]);
              Inc(Caught);
            end;
        end;
        Check(StringRefCount(AnsiValue) = 1);
        Check(StringRefCount(UnicodeValue) = 1);
        Check((AnsiValue[10] = 'k') and (UnicodeValue[10] = WideChar($10a)));
      end;
  Check((Caught = 200) and (FinallyCount = 400));
  AnsiSlot := AnsiValue;
  UnicodeSlot := UnicodeValue;
  try
    Replace(AnsiTarget^, UnicodeTarget^, True);
    Halt(1);
  except
    on E: Exception do
      Check((AnsiSlot = '') and (UnicodeSlot = ''));
  end;
  Check(TargetCount = 2);
  Check((StringRefCount(AnsiValue) = 1) and (StringRefCount(UnicodeValue) = 1));
  Replace(AnsiTarget^, UnicodeTarget^, False);
  Check(TargetCount = 4);
  Check((AnsiSlot = AnsiValue) and (UnicodeSlot = UnicodeValue));
  Finalize(AnsiTarget^);
  Finalize(UnicodeTarget^);
  Check(TargetCount = 6);
  Check((AnsiSlot = '') and (UnicodeSlot = ''));
  Check((StringRefCount(AnsiValue) = 1) and (StringRefCount(UnicodeValue) = 1));
  Finalize(AnsiTarget^);
  Finalize(UnicodeTarget^);
  Check(TargetCount = 8);
  WriteLn('ok');
end.
