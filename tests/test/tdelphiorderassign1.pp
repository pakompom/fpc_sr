{ %OPT=-O4 -OoNOFASTMATH }

{ Delphi 2007 scalar assignment scheduling:
  ordinary scalar assignments evaluate the RHS first on equal demand,
  but prepare a more demanding destination first. The traces and destination
  values are also verified with Delphi 2007 Update 4 with optimization off. }
program tdelphiorderassign1;
{$mode delphi}{$DELPHIORDER ON}{$INLINE OFF}
type
  PValue = ^LongInt;
  TValues = array[0..1] of LongInt;
  PValues = ^TValues;
  TValueObject = class
    Value: LongInt;
  end;
var
  A,B,Shared: LongInt;
  Current: PValue;
  Events: ShortString;
  Obj: TValueObject;
  ArrayA,ArrayB: TValues;
  CurrentArray: PValues;

function Destination(Tag: LongInt): PValue;
begin
  Events:=Events+'D';
  Shared:=77;
  Result:=Current;
end;

function BusyDestination(X,Y,Z: LongInt): PValue;
begin
  Events:=Events+'D';
  Result:=Current;
end;

function Value(Tag: LongInt): LongInt;
begin
  Events:=Events+'V';
  Current:=@B;
  Result:=42;
end;

function ObjectDestination(Tag: LongInt): TValueObject;
begin
  Events:=Events+'D';
  Result:=Obj;
end;

function ArrayDestination(Tag: LongInt): PValues;
begin
  Events:=Events+'D';
  Result:=CurrentArray;
end;

function Index(Tag: LongInt): LongInt;
begin
  Events:=Events+'I';
  CurrentArray:=@ArrayB;
  Result:=0;
end;

procedure Reset;
begin
  A:=10;
  B:=20;
  Shared:=30;
  Current:=@A;
  Events:='';
end;

begin
  Reset;
  Destination(1)^:=Value(1);
  if (Events<>'VD') or (A<>10) or (B<>42) then Halt(1);

  Reset;
  BusyDestination(1,2,3)^:=Value(1);
  { Preserve the old destination address while the RHS replaces Current. }
  if (Events<>'DV') or (A<>42) or (B<>20) then Halt(2);

  Reset;
  Current^:=Value(1);
  { A plain pointer load competes with an effectful RHS. }
  if (Events<>'V') or (A<>10) or (B<>42) then Halt(3);

  Reset;
  Destination(1)^:=Shared;
  { An ordinary RHS read must happen after the destination's mutation. }
  if (Events<>'D') or (A<>77) or (B<>20) then Halt(4);

  Reset;
  Obj:=TValueObject.Create;
  ObjectDestination(1).Value:=Value(1);
  if (Events<>'VD') or (Obj.Value<>42) then Halt(5);
  Obj.Free;

  Reset;
  Destination(1)^:=123;
  if (Events<>'D') or (A<>123) then Halt(6);

  Reset;
  ArrayA[0]:=10;
  ArrayB[0]:=20;
  CurrentArray:=@ArrayA;
  ArrayDestination(1)^[Index(1)]:=Value(1);
  { The destination needs both calls, so precedes Value. Within that
    destination, equal-demand indexing prepares Index before the base. }
  if (Events<>'IDV') or (ArrayA[0]<>10) or (ArrayB[0]<>42) then Halt(7);
  Writeln('ok');
end.
