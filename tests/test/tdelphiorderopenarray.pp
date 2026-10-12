{ %OPT=-O4 -OoNOFASTMATH }
{ Reference output: original Delphi 2007 Update 4, optimization disabled. }
program tdelphiorderopenarray;
{$IFDEF FPC}{$mode delphi}{$DELPHIORDER OFF}{$ENDIF}
{$APPTYPE CONSOLE}{$Q-}{$R-}{$INLINE ON}

uses Math;

type TIntArray = array of Integer;
var Values, KeepAlive: TIntArray;
  Trace: AnsiString;
  SeenLength, SeenFirst, SeenValue: Integer;

procedure Reset;
begin
  KeepAlive := nil;
  Values := nil;
  SetLength(Values,2);
  Values[0] := 7;
  KeepAlive := Values;
  Trace := '';
end;

function Mutate: Integer;
begin
  Trace := Trace+'M';
  SetLength(Values,3);
  Values[0] := 42;
  Result := 0;
end;

function One: Integer;
begin
  Trace := Trace+'O';
  Result := 1;
end;

function GetValues: TIntArray;
begin
  Trace := Trace+'G';
  Result := Values;
end;

procedure Sink(const a: array of Integer; n: Integer);
begin
  SeenLength := Length(a);
  if SeenLength>0 then SeenFirst := a[0] else SeenFirst := -1;
  SeenValue := n;
end;

procedure BeforeSink(n: Integer; const a: array of Integer);
begin
  Sink(a,n);
end;

procedure PascalSink(const a: array of Integer; n: Integer); pascal;
begin
  Sink(a,n);
end;

procedure Pair(a,b: Integer);
begin
  SeenLength := a;
  SeenFirst := b;
  SeenValue := 0;
end;

procedure Report(const Name: AnsiString);
begin
  WriteLn(Name,': ',Trace,' ',SeenLength,' ',SeenFirst,' ',SeenValue);
end;

{$IFDEF FPC}{$DELPHIORDER ON}{$ENDIF}
procedure Forward(const a: array of Integer);
begin
  Sink(a,Mutate);
end;

procedure Check;
begin
  Reset; Sink(Values,Mutate); Report('register');
  Reset; BeforeSink(Mutate,Values); Report('before');
  Reset; PascalSink(Values,Mutate); Report('pascal');
  Reset; Sink(GetValues,Mutate); Report('returned');
  Reset; Forward(Values); Report('forwarded');
  Reset; Values := nil; Sink(Values,Mutate); Report('empty');
  Reset; Pair(High(Values),Mutate); Report('high');
  Reset; Pair(Length(Values),Mutate); Report('length');
  Reset; Pair(High(Values),Min(One,Mutate)); Report('high-inline');
  Reset; Pair(Length(Values),Min(One,Mutate)); Report('length-inline');
end;

begin
  Check;
end.
