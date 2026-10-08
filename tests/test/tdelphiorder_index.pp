{ %OPT=-O4 -OoNOFASTMATH }

{ Delphi 2007's indexed-address lowering compares source demand: ties evaluate the
  index first. Check both the call trace and the chosen storage, including
  writes and reference arguments. Verified with Delphi 2007 Update 4,
  optimization off:
  dereferencing a returned array pointer adds demand; range checking the
  index adds demand too and can reverse the selected order. }
program tdelphiorder_index;
{$mode delphi}{$DELPHIORDER ON}{$INLINE OFF}{$R-}
type
  TValues = array[0..1] of Integer;
  PValues = ^TValues;
  TWideValues = array[0..100000] of Integer;
  PWideValues = ^TWideValues;
  TTriple = array[0..2] of Integer;
  TTriples = array[0..1] of TTriple;
  PTriples = ^TTriples;
  TDynValues = array of Integer;
var
  OldValues, NewValues: TValues;
  Current: PValues;
  OldTriples, NewTriples: TTriples;
  CurrentTriples: PTriples;
  WideValues: TWideValues;
  OldDyn, NewDyn, CurrentDyn: TDynValues;
  Text: AnsiString;
  Trace: AnsiString;
  Value: Integer;

function ChooseBase: PValues;
begin
  Trace:=Trace+'B';
  Result:=Current;
end;

function ComplexBase(Arg: Integer): PValues;
begin
  Trace:=Trace+'B';
  Result:=Current;
end;

function TripleBase: PTriples;
begin
  Trace:=Trace+'B';
  Result:=CurrentTriples;
end;

function WideBase(Arg: Integer): PWideValues;
begin
  Trace:=Trace+'B';
  Result:=@WideValues;
end;

function ChooseIndex: Integer;
begin
  Trace:=Trace+'I';
  Current:=@NewValues;
  CurrentTriples:=@NewTriples;
  CurrentDyn:=NewDyn;
  Text:='new';
  Result:=0;
end;

function StringIndex: Integer;
begin
  Result:=ChooseIndex+1;
end;

procedure SetValue(var Dest: Integer);
begin
  Dest:=77;
end;

procedure Reset;
begin
  Current:=@OldValues;
  CurrentTriples:=@OldTriples;
  CurrentDyn:=OldDyn;
  Text:='old';
  Trace:='';
end;

begin
  OldValues[0]:=10;
  OldTriples[0][0]:=10;
  NewTriples[0][0]:=20;
  NewValues[0]:=20;
  SetLength(OldDyn,1);
  SetLength(NewDyn,1);
  OldDyn[0]:=30;
  NewDyn[0]:=40;
  Reset;
  Value:=ChooseBase^[ChooseIndex];
  if (Trace<>'BI') or (Value<>10) then Halt(1);
  Reset;
  Value:=Current^[ChooseIndex];
  if (Trace<>'I') or (Value<>20) then Halt(2);
  Reset;
  Value:=ComplexBase(1)^[ChooseIndex];
  if (Trace<>'BI') or (Value<>10) then Halt(3);
  Reset;
  Value:=CurrentDyn[ChooseIndex];
  if (Trace<>'I') or (Value<>40) then Halt(4);
  Reset;
  if Text[StringIndex]<>'n' then Halt(5);
  Reset;
  ChooseBase^[ChooseIndex]:=66;
  if (Trace<>'BI') or (NewValues[0]<>20) or (OldValues[0]<>66) then Halt(6);
  Reset;
  SetValue(ChooseBase^[ChooseIndex]);
  if (Trace<>'BI') or (NewValues[0]<>20) or (OldValues[0]<>77) then Halt(7);
  Reset;
  Value:=TripleBase^[ChooseIndex][0];
  if (Trace<>'IB') or (Value<>20) then Halt(13);
  {$R+}
  Reset;
  Value:=ChooseBase^[ChooseIndex];
  if (Trace<>'IB') or (Value<>20) then Halt(8);
  Reset;
  Value:=ComplexBase(1)^[ChooseIndex];
  if (Trace<>'IB') or (Value<>20) then Halt(9);
  Reset;
  WideValues[0]:=30;
  Value:=WideBase(1)^[ChooseIndex];
  if (Trace<>'BI') or (Value<>30) then Halt(10);
  {$B-}
  Reset;
  if (Current=nil) and (ChooseBase^[ChooseIndex]=0) then Halt(11);
  if Trace<>'' then Halt(12);
  Writeln('ok');
end.
