{ %OPT=-O4 -OoNOFASTMATH }

{ An indexed procvar captures its value; a based-field procvar captures the
  field address. Argument side effects distinguish these two cases. }

program tdelphiorder4;
{$mode delphi}{$DELPHIORDER ON}
{$INLINE OFF}

type
  TCallback = procedure(a, b: Integer);
  TMethod = procedure(a, b, c: Integer) of object;
  THolder = record
    Callback: TCallback;
  end;
  PHolder = ^THolder;
  TReceiver = class
    procedure Run(a, b, c: Integer);
  end;

var
  Trace: AnsiString;
  Callback: TCallback;
  Callbacks: array[0..1] of TCallback;
  Holder: THolder;
  Method: TMethod;
  Receiver: TReceiver;

procedure One(a,b:Integer);
begin
  Trace := Trace+'1';
end;

procedure Two(a,b:Integer);
begin
  Trace := Trace+'2';
end;

function A: Integer;
begin
  Trace := Trace+'A';
  Result := 10;
end;

function B: Integer;
begin
  Trace := Trace+'B';
  Callback := Two;
  Callbacks[0] := Two;
  Holder.Callback := Two;
  Result := 20;
end;

function C: Integer;
begin
  Trace := Trace+'C';
  Result := 30;
end;

function TargetIndex: Integer;
begin
  Trace := Trace+'I';
  Result := 0;
end;

function TargetHolder: PHolder;
begin
  Trace := Trace+'H';
  Result := @Holder;
end;

procedure TReceiver.Run(a,b,c:Integer);
begin
  Trace := Trace+'M';
end;
begin
  Callback := One;
  Trace := '';
  Callback(A,B);
  WriteLn('plain ',Trace);
  Callbacks[0] := One;
  Trace := '';
  Callbacks[TargetIndex](A,B);
  WriteLn('indexed ',Trace);
  Holder.Callback := One;
  Trace := '';
  TargetHolder^.Callback(A,B);
  WriteLn('field ',Trace);
  Receiver := TReceiver.Create;
  Method := Receiver.Run;
  Trace := '';
  Method(A,B,C);
  WriteLn('method ',Trace);
  Receiver.Free;
end.
