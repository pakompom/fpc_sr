{ %OPT=-O4 -OoNOFASTMATH }
{ Ordered div/shift nodes in saved inline trees retain their preparation flag
  through PPU serialization, so the consumed captures are not prepared again. }
program tdelphiorderinteger2;
{$mode delphi}{$DELPHIORDER ON}{$DELPHIINTEGER32 ON}{$INLINE ON}
uses udelphiorderinteger1;
var Value: Int64;
begin
  Trace:='';
  Value:=OrderedDivision;
  if (Trace<>'CV') or (Value<>12) then Halt(1);
  Trace:='';
  Value:=OrderedShift;
  if (Trace<>'CV') or (Value<>288) then Halt(2);
  Writeln('ok');
end.
