{ %OPT=-O4 -OoNOFASTMATH }
{ Delphi real conversions remain saved-inline capture barriers even when
  Extended and Double have the same target representation. }
program tdelphiorderfloatcapture;
{$IFDEF FPC}{$mode delphi}{$DELPHIORDER OFF}{$ENDIF}
{$APPTYPE CONSOLE}{$Q-}{$R-}
uses Math;

var
  Trace: AnsiString;
  Seen: Integer;

function SingleSource: Single;
begin Trace:=Trace+'S'; Result:=2; end;

function DoubleSource: Double;
begin Trace:=Trace+'D'; Result:=2; end;

function ExtendedSource: Extended;
begin Trace:=Trace+'E'; Result:=2; end;

function A: Double;
begin Trace:=Trace+'A'; Result:=1; end;

function B: Double;
begin Trace:=Trace+'B'; Result:=2; end;

procedure Doubles(a,b: Double);
begin Seen:=Round(a+b); end;

procedure Extendeds(a,b: Extended);
begin Seen:=Round(a+b); end;

procedure Check(const Expected: AnsiString; Value, Number: Integer);
begin
  if (Trace<>Expected) or (Seen<>Value) then
    begin
      WriteLn('case ',Number,': ',Trace,' value=',Seen);
      Halt(Number);
    end;
  Trace:='';
end;

{$IFDEF FPC}{$DELPHIORDER ON}{$ENDIF}
procedure Run;
begin
  Trace:='';
  Doubles(Sqr(SingleSource),Min(A,B)); Check('ABS',5,1);
  Doubles(Sqr(DoubleSource),Min(A,B)); Check('ABD',5,2);
  Doubles(SingleSource,Min(A,B)); Check('ABS',3,3);
  Doubles(DoubleSource,Min(A,B)); Check('DAB',3,4);
  Doubles(ExtendedSource,Min(A,B)); Check('ABE',3,5);
  Extendeds(Sqr(SingleSource),Min(A,B)); Check('SAB',5,6);
  Extendeds(Sqr(DoubleSource),Min(A,B)); Check('DAB',5,7);
  Extendeds(DoubleSource,Min(A,B)); Check('ABD',3,8);
  Extendeds(ExtendedSource,Min(A,B)); Check('EAB',3,9);
  Doubles(Abs(DoubleSource),Min(A,B)); Check('ABD',3,10);
  Extendeds(Abs(DoubleSource),Min(A,B)); Check('DAB',3,11);
  Doubles(Sqrt(DoubleSource),Min(A,B)); Check('ABD',2,12);
  Extendeds(Sqrt(DoubleSource),Min(A,B)); Check('DAB',2,13);
  Doubles(Frac(DoubleSource),Min(A,B)); Check('ABD',1,14);
  Extendeds(Frac(DoubleSource),Min(A,B)); Check('DAB',1,15);
end;

{$IFDEF FPC}{$LEGACYPC24 ON}{$ENDIF}
procedure RunPC24;
begin
  Doubles(Sqr(SingleSource),Min(A,B)); Check('ABS',5,16);
  Extendeds(Sqr(SingleSource),Min(A,B)); Check('SAB',5,17);
  Doubles(Sqr(DoubleSource),Min(A,B)); Check('ABD',5,18);
  Extendeds(Sqr(DoubleSource),Min(A,B)); Check('DAB',5,19);
end;

begin
  Run;
  RunPC24;
  WriteLn('ok');
end.
