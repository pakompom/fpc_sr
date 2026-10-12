{ %OPT=-O4 -OoNOFASTMATH }
{ Scalar Math selectors retain saved-inline argument preparation on Wasm. }
program tdelphiorderminmax;
{$mode delphi}{$DELPHIORDER ON}
{$ifdef TEST_PC24}{$LEGACYPC24 ON}{$endif}

uses Math;

var
  Trace: AnsiString;
  SeenA, SeenB: Integer;
  I, J: Integer;
  L, M: Int64;
  U, V: QWord;
  S, T: Single;
  D, E: Double;
  Bits: QWord;

function DoubleBits(Value: Double): QWord;
begin
  Move(Value,Result,SizeOf(Result));
end;

function Next(Tag: Char; Value: Integer): Integer;
begin
  Trace := Trace+Tag;
  Result := Value;
end;

procedure Pair(A, B: Integer);
begin
  SeenA := A;
  SeenB := B;
end;

{$INLINE ON}
procedure CheckInline;
begin
  Trace := '';
  Pair(Next('A',10),Min(Next('B',3),Next('C',7)));
  if (Trace<>'ABC') or (SeenA<>10) or (SeenB<>3) then Halt(1);
  Trace := '';
  Pair(Next('A',10),Max(Next('B',3),Next('C',7)));
  if (Trace<>'ABC') or (SeenA<>10) or (SeenB<>7) then Halt(2);
end;

{ A caller's inline setting must not change source-order preparation. }
{$INLINE OFF}
procedure CheckNoInline;
begin
  Trace := '';
  Pair(Next('A',10),Min(Next('B',3),Next('C',7)));
  if (Trace<>'ABC') or (SeenA<>10) or (SeenB<>3) then Halt(3);
  Trace := '';
  Pair(Next('A',10),Max(Next('B',3),Next('C',7)));
  if (Trace<>'ABC') or (SeenA<>10) or (SeenB<>7) then Halt(4);
end;

{$INLINE ON}
begin
  CheckInline;
  CheckNoInline;
  { Runtime values exercise every selector family, including signed and
    unsigned values that cannot be narrowed to a 32-bit comparison. }
  I := Low(Integer)+ParamCount;
  J := High(Integer)-ParamCount;
  if (Min(I,J)<>I) or (Max(I,J)<>J) then Halt(5);
  L := Low(Int64)+ParamCount;
  M := High(Int64)-ParamCount;
  if (Min(L,M)<>L) or (Max(L,M)<>M) then Halt(6);
  U := QWord(1) shl 63;
  Inc(U,ParamCount);
  V := High(QWord)-ParamCount;
  if (Min(U,V)<>U) or (Max(U,V)<>V) then Halt(7);
  S := -1.25-ParamCount;
  T := 2.5+ParamCount;
  if (Min(S,T)<>S) or (Max(S,T)<>T) then Halt(8);
  D := -1.25-ParamCount;
  E := 2.5+ParamCount;
  if (Min(D,E)<>D) or (Max(D,E)<>E) then Halt(9);
  { A comparison-based selector returns its second operand for unordered
    values and ties. Inlining must retain NaNs and the sign of a zero. }
  Bits := QWord($8000000000000000)+ParamCount;
  Move(Bits,D,SizeOf(D));
  E := 0;
  if (DoubleBits(Min(E,D))<>Bits) or
     (DoubleBits(Max(E,D))<>Bits) then Halt(10);
  Bits := QWord($7ff8000000000000)+ParamCount;
  Move(Bits,D,SizeOf(D));
  E := 3;
  if (Min(D,E)<>E) or (Max(D,E)<>E) then Halt(11);
  if not IsNan(Min(E,D)) or not IsNan(Max(E,D)) then Halt(12);
  WriteLn('ok');
end.
