unit udelphiorderinteger1;
{$mode delphi}{$DELPHIORDER ON}{$DELPHIINTEGER32 ON}{$INLINE ON}
interface
var Trace: AnsiString;
function Value: Int64;
function Count: Integer;
function OrderedDivision: Int64; inline;
function OrderedShift: Int64; inline;
implementation
function Value: Int64;
begin
  Trace:=Trace+'V';
  Result:=36;
end;
function Count: Integer;
begin
  Trace:=Trace+'C';
  Result:=3;
end;
function OrderedDivision: Int64;
begin
  Result:=Value div Int64(Count);
end;
function OrderedShift: Int64;
begin
  Result:=Value shl Count;
end;
end.
