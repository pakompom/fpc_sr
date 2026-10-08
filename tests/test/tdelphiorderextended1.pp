{ %OPT=-O4 -OoNOFASTMATH }
{ %RECOMPILE }

{ Delphi 2007 distinguishes an Extended getter from a Double getter when
  both operands have equal demand. Preserve that distinction across a PPU,
  aliases, distinct types and indirect calls, even when both target storage
  formats are Double. It must not change the target ABI or RTTI identity. }
program tdelphiorderextended1;
{$mode delphi}{$DELPHIORDER ON}{$INLINE OFF}
{$ifdef TEST_PC24}{$LEGACYPC24 ON}{$endif}
uses udelphiorderextended1;

var Value: Double;
  E: Extended;
  EP,ER: TExtendedGetter;
  DP,DR: TDoubleGetter;
  L,R: TRealSource;

procedure Check(const Expected: AnsiString; Code: Integer);
begin
  if (Trace<>Expected) or (Value<>4) then Halt(Code);
end;

procedure SetDouble(var D: Double);
begin D:=3; end;

function SelectReal(D: Double): Integer; overload;
begin Result:=1; end;

function SelectReal(S: Single): Integer; overload;
begin Result:=2; end;

begin
  L:=TRealSource.Create;
  R:=TRealSource.Create;
  L.Tag:='L'; L.Value:=2;
  R.Tag:='R'; R.Value:=4;
  Trace:='';
  Value:=L.AsExtended*(1+R.AsExtended*0.25);
  Check('LR',12);
  Trace:='';
  Value:=L.AsDouble*(1+R.AsDouble*0.25);
  Check('RL',13);
  Trace:='';
  Value:=L.AsDistinct*(1+R.AsExtended*0.25);
  Check('LR',14);
  L.Free;
  R.Free;

  { A completed real multiplication includes operand preparation demand.
    A direct no-argument call has less demand and is evaluated afterward. }
  Trace:='';
  Value:=ExtendedLeft*(1+ExtendedRight*0.25);
  Check('RL',1);
  Trace:='';
  Value:=DoubleLeft*(1+DoubleRight*0.25);
  Check('RL',2);
  Trace:='';
  Value:=DistinctLeft*(1+ExtendedRight*0.25);
  Check('RL',3);

  EP:=ExtendedLeft;
  ER:=ExtendedRight;
  DP:=DoubleLeft;
  DR:=DoubleRight;
  Trace:='';
  Value:=EP()*(1+ER()*0.25);
  Check('LR',4);
  Trace:='';
  Value:=DP()*(1+DR()*0.25);
  Check('RL',5);

{$if SizeOf(Extended)=SizeOf(Double)}
  if TypeInfo(Extended)<>TypeInfo(Double) then Halt(6);
  if TypeInfo(TExtendedAlias)<>TypeInfo(Double) then Halt(7);
  if TypeInfo(TExtendedDistinct)=TypeInfo(Double) then Halt(8);
  SetDouble(E);
  if E<>3 then Halt(9);
  if SelectReal(E)<>1 then Halt(10);
  DP:=EP;
  if DP()<>2 then Halt(11);
{$endif}
  Writeln('ok');
end.
