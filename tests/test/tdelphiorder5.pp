{ %OPT=-O4 -OoNOFASTMATH }

{ Ordering captures the function result in a temporary. Rewriting x*2 as
  x+x must not read that consumed temporary twice, including through the
  Single-to-Double conversion. Exercise both operand orders. }
program tdelphiorder5;
{$mode delphi}{$DELPHIORDER ON}{$INLINE OFF}
var Calls: Integer; S: Single; D: Double;
function NextValue: Single;
begin
  Inc(Calls);
  Result:=1.25;
end;
begin
  S:=NextValue*2;
  D:=2*NextValue;
  if (Calls<>2) or (S<>2.5) or (D<>2.5) then Halt(1);
  Writeln('ok');
end.
