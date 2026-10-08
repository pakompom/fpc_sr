{ %CPU=x86_64,i386 }
{ %OPT=-O2 -OoNOFASTMATH }
program tpc24controlword;
{$mode objfpc}
{$inline off}
{$asmmode att}

{$ifdef FPC_HAS_TYPE_EXTENDED}
type
  TBits = packed record
    Mantissa: QWord;
    Exponent: Word;
  end;
const
  Inputs: array[0..7] of TBits = (
    (Mantissa:0; Exponent:0), (Mantissa:1; Exponent:0),
    (Mantissa:$8000008000000001; Exponent:$3fff), { above PC24 midpoint }
    (Mantissa:$8000000000000000; Exponent:$bfff),
    (Mantissa:$8000000000000000; Exponent:$4100), { outside Single range }
    (Mantissa:$8000000000000000; Exponent:$7fff),
    (Mantissa:$c000000000000123; Exponent:$7fff),
    (Mantissa:$8000000000000123; Exponent:$7fff));
  Precisions: array[0..2] of Word = (0,$200,$300);

procedure ResetFP(CW: Word);
begin
  asm
    fnclex
    fldcw CW
  end;
end;

function Status: Word; assembler; nostackframe;
asm
  fnstsw %ax
end;

function Reference(Op: Integer; A,B: Extended): Extended;
var OldCW, PC24CW: Word;
begin
  { An unconditional precision switch is the reference for both fast and
    slow paths. Keep the output's complete binary80 representation. }
  asm
    fnstcw OldCW
    movw OldCW,%ax
    andw $0xfcff,%ax
    movw %ax,PC24CW
    fldcw PC24CW
  end;
  case Op of
    0: asm fldt A; fldt B; faddp %st,%st(1); fstpt Result end;
    1: asm fldt A; fldt B; fsubrp %st,%st(1); fstpt Result end;
    2: asm fldt A; fldt B; fmulp %st,%st(1); fstpt Result end;
    3: asm fldt A; fldt B; fdivrp %st,%st(1); fstpt Result end;
    4: asm fldt A; fld %st; fmulp %st,%st(1); fstpt Result end;
    5: asm fldt A; fsqrt; fstpt Result end;
  end;
  asm
    fwait
    fldcw OldCW
  end;
end;

{$LEGACYPC24 ON}
function Candidate(Op: Integer; A,B: Extended): Extended;
begin
  case Op of
    0: Result:=A+B;
    1: Result:=A-B;
    2: Result:=A*B;
    3: Result:=A/B;
    4: Result:=Sqr(A);
    5: Result:=Sqrt(A);
  end;
end;
{$LEGACYPC24 OFF}

var
  SavedCW, CW, Flags: Word;
  P,R,I,J,Op: Integer;
  A,B,X,Y: Extended;
  XB,YB: TBits;
{$endif}
begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
  SavedCW:=Get8087CW;
  for P:=0 to 2 do
    for R:=0 to 3 do
      for I:=Low(Inputs) to High(Inputs) do
        for J:=Low(Inputs) to High(Inputs) do
          for Op:=0 to 5 do
            begin
              CW:=$7f or Precisions[P] or (R shl 10);
              Move(Inputs[I],A,10);
              Move(Inputs[J],B,10);
              ResetFP(CW);
              X:=Reference(Op,A,B);
              Flags:=Status and $3f;
              ResetFP(CW);
              Y:=Candidate(Op,A,B);
              Move(X,XB,10);
              Move(Y,YB,10);
              if (XB.Mantissa<>YB.Mantissa) or (XB.Exponent<>YB.Exponent) or
                 ((Status and $3f)<>Flags) or (Get8087CW<>CW) then Halt(1);
            end;
  ResetFP(SavedCW);
{$endif}
  WriteLn('ok');
end.
