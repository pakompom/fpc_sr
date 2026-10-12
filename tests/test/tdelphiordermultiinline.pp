{ %OPT=-O2 }
program tdelphiordermultiinline;
{$mode delphi}{$DELPHIORDER ON}{$inline off}

var
  Value, Calls: LongInt;

function Destination: PLongInt;
begin
  Inc(Calls);
  Result := @Value;
end;

function Source: LongInt;
begin
  Inc(Calls);
  Result := -120;
end;

begin
  { The arithmetic-shift intrinsic has a call-parameter list, which has no
    result type. Assignment scheduling must inspect its arguments safely. }
  Destination^ := SarLongint(Source, 2);
  if (Value <> -30) or (Calls <> 2) then Halt(1);
  WriteLn('ok');
end.
