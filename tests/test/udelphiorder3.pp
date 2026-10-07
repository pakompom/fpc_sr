unit udelphiorder3;

{$mode delphi}
{$DELPHIORDER OFF}

interface

type
  TPascalCallback = procedure(a, b, c, d: Integer); pascal;
  TRegisterCallback = procedure(a: Double; b, c: Integer); register;

var
  Seen: Integer;

procedure SavedPascal(a, b, c, d: Integer); pascal;
procedure SavedRegister(a: Double; b, c: Integer); register;

implementation

{ The implementation inherits the original source convention from the
  interface even when both target conventions normalize to stdcall. }
procedure SavedPascal(a, b, c, d: Integer);
begin
  Seen := a + b + c + d;
end;

procedure SavedRegister(a: Double; b, c: Integer);
begin
  Seen := Round(a) + b + c;
end;

end.
