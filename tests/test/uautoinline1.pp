unit uautoinline1;

{$mode objfpc}

interface

type
  TPoint = record
    X, Y: Single;
  end;

function SquaredDistance(a, b: TPoint): Single;
function SumSquares(a, b: Single): Single;
function StoredSum(a, b, c: Single): Single;

implementation

{ These small leaves are not explicitly declared inline. Their local stores
  and field selections must keep the same semantics after automatic inlining. }
function SquaredDistance(a, b: TPoint): Single;
var
  x, y: Single;
begin
  x := a.X - b.X;
  y := a.Y - b.Y;
  Result := x * x + y * y;
end;

function SumSquares(a, b: Single): Single;
var
  Difference, Sum: Single;
begin
  Difference := a - b;
  Sum := a + b;
  Result := Difference * Difference + Sum * Sum;
end;

function StoredSum(a, b, c: Single): Single;
var
  Intermediate: Single;
begin
  Intermediate := a + b;
  Result := Intermediate + c;
end;

end.
