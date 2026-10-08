{ %OPT=-O4 -OoNOFASTMATH }

{ Integer schedules checked against Delphi 2007 Update 4 with $O-.
  The upgrade case checks call order and resulting attributes when
  the integer and floating helpers share random state. }
program tdelphiorderinteger1;
{$mode delphi}{$Q-}{$R-}{$B-}
{$DELPHIORDER ON}{$DELPHIINTEGER32 ON}
{$ifdef TEST_PC24}{$LEGACYPC24 ON}{$endif}
{$ifdef TEST_INLINE}{$INLINE ON}{$else}{$INLINE OFF}{$endif}

var
  Trace: AnsiString;
  State: Integer;
  Seed: Cardinal;
  Chaotic: Boolean;

procedure Check(const Name, ExpectedTrace: AnsiString; Value, Expected: Int64);
begin
  if (Trace<>ExpectedTrace) or (Value<>Expected) then
    begin
      Writeln(Name,': trace=',Trace,' value=',Value,
        ' expected=',ExpectedTrace,'/',Expected);
      Halt(1);
    end;
  Trace:='';
end;

function A: Integer;
begin
  Trace:=Trace+'A';
  Result:=36;
end;

function B: Integer;
begin
  Trace:=Trace+'B';
  Result:=3;
end;

function BiggerB(x,y,z: Integer): Integer;
begin
  Trace:=Trace+'B';
  Result:=x+y+z;
end;

function A64: Int64;
begin
  Trace:=Trace+'A';
  Result:=36;
end;

function B64: Int64;
begin
  Trace:=Trace+'B';
  Result:=3;
end;

function BiggerB64(x,y,z: Integer): Int64;
begin
  Trace:=Trace+'B';
  Result:=x+y+z;
end;

function ChangeState: Integer;
begin
  Trace:=Trace+'C';
  State:=100;
  Result:=3;
end;

function Guard: Boolean;
begin
  Trace:=Trace+'G';
  Result:=True;
end;

function Product64: Int64; inline;
begin
  Result:=A64*B64;
end;

function Next(Bound: Cardinal): Cardinal;
begin
  Seed:=Seed*134775813+1;
  Result:=(UInt64(Seed)*Bound) shr 32;
end;

function SeededInteger(Low,High: Integer; ItemSeed: Cardinal): Integer;
begin
  Trace:=Trace+'I';
  if Chaotic then Result:=Next(High-Low+1)+Low
  else Result:=ItemSeed mod Cardinal(High-Low+1)+Low;
end;

function SeededFloat(ItemSeed: Cardinal; Low,High: Double): Double;
var L,H: Integer;
begin
  Trace:=Trace+'F';
  L:=Trunc(Low*1000+1);
  H:=Trunc(High*1000+1);
  if Chaotic then Result:=(Next(H-L+1)+L)/1000
  else Result:=(ItemSeed mod Cardinal(H-L+1)+L)/1000;
end;

procedure CheckUpgrade;
var Id: Cardinal; ScanPower: ShortInt;
begin
  Id:=123;
  ScanPower:=20;
  Seed:=1;
  Trace:='';
  ScanPower:=ScanPower+Round(ScanPower*SeededFloat(Id*254571,0.05,0.1))
    +SeededInteger(1,3,Id*354571);
  if Chaotic then
    begin
      Check('chaotic upgrade','IF',ScanPower,23);
      if Seed<>3698175007 then Halt(2);
    end
  else
    begin
      Check('seeded upgrade','IF',ScanPower,22);
      if Seed<>1 then Halt(3);
    end;
end;

var I: Integer; L: Int64; Flag: Boolean;
begin
  Trace:='';
  I:=A+B;
  Check('add tie','AB',I,39);
  I:=A-B;
  Check('subtract tie','AB',I,33);
  I:=A*B;
  Check('multiply tie','AB',I,108);
  I:=A+BiggerB(1,1,1);
  Check('add demand','BA',I,39);
  I:=A-BiggerB(1,1,1);
  Check('subtract demand','BA',I,33);
  I:=A*BiggerB(1,1,1);
  Check('multiply demand','BA',I,108);
  I:=A div B;
  Check('divide tie','AB',I,12);
  I:=A mod B;
  Check('modulo tie','AB',I,0);
  I:=A div BiggerB(1,1,1);
  Check('divide demand','BA',I,12);
  I:=A mod BiggerB(1,1,1);
  Check('modulo demand','BA',I,0);
  I:=A and B;
  Check('bitwise and','AB',I,0);
  I:=A or B;
  Check('bitwise or','AB',I,39);
  I:=A xor B;
  Check('bitwise xor','AB',I,39);
  Flag:=A>B;
  Check('compare tie','AB',Ord(Flag),1);
  Flag:=A>BiggerB(1,1,1);
  Check('compare demand','BA',Ord(Flag),1);

  State:=10;
  I:=State+ChangeState;
  Check('load after mutation','C',I,103);
  State:=10;
  I:=State-ChangeState;
  Check('subtract load after mutation','C',I,97);
  State:=10;
  L:=Int64(State)-Int64(ChangeState);
  Check('int64 subtract captures load','C',L,7);

  L:=A64+B64;
  Check('int64 add','AB',L,39);
  L:=A64+BiggerB64(1,1,1);
  Check('int64 add demand','BA',L,39);
  L:=A64-BiggerB64(1,1,1);
  Check('int64 subtract fixed','AB',L,33);
  L:=A64*B64;
  Check('int64 multiply fixed','BA',L,108);
  L:=A64 div B64;
  Check('int64 divide fixed','BA',L,12);
  L:=A64 mod B64;
  Check('int64 modulo fixed','BA',L,0);
  Flag:=A64>BiggerB64(1,1,1);
  Check('int64 compare','BA',Ord(Flag),1);
  L:=Product64;
  Check('inline int64 multiply','BA',L,108);

  I:=A shl B;
  Check('shift call clobbers ecx','AB',I,288);
  I:=A shr B;
  Check('right shift call clobbers ecx','AB',I,4);
  L:=A64 shl B;
  Check('int64 shift count needs eax','BA',L,288);
  L:=A64 shr B;
  Check('int64 right shift count needs eax','BA',L,4);

  I:=A*2;
  Check('single evaluation multiply','A',I,72);
  I:=2*A;
  Check('single evaluation left constant','A',I,72);
  I:=A div 4;
  Check('single evaluation divide','A',I,9);
  I:=A mod 4;
  Check('single evaluation modulo','A',I,0);
  L:=A64*2;
  Check('single evaluation int64 constant','A',L,72);
  L:=A64 div 4;
  Check('single evaluation int64 divide','A',L,9);

  Flag:=False and Guard;
  Check('short circuit and','',Ord(Flag),0);
  Flag:=True or Guard;
  Check('short circuit or','',Ord(Flag),1);
  Chaotic:=False;
  CheckUpgrade;
  Chaotic:=True;
  CheckUpgrade;
  Writeln('ok');
end.
