{ %CPU=i386,x86_64 }
program tllvmextendedconst;
{$mode delphi}
{$DELPHIORDER ON}

const
  Values: array[0..2] of Extended = (-1.0, 0.5, 7.0);

{$LEGACYPC24 ON}
function Negate(Value: Single): Single;
begin
  Result:=-Value;
end;
{$LEGACYPC24 OFF}

function Identity(Value: Extended): Extended;
begin
  Result:=Value;
end;

var
  Value: Extended;
begin
  if Negate(7.0)<>-7.0 then
    Halt(1);
  Value:=Identity(-1.0);
  if Double(Value)<>-1.0 then
    Halt(2);
  if Double(Values[0])<>-1.0 then
    Halt(3);
  if Double(Values[1])<>0.5 then
    Halt(4);
  if Double(Values[2])<>7.0 then
    Halt(5);
end.
