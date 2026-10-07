{ %OPT=-O4 -OoNOFASTMATH }
{ %RECOMPILE }

{ Preserve source calling conventions across a unit interface even when the
  target uses the same ABI for register and pascal declarations. }

program tdelphiorder3;
{$mode delphi}{$DELPHIORDER OFF}

uses udelphiorder3;

var Trace: AnsiString;
  P: TPascalCallback;
  R: TRegisterCallback;

function A: Integer;
begin
  Trace := Trace+'A';
  Result := 1;
end;

function B: Integer;
begin
  Trace := Trace+'B';
  Result := 2;
end;

function C: Integer;
begin
  Trace := Trace+'C';
  Result := 3;
end;

function D: Integer;
begin
  Trace := Trace+'D';
  Result := 4;
end;

function FloatA: Double;
begin
  Trace := Trace+'A';
  Result := 1;
end;
{$DELPHIORDER ON}
{$ifdef TEST_PC24}{$LEGACYPC24 ON}{$endif}
begin
  Trace := '';
  SavedPascal(A,B,C,D);
  if (Trace<>'ABCD') or (Seen<>10) then Halt(1);
  Trace := '';
  SavedRegister(FloatA,B,C);
  if (Trace<>'ACB') or (Seen<>6) then Halt(2);
  P := SavedPascal;
  Trace := '';
  P(A,B,C,D);
  if (Trace<>'ABCD') or (Seen<>10) then Halt(3);
  R := SavedRegister;
  Trace := '';
  R(FloatA,B,C);
  if (Trace<>'ACB') or (Seen<>6) then Halt(4);
  WriteLn('ok');
end.
