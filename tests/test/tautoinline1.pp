{ %OPT=-O3 -OoAUTOINLINE -OoNOFASTMATH }
{ %RECOMPILE }

program tautoinline1;

{$mode objfpc}{$H+}

uses uautoinline1;

var
  ReadACount, ReadBCount: LongInt;
  a, b: TPoint;

function ReadA: Single; noinline;
begin
  Inc(ReadACount);
  Result := 2;
end;

function ReadB: Single; noinline;
begin
  Inc(ReadBCount);
  Result := 3;
end;

begin
  a.X := 1;
  a.Y := 2;
  b.X := 4;
  b.Y := 6;
  if SquaredDistance(a, b) <> 25 then
    Halt(1);

  { Exposing an imported leaf must evaluate each argument exactly once. }
  ReadACount := 0;
  ReadBCount := 0;
  if SumSquares(ReadA, ReadB) <> 26 then
    Halt(2);
  if (ReadACount <> 1) or (ReadBCount <> 1) then
    Halt(3);

  { The explicit Single local remains a rounding boundary. }
  if StoredSum(16777216, 1, -16777216) <> 0 then
    Halt(4);
  WriteLn('ok');
end.
