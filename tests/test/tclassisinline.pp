{ %OPT=-O2 }
program tclassisinline;
{$mode objfpc}{$inline on}

type
  TBase = class end;
  TChild = class(TBase) end;
  TGrandchild = class(TChild) end;
  TOther = class end;

var
  Obj: TObject;
  Target: TClass;
  ObjectCalls, ClassCalls: Integer;

function ObjectValue: TObject;
begin
  Inc(ObjectCalls);
  Result := Obj;
end;

function ClassValue: TClass;
begin
  Inc(ClassCalls);
  Result := Target;
end;

procedure Check(Value: Boolean; Code: Integer);
begin
  if not Value then
    Halt(Code);
end;

begin
  Obj := TGrandchild.Create;
  Target := TChild;
  Check(Obj is TObject, 1);
  Check(Obj is TBase, 2);
  Check(Obj is TChild, 3);
  Check(Obj is TGrandchild, 4);
  Check(not (Obj is TOther), 5);
  Check(ObjectValue is ClassValue, 6);
  Check((ObjectCalls = 1) and (ClassCalls = 1), 7);
  Check(Target.InheritsFrom(TBase), 8);
  Target := nil;
  Check(not (Obj is Target), 9);
  Check(not Target.InheritsFrom(TBase), 10);
  Obj.Free;

  Obj := TOther.Create;
  { An explicit cast must not replace the object's actual class identity. }
  Check(not (TChild(Obj) is TChild), 11);
  Obj.Free;
  Obj := nil;
  Check(not (Obj is TObject), 12);
  Check(not (Obj is TChild), 13);
  Writeln('ok');
end.
