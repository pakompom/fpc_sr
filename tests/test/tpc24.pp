{ %CPU=aarch64,x86_64 }
{ %OPT=-O4 -OoNOFASTMATH }
{$ifdef CPULLVM}
program tpc24;
{$ifdef PC24_TEST_DELPHI}
{$mode delphi}{$EXCESSPRECISION ON}
{$else}
{$mode objfpc}
{$endif}
{$inline on}
uses upc24inline;
type TBits=record case Boolean of False:(d:Double); True:(u:QWord); end;
function FromBits(u: QWord): Double;
var b: TBits;
begin b.u:=u; Result:=b.d; end;
procedure Check(ok: Boolean; n: LongInt);
begin if not ok then begin WriteLn('failure ',n); Halt(n); end; end;
var a,b,d: Double; s: Single; i,calls: LongInt;
{$LEGACYPC24 ON}
function RuntimeDivide(i: LongInt): Double;
begin Result:=i/50; end;
function RuntimeCoefficient(a: Double): Double;
begin Result:=a*0.99; end;
function RuntimeSqrt(a: Double): Double;
begin Result:=Sqrt(a); end;
function RuntimeFrac(a: Double): Double;
begin Result:=Frac(a); end;
function TailComparison(a: Double): Boolean;
begin
  Result:=(a<1.0000000000000000001) and (a<=1.0000000000000000001)
    and (1.0000000000000000001>a) and (a<>1.0000000000000000001)
    and not(a=1.0000000000000000001) and (a>0.99999999999999999);
end;
function SideEffect: Double;
begin Inc(calls); Result:=1; end;
function TailEquality: Boolean;
begin Result:=SideEffect=1.0000000000000000001; end;
function PiComparison(a: Double): Boolean;
begin Result:=(a<Pi) and (a<>Pi); end;
{$LEGACYPC24 OFF}
begin
  a:=FromBits($3ff0000010000000); { 1 + 2^-24 }
  b:=FromBits($3c90000000000000); { 2^-54 }
  Check(PCAdd(a,b)=FromBits($3ff0000020000000),1);
  Check(NativeAdd(a,b)=a,2);
  s:=16777216;
  Check(PCSingleAdd(s,1)=16777216,3);
  i:=16777217;
  Check(PCIntAdd(-s,i)=1,4);
  {$push}{$LEGACYPC24 ON}
  d:=1/50;
  Check(d=Double(0.02),5);
  Check(RuntimeDivide(1)=Double(Single(0.02)),6);
  Check(RuntimeDivide(1)<>d,7);
  {$pop}
  a:=FromBits($3ff0000020000011); { square above the Single-root midpoint }
  Check(RuntimeSqrt(a)=FromBits($3ff0000020000000),8);
  Check(RuntimeCoefficient(1)=Double(Single(0.99)),9);
  Check(TailComparison(FromBits($3ff0000000000000)),10);
  Check(not TailEquality,11);
  Check(calls=1,12);
  Check(RuntimeFrac(FromBits($3ff199999999999a))=Double(Single(0.1)),13);
  Check(PiComparison(FromBits($400921fb54442d18)),14);
  {$push}{$LEGACYPC24 ON}
  Check(Trunc(1.99999999999999999)=1,15);
  Check(Round(2.5000000000000000002)=3,16);
  Check(Frac(1.99999999999999999)<1.0,17);
  Check(Abs(-1.0000000000000000001)>1.0,18);
  {$pop}
  WriteLn('ok');
end.
{$else}
program tpc24;
begin
  WriteLn('ok');
end.
{$endif}
