{ %CPU=aarch64,arm,x86_64,i386,wasm32 }
{ %OPT=-O4 -OoNOFASTMATH }

program tpc24sqr;
{$ifdef PC24_TEST_DELPHI}
{$mode delphi}{$EXCESSPRECISION ON}
{$else}
{$mode objfpc}
{$endif}
{$LEGACYPC24 ON}

type
  TNumber = class
    Value: Double;
    function GetFloat: Double;
    procedure SetFloat(a: Double);
  end;

function TNumber.GetFloat: Double;
begin
  Result := Value;
end;

procedure TNumber.SetFloat(a: Double);
begin
  Value := a;
end;

procedure SquareElement(Values: array of TNumber);
begin
  { Lowering Sqr must preserve the nested getter and setter call trees. }
  Values[0].SetFloat(Sqr(Values[1].GetFloat));
end;

function Square(a: Double): Double;
begin
  Result := Sqr(a);
end;

var
  Target, Source: TNumber;
begin
  Target := TNumber.Create;
  Source := TNumber.Create;
  Source.Value := 3;
  SquareElement([Target, Source]);
  if Target.Value <> 9 then
    Halt(1);
  if Square(2) <> 4 then
    Halt(2);
  Target.Free;
  Source.Free;
end.
