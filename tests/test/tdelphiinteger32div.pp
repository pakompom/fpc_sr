{ %OPT=-O4 }
program tdelphiinteger32div;
{$mode objfpc}{$DELPHIINTEGER32 ON}{$INLINE OFF}{$Q-}{$R-}

function ConstantDivide(Value, Index: LongInt): LongInt;
begin
  case Index of
    0: Result:=Value div 3;
    1: Result:=Value div -3;
    2: Result:=Value div 7;
    3: Result:=Value div -7;
    4: Result:=Value div 10;
    5: Result:=Value div 65535;
    6: Result:=Value div 127773;
    7: Result:=Value div -127773;
    8: Result:=Value div 2147483647;
    else Result:=Value div -2147483647;
  end;
end;

function VariableDivide(Value, Divisor: LongInt): LongInt;
begin
  Result:=Value div Divisor;
end;

const
  Divisors: array[0..9] of LongInt=(3,-3,7,-7,10,65535,127773,-127773,
    2147483647,-2147483647);
  Values: array[0..17] of LongInt=(Low(LongInt),Low(LongInt)+1,-1622650073,
    -282475249,-127774,-127773,-127772,-7,-1,0,1,7,127772,127773,127774,
    282475249,1622650073,High(LongInt));
var I,J: Integer;
begin
  { A variable divisor uses hardware division; the constant path uses a
    signed reciprocal, including negative multipliers for positive divisors. }
  for I:=Low(Values) to High(Values) do
    for J:=Low(Divisors) to High(Divisors) do
      if ConstantDivide(Values[I],J)<>VariableDivide(Values[I],Divisors[J]) then
        Halt(1);
  WriteLn('ok');
end.
