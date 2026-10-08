{ %OPT=-O2 }
program tvmtwasmsignatures;

{$mode objfpc}
{$inline off}

uses SysUtils;

type
  TDispatch = class
    procedure Empty; virtual;
    procedure EmptyArgs(A: LongInt; B: Int64); virtual;
    procedure AbstractProc(A: LongInt; B: Double); virtual; abstract;
    function AbstractFunc(A: Int64): Double; virtual; abstract;
  end;
  TInherited = class(TDispatch);
  TDispatchClass = class of TDispatch;

procedure TDispatch.Empty;
begin
end;

procedure TDispatch.EmptyArgs(A: LongInt; B: Int64);
begin
end;

procedure Exercise(Obj: TDispatch);
var
  Caught: LongInt;
begin
  { A shared parameterless empty-method stub cannot satisfy either Wasm
    signature. Each VMT entry must retain the original method signature. }
  Obj.Empty;
  Obj.EmptyArgs(7, Int64(1) shl 40);

  Caught := 0;
  try
    Obj.AbstractProc(7, 1.5);
    Halt(1);
  except
    on E: EAbstractError do Inc(Caught);
  end;
  try
    if Obj.AbstractFunc(Int64(1) shl 40) = 0 then Halt(2);
    Halt(3);
  except
    on E: EAbstractError do Inc(Caught);
  end;
  if Caught <> 2 then Halt(4);
end;

var
  C: TDispatchClass;
  Obj: TDispatch;
begin
  { Use an inherited VMT as well as the methods' declaring class. Abstract
    slots must point at their signature-correct per-method stubs. }
  C := TDispatch;
  Obj := C.Create;
  try
    Exercise(Obj);
  finally
    Obj.Free;
  end;
  C := TInherited;
  Obj := C.Create;
  try
    Exercise(Obj);
  finally
    Obj.Free;
  end;
  WriteLn('ok');
end.
