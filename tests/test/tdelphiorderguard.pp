{ %OPT=-O4 -OoAUTOINLINE }
program tdelphiorderguard;
{$mode delphi}{$DELPHIORDER ON}{$B-}

var Calls: Integer;

function ResourceVariant: Integer;
begin
  Result:=2;
end;

function Hit: Boolean;
begin
  Inc(Calls);
  Result:=True;
end;

type
  TPlanet=class
    Mask,Radius: Integer;
    function Test: Boolean;
  end;

function TPlanet.Test: Boolean;
begin
  Result:=False;
  { Auto-inlining folds the middle comparison inside its ordering block.
    Keep both the block's prefix and the surrounding short-circuit guards. }
  if (Mask>0) and (ResourceVariant=2) and (Radius=100) and Hit then
    Result:=True;
end;

var P: TPlanet;
begin
  P:=TPlanet.Create;
  P.Mask:=0; P.Radius:=100;
  if P.Test or (Calls<>0) then Halt(1);
  P.Mask:=1;
  if not P.Test or (Calls<>1) then Halt(2);
  P.Radius:=99;
  if P.Test or (Calls<>1) then Halt(3);
  P.Free;
  WriteLn('ok');
end.
