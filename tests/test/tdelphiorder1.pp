{ %OPT=-O4 -OoNOFASTMATH }

{ Real-expression scheduling, including mutation of a previously read operand.
  The default run exercises DELPHIORDER without PC24 arithmetic. }

program tdelphiorder1;
{$mode delphi}{$Q-}{$R-}{$DELPHIORDER OFF}

var Trace: AnsiString;
  Seed: Cardinal;
  Target: Double;

function FloatDraw(a,b: Double; var s: Cardinal): Double;
begin
  Trace := Trace+'F';
  s := s*7981+567+s div 7931;
  Result := 0.004;
end;

function UnitDraw(var s: Cardinal): Double;
begin
  Trace := Trace+'U';
  s := s*7981+5671;
  Result := 0.125;
end;

function IntegerDraw(a,b: Integer; var s: Cardinal): Integer;
begin
  if a=-10 then Trace := Trace+'A'
  else Trace := Trace+'B';
  s := s*7981+567+s div 7981;
  Result := s mod Cardinal(b-a+1)+a;
end;

function Heading(a: Double): Double;
begin
  Result := a*(3.1415926/180);
end;

function ChangeTarget(var s: Cardinal): Double;
begin
  Trace := Trace+'C';
  Target := 100;
  Inc(s);
  Result := 2;
end;

function IndexDraw(var s: Cardinal): Integer;
begin
  Trace := Trace+'I';
  Inc(s);
  Result := 0;
end;

function SecondDraw(i: Integer; var s: Cardinal): Double;
begin
  Trace := Trace+'D';
  Inc(s);
  Result := 2;
end;

function CastLeft: Double;
begin
  Trace := Trace+'L';
  Result := 1;
end;

function CastRight: Double;
begin
  Trace := Trace+'R';
  Result := 2;
end;

{$DELPHIORDER ON}
{$ifdef TEST_PC24}{$LEGACYPC24 ON}{$endif}

procedure CheckProductSum;

var Value: Double;
  Count: Integer;
begin
  Trace := '';
  Seed := 2020190946;
  Count := 100;
  Value := Count*FloatDraw(0.0025,0.005,Seed)+UnitDraw(Seed);
  if (Trace<>'FU') or (Seed<>201771908) then Halt(1);
  if (Value<0.524) or (Value>0.526) then Halt(2);
  Trace := '';
  Seed := 2020190946;
  Value := -Count*FloatDraw(0.0025,0.005,Seed)-UnitDraw(Seed);
  if (Trace<>'FU') or (Seed<>201771908) then Halt(3);
  if (Value>(-0.524)) or (Value<(-0.526)) then Halt(4);
end;

procedure CheckNestedCalls;

var Angle: Single;
begin
  Trace := '';
  Seed := 123456789;
  Angle := 1;
  Angle := Angle+Heading(IntegerDraw(-10,10,Seed)+25)*(2*IntegerDraw(0,1,Seed)-1);
  if Trace<>'AB' then Halt(5);
end;

procedure CheckCaptures;

var Value: Double;
begin
  Trace := '';
  Seed := 1;
  Target := 10;
  Value := Target*FloatDraw(0,1,Seed)+ChangeTarget(Seed);
  if (Trace<>'FC') or (Value<2.039) or (Value>2.041) then Halt(6);

{ Calls dominate a plain load: this must read Target AFTER ChangeTarget,
    rather than imposing blanket source-left-to-right evaluation. }
  Trace := '';
  Target := 10;
  Value := Target+ChangeTarget(Seed);
  if (Trace<>'C') or (Value<>102) then Halt(7);
end;

procedure CheckComparisons;

var Value: Boolean;
begin
  Trace := '';
  Seed := 1;
  Target := 10;
  Value := Target*FloatDraw(0,1,Seed)<ChangeTarget(Seed);
  if (Trace<>'FC') or not Value then Halt(8);
  Trace := '';
  Target := 10;
  Value := Target>ChangeTarget(Seed);
  if (Trace<>'C') or not Value then Halt(9);
end;

procedure CheckIndexedPressure;

var Values: array[0..1] of Double;
  Value: Double;
begin
  Trace := '';
  Seed := 1;
  Values[0] := 3;

{ Delphi 2007's direct fixed-array base adds no pressure. The two-ordinal-
    parameter call wins over the one-parameter index call. }
  Value := Values[IndexDraw(Seed)]+SecondDraw(0,Seed);
  if (Trace<>'DI') or (Value<>5) then Halt(10);
end;

procedure CheckOuterScope;

var Outer: Double;

procedure Inner;

var Value,Local: Double;
begin
  Trace := '';
  Local := 1;
  Outer := 2;

{ An outer frame contributes address pressure while a direct local
      floating slot does not. Both computed operands otherwise tie. }
  Value := (Local+CastLeft)+(Outer+CastRight);
  if (Trace<>'RL') or (Value<>6) then Halt(11);
end;
begin
  Inner;
end;

procedure CheckCastTie;

var Value: Double;
begin
  Trace := '';

{ Equal call demands: the computed Extended operand wins the tie even
    through a real cast. The cast's value conversion is still retained. }
  Value := CastLeft+Single(CastRight+1.0);
  if (Trace<>'RL') or (Value<>4) then Halt(12);
end;

begin
  CheckProductSum;
  CheckNestedCalls;
  CheckCaptures;
  CheckComparisons;
  CheckIndexedPressure;
  CheckOuterScope;
  CheckCastTie;
  WriteLn('ok');
end.
