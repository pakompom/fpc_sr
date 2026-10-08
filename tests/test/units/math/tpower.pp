{ %OPT=-OoNOFASTMATH }
{ Define FPC_USE_PC24_MATH for this test only when Math was also compiled with
  that RTL policy. A caller's LEGACYPC24 setting cannot change a compiled unit. }
{$mode objfpc}
uses
  math;

type
  TDoubleBits = record
    case Boolean of
      False: (Value: Double);
      True: (Bits: QWord);
  end;

procedure CheckPower(Base, Exponent: Float; Expected: QWord; Number: Integer);
var
  B: TDoubleBits;
begin
  B.Value:=Power(Base,Exponent);
  if B.Bits<>Expected then
    begin
      WriteLn('Power failure ',Number);
      Halt(Number);
    end;
end;

{$ifdef FPC_USE_PC24_MATH}
{$LEGACYPC24 ON}
function Payout(Base, Exponent: Double; Amount: LongInt): Int64;
begin
  Result:=Round(Power(Base,Exponent)*Amount);
end;
{$LEGACYPC24 OFF}
{$endif}

{$ifdef FPC_USE_PC24_MATH}
var
  NegativeZero: TDoubleBits;
{$endif}
begin
  SetExceptionMask([exInvalidOp,exDenormalized,exZeroDivide,
    exOverflow,exUnderflow,exPrecision]);
  SetRoundMode(rmNearest);
  if power(0,0)<>1 then
    halt(1);
  if intpower(0,0)<>1 then
    halt(2);
  CheckPower(0,-1,$7FF0000000000000,3);
  CheckPower(-2,3,$C020000000000000,4);
  CheckPower(-2,-3,$BFC0000000000000,5);
{$ifdef FPC_USE_PC24_MATH}
  { The multiply and Exp stages both round to PC24. }
  CheckPower(1.0008333921432495,1.1835616827011108,$3FF0040A60000000,6);
  CheckPower(1.0008333921432495,1.8082191944122314,$3FF0062CC0000000,7);
  CheckPower(1.0008333921432495,18.641096115112305,$3FF0401A40000000,8);
  if Payout(1.0008333921432495,1.8082191944122314,1000000)<>1001508 then
    Halt(9);
  { Zero is special only after the integral-exponent branch. }
  CheckPower(0,-0.5,0,10);
  CheckPower(0,0.5,0,11);
  NegativeZero.Bits:=QWord($8000000000000000);
  CheckPower(NegativeZero.Value,-0.5,QWord($8000000000000000),12);
  CheckPower(NegativeZero.Value,0.5,QWord($8000000000000000),13);
  CheckPower(NegativeZero.Value,-1,QWord($FFF0000000000000),14);
  CheckPower(NegativeZero.Value,2,0,15);
  { Tiny fractions must not round to zero in the integral-exponent test. }
  CheckPower(0,1e-60,0,16);
  CheckPower(NegativeZero.Value,-1e-60,QWord($8000000000000000),17);
  { Delphi 2007 limits the integral branch to [-MaxInt, MaxInt]. }
  CheckPower(-1,2147483647,$BFF0000000000000,18);
  if not IsNan(Power(-1,2147483648.0)) then Halt(19);
  CheckPower(NegativeZero.Value,-2147483648.0,QWord($8000000000000000),20);
  CheckPower(0,NaN,0,21);
  CheckPower(NegativeZero.Value,Infinity,QWord($8000000000000000),22);
  if Sign(0)*Power(0,-0.5)<>0 then Halt(23);
  { Rounding the final Power result alone gives the next larger Single. }
  CheckPower(1.0008333921432495,27.024656295776367,$3FF05D4200000000,26);
{$else}
  { The ordinary RTL retains its existing zero/domain and full-precision math. }
  CheckPower(0,-0.5,$7FF0000000000000,24);
  if Abs(Power(2,0.5)-1.4142135623730950488)>1e-14 then Halt(25);
{$endif}
  writeln('ok');
end.
