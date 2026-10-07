{ %OPT=-O2 }
program tvmtancestry;
{$mode objfpc}{$inline on}

uses uvmtancestry;

type
  TGrandchild = class(TAncestryChild)
    function Value: Integer; override;
  end;
  TDeep1 = class(TGrandchild) end;
  TDeep2 = class(TDeep1) end;
  TDeep3 = class(TDeep2) end;
  generic TBox<T> = class(TAncestryBase)
    Item: T;
  end;
  TIntBox = specialize TBox<Integer>;
  TByteBox = specialize TBox<Byte>;

function TGrandchild.Value: Integer;
begin
  Result := 23;
end;

function Walk(Actual, Target: TClass): Boolean;
begin
  if Target <> nil then
    while Actual <> nil do
      begin
        if Actual = Target then Exit(True);
        Actual := Actual.ClassParent;
      end;
  Result := False;
end;

procedure Check(Value: Boolean; Code: Integer);
begin
  if not Value then Halt(Code);
end;

var
  Classes: array[0..10] of TClass = (nil, TObject, TAncestryBase,
    TAncestryChild, TGrandchild, TDeep1, TDeep2, TDeep3, TAncestryOther,
    TIntBox, TByteBox);
  I, J: Integer;
  Obj: TAncestryBase;
{$ifdef FPC_VMT_ANCESTRY}
  Original, Proxy1, Proxy2: TClass;
  Vmt1, Vmt2: PVmt;
  VmtBytes: SizeInt;
{$endif FPC_VMT_ANCESTRY}
begin
  for I := Low(Classes) to High(Classes) do
    for J := Low(Classes) to High(Classes) do
      Check(Classes[I].InheritsFrom(Classes[J]) = Walk(Classes[I], Classes[J]), 1);
  Obj := TDeep3.Create;
  try
    Check(Obj.Value = 23, 2);
    Check((Obj is TAncestryBase) and (Obj is TAncestryChild) and
      (Obj is TDeep3) and not (TObject(Obj) is TAncestryOther), 3);
    Check((Obj as TGrandchild).Value = 23, 4);
    Check((TIntBox.ClassParent = TAncestryBase) and
      not TIntBox.InheritsFrom(TByteBox), 5);
{$ifdef FPC_VMT_ANCESTRY}
    Check(PVmt(TObject)^.vTypeDepth = 0, 6);
    Check(PVmt(TDeep3)^.vTypeDepth = 6, 7);
    Check(Assigned(PVmt(TDeep3)^.vAncestors), 8);
    { Runtime VMT copies have no compiler-emitted ancestry of their own.
      Exercise two proxy levels, including a target without metadata. }
    Original := Obj.ClassType;
    VmtBytes := SizeOf(TVmt) + 2 * SizeOf(CodePointer);
    GetMem(Vmt1, VmtBytes);
    GetMem(Vmt2, VmtBytes);
    try
      Move(Pointer(Original)^, Vmt1^, VmtBytes);
      Proxy1 := TClass(Vmt1);
      Vmt1^.vParentRef := PPVmt(@Original);
      Vmt1^.vAncestors := nil;
      Move(Vmt1^, Vmt2^, VmtBytes);
      Proxy2 := TClass(Vmt2);
      Vmt2^.vParentRef := PPVmt(@Proxy1);
      PPointer(Obj)^ := Pointer(Proxy2);
      Check(Obj.Value = 23, 9);
      Check((Obj is TDeep3) and (Obj is TAncestryBase), 10);
      Check(Proxy2.InheritsFrom(Proxy1) and Proxy2.InheritsFrom(Original), 11);
      Check(Proxy2.InheritsFrom(Proxy2) and not Original.InheritsFrom(Proxy1), 12);
      Check(not Proxy2.InheritsFrom(nil) and not Proxy2.InheritsFrom(TAncestryOther), 13);
    finally
      PPointer(Obj)^ := Pointer(Original);
      FreeMem(Vmt2);
      FreeMem(Vmt1);
    end;
{$endif FPC_VMT_ANCESTRY}
  finally
    Obj.Free;
  end;
  WriteLn('ok');
end.
