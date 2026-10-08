{ %CPU=aarch64,arm,x86_64,i386,wasm32 }
{ %OPT=-O4 -OoNOFASTMATH }
program tpc24excess;
{$mode delphi}{$EXCESSPRECISION ON}{$LEGACYPC24 ON}
function Chain(a,b,c:Single):Single;
begin Result:=(a+b)+c; end;
function Bound(a:Double):Int64;
begin Result:=Trunc(a*1000+1); end;
function CardinalDivide(a:Cardinal):Double;
begin Result:=Frac(a/10011001); end;
begin
  if Chain(16777216,1,-16777216)<>0 then Halt(1);
  if Bound(65536.9999)<>65537000 then Halt(2);
  if Bound(-32768.9987)<>-32768996 then Halt(3);
  WriteLn('ok');
end.
