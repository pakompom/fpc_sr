{ %OPT=-O4 -OoNOFASTMATH }

{ Source scalar conversion and constant-shift demand affect the enclosing
  register argument schedule. The nested method case exercises an implicit
  Byte conversion competing with a one-argument helper call. Expected
  traces match Delphi 2007 Update 4 with optimization disabled, after
  removing only FPC-specific directives. }
program tdelphiorder_calls;
{$mode delphi}{$DELPHIORDER ON}{$INLINE OFF}{$R-}{$Q-}

type
  TCallback = function: Integer;
  TReceiver = class
    procedure Accept(Size: Integer; Level, Owner: Byte);
    procedure Probe;
  end;

var
  Trace: AnsiString;

function A: Integer;
begin
  Trace:=Trace+'A';
  Result:=2;
end;

function B(Value: Integer): Integer;
begin
  Trace:=Trace+'B';
  Result:=Value+3;
end;

function Indirect: Integer;
begin
  Trace:=Trace+'I';
  Result:=5;
end;

procedure Sink(First,Second: Integer);
begin
  Writeln(Trace,' ',First,' ',Second);
end;

procedure ByteSink(First: Integer; Second: Byte);
begin
  Writeln(Trace,' ',First,' ',Second);
end;

procedure TReceiver.Accept(Size: Integer; Level, Owner: Byte);
begin
  Writeln(Trace,' ',Size,' ',Level);
end;

procedure TReceiver.Probe;
  function Level: Integer;
  begin
    Trace:=Trace+'L';
    Result:=4;
  end;
  function Size(Base: Integer): Integer;
  begin
    Trace:=Trace+'S';
    Result:=Base+10;
  end;
begin
  Accept(Size(20),Level,0);
end;

var Receiver: TReceiver; Callback: TCallback;
begin
  Trace:='';
  ByteSink(B(1),A);
  Trace:='';
  Sink(B(1),A);
  Trace:='';
  Sink(A shl 2,B(1));
  Trace:='';
  Sink(A shr 1,B(1));
  Callback:=Indirect;
  Trace:='';
  Sink(Callback(),A);
  Receiver:=TReceiver.Create;
  Trace:='';
  Receiver.Probe;
  Receiver.Free;
end.
