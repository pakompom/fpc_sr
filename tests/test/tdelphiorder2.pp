{ %OPT=-O4 -OoNOFASTMATH }
{ Argument preparation for calls, saved inlines, references and open arrays. }

program tdelphiorder2;
{$mode delphi}{$Q-}{$R-}{$DELPHIORDER OFF}

uses Math;

type
  TReceiver = class
    procedure Accept(Weight: Integer; Level: Byte; Owner: Integer);
  end;

  TCounter = record
    Value: Integer;
    procedure Apply(a, b: Integer);
  end;

  TIntHelper = record helper for Integer
    procedure Apply(a, b: Integer);
  end;

  TCallback = function: Integer;
  TBinaryCallback = function(a, b: Integer): Integer;
  TMethodCallback = function(a, b, c: Integer): Integer of object;

  TCallbackObject = class
    function Apply(a, b, c: Integer): Integer;
  end;

var
  Trace: AnsiString;
  Serial, FirstSeen, SecondSeen, Shared, Index: Integer;
  Values: array[0..1] of Integer;
  DynamicValues: array of Integer;
  Callbacks: array[0..0] of TBinaryCallback;

procedure TReceiver.Accept(Weight: Integer; Level: Byte; Owner: Integer);
begin
  FirstSeen := Weight;
  SecondSeen := Level;
end;

procedure TCounter.Apply(a,b: Integer);
begin
  Inc(Value,a+b);
end;

procedure TIntHelper.Apply(a,b: Integer);
begin
  Inc(Self,a+b);
end;

function TCallbackObject.Apply(a,b,c: Integer): Integer;
begin
  Result := a+b+c;
end;

function LevelSource: Integer;
begin
  Result := ParamCount+10;
end;

function FirstArgument(Base: Integer): Integer;
begin
  Trace := Trace+'S';
  Inc(Serial);
  Result := Serial;
end;

function SecondArgument(a,b: Integer): Integer;
begin
  Trace := Trace+'R';
  Inc(Serial);
  Result := Serial;
end;

function A: Integer;
begin
  Trace := Trace+'A';
  Result := 1;
end;

function B: Integer;
begin
  Trace := Trace+'B';
  Result := 2;
end;

function C: Integer;
begin
  Trace := Trace+'C';
  Result := 3;
end;

function D: Integer;
begin
  Trace := Trace+'D';
  Result := 4;
end;

function FloatA: Double;
begin
  Trace := Trace+'A';
  Result := 1;
end;

function FloatB: Double;
begin
  Trace := Trace+'B';
  Result := 2;
end;

function SingleA: Single;
begin
  Trace := Trace+'A';
  Result := 2;
end;

procedure Four(a,b,c,d: Integer);
begin
  Shared := a+b+c+d;
end;

procedure Floats(a,b: Double);
begin
  Shared := Round(a+b);
end;

procedure CdeclFloats(a, b: Double); cdecl;
begin
  Shared := Round(a+b);
end;

procedure PascalInts(a, b, c, d: Integer); pascal;
begin
  Shared := a+b+c+d;
end;

function Change: Integer;
begin
  Trace := Trace+'C';
  Shared := 100;
  Result := 2;
end;

procedure Pair(a,b: Integer);
begin
  FirstSeen := a;
  SecondSeen := b;
end;

procedure Empty(a,b: Integer);
begin
end;

function IndexCall: Integer;
begin
  Trace := Trace+'I';
  Result := Index;
end;

function ChangeIndex: Integer;
begin
  Trace := Trace+'C';
  Index := 1;
  Result := 2;
end;

procedure ByReference(var a: Integer; b: Integer);
begin
  a := b;
end;

procedure CallbackValue(cb: TCallback; n: Integer);
begin
  FirstSeen := cb();
end;

function MutateArray: Integer;
begin
  SetLength(DynamicValues,3);
  DynamicValues[0] := 42;
  Result := 0;
end;

procedure ArrayValue(const a: array of Integer; n: Integer);
begin
  FirstSeen := Length(a);
  SecondSeen := a[0];
end;

function BinaryCallback(a,b: Integer): Integer;
begin
  Result := a+b;
end;

function TargetIndex: Integer;
begin
  Trace := Trace+'T';
  Result := 0;
end;

procedure RealPair(a,b: Double);
begin
  FirstSeen := Round(a+b);
end;

procedure ForwardSink(n: Integer; a: array of Integer; last: Integer);
begin
  FirstSeen := Length(a);
  SecondSeen := a[last];
end;

{$DELPHIORDER ON}
{$ifdef TEST_PC24}{$LEGACYPC24 ON}{$endif}

procedure ForwardArray(dimensions: array of Integer; last: Integer);
begin
  ForwardSink(A,dimensions,last+1);
end;

procedure Check;

var Receiver: TReceiver;
  Limit: Integer;
  Counter: TCounter;
  Callback: TCallback;
  Method: TMethodCallback;
  Obj: TCallbackObject;
begin
  Receiver := TReceiver.Create;
  Limit := LevelSource;
  Trace := '';
  Serial := 0;
  Receiver.Accept(FirstArgument(20),SecondArgument(1,Limit),5);
  if (Trace<>'RS') or (FirstSeen<>2) or (SecondSeen<>1) then Halt(1);
  Trace := '';
  Serial := 0;
  Receiver.Accept(FirstArgument(20),SecondArgument(1,Min(Limit,7)),5);
  if (Trace<>'SR') or (FirstSeen<>1) or (SecondSeen<>2) then Halt(2);
  Trace := '';
  Four(A,B,C,D);
  if (Trace<>'DCBA') or (Shared<>10) then Halt(3);
  Trace := '';
  Floats(FloatA,FloatB);
  if (Trace<>'AB') or (Shared<>3) then Halt(4);
  Trace := '';
  Shared := 10;
  Pair(Shared,Change);
  if (Trace<>'C') or (FirstSeen<>100) or (SecondSeen<>2) then Halt(5);
  Trace := '';
  Index := 0;
  Values[0] := 0;
  Values[1] := 0;
  ByReference(Values[IndexCall],ChangeIndex);
  if (Trace<>'IC') or (Values[0]<>2) or (Values[1]<>0) then Halt(6);
  Trace := '';
  CdeclFloats(FloatA,FloatB);
  if Trace<>'BA' then Halt(7);
  Trace := '';
  PascalInts(A,B,C,D);
  if Trace<>'ABCD' then Halt(8);
  Trace := '';
  Pair(Min(A,B),C);
  if Trace<>'ABC' then Halt(9);
  { Update 4 captures earlier calls, not ordinary arithmetic/conversions. }
  Trace := '';
  Pair(A+1,Min(B,C));
  if Trace<>'BCA' then Halt(10);
  Trace := '';
  Pair(Byte(A),Min(B,C));
  if Trace<>'BCA' then Halt(11);
  Trace := '';
  Empty(A,B);
  if Trace<>'BA' then Halt(12);
  Trace := '';
  Counter.Value := 10;
  Counter.Apply(A,B);
  if (Trace<>'BA') or (Counter.Value<>13) then Halt(13);
  Trace := '';
  Limit := 10;
  Limit.Apply(A,B);
  if (Trace<>'BA') or (Limit<>13) then Halt(14);
  Trace := '';
  Callback := A;
  CallbackValue(Callback,C);
  if (Trace<>'CA') or (FirstSeen<>1) then Halt(15);
  SetLength(DynamicValues,2);
  DynamicValues[0] := 7;
  ArrayValue(DynamicValues,MutateArray);
  if (FirstSeen<>3) or (SecondSeen<>42) then Halt(16);
  ArrayValue([A,B],C);
  if (FirstSeen<>2) or (SecondSeen<>1) then Halt(17);
  Trace := '';
  RealPair(Sqr(SingleA),Min(FloatA,FloatB));
  if (Trace<>'AAB') or (FirstSeen<>5) then Halt(18);
  Trace := '';
  Callbacks[0] := BinaryCallback;
  Shared := Callbacks[TargetIndex](A,B);
  if (Trace<>'TBA') or (Shared<>3) then Halt(19);
  Obj := TCallbackObject.Create;
  Method := Obj.Apply;
  Trace := '';
  Shared := Method(A,B,C);
  if (Trace<>'CBA') or (Shared<>6) then Halt(20);
  Values[0] := 7;
  Values[1] := 8;
  ForwardArray(Values,0);
  if (FirstSeen<>2) or (SecondSeen<>8) then Halt(21);
  Obj.Free;
  Receiver.Free;
end;
begin
  Check;
  WriteLn('ok');
end.
