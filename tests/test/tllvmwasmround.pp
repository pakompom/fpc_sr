{ %CPU=wasm32 }
{ %OPT=-O2 -OoNOFASTMATH }
{$ifdef CPULLVM}
program tllvmwasmround;
{$mode objfpc}{$inline off}

function RTLRound(X: Double): Int64; external name 'fpc_round_real';
function RTLTrunc(X: Double): Int64; external name 'fpc_trunc_real';

const
  Inputs: array[0..15] of QWord = (
    $0000000000000000, $8000000000000000,
    $0000000000000001, $8000000000000001,
    $3fe0000000000000, $bfe0000000000000,
    $43dfffffffffffff, $c3dfffffffffffff,
    $43e0000000000000, $c3e0000000000000,
    $7ff0000000000000, $fff0000000000000,
    $7ff8000000000001, $fff8000000000001,
    $7ff0000000000001, $fff0000000000001);
var
  X: Double;
  S: Single;
  Bits: QWord;
  I: LongInt;

procedure Check(X: Double);
begin
  if Round(X)<>RTLRound(X) then Halt(1);
  if Trunc(X)<>RTLTrunc(X) then Halt(2);
end;

begin
  for I:=Low(Inputs) to High(Inputs) do
    begin
      Bits:=Inputs[I];
      Move(Bits,X,SizeOf(X));
      Check(X);
    end;
  for I:=-1000 to 1000 do
    begin
      X:=I+0.5;
      Check(X);
      if Round(X)<>I+(I and 1) then Halt(3);
      S:=I+0.25;
      if (Round(S)<>RTLRound(S)) or (Trunc(S)<>RTLTrunc(S)) then Halt(4);
    end;
  Bits:=$0123456789abcdef;
  for I:=1 to 10000 do
    begin
      Bits:=Bits xor (Bits shl 13);
      Bits:=Bits xor (Bits shr 7);
      Bits:=Bits xor (Bits shl 17);
      Move(Bits,X,SizeOf(X));
      Check(X);
    end;
  Writeln('ok');
end.

{$else}
program tllvmwasmround;
begin
  Writeln('ok');
end.
{$endif}
