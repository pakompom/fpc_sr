unit reloadclass_child;

{$mode objfpc}
{$inline on}

interface

uses reloadclass_base;

procedure Accept(Value: TBase);
function Inlined(Value: TBase): TBase; inline;

implementation

function Identity(Value: TBase): TBase;
begin
  Result:=Value;
end;

procedure Accept(Value: TBase);
begin
  Value.Value:=42;
end;

function Inlined(Value: TBase): TBase;
begin
  { The inline body also registers Identity in the local symbol table. Both
    its parameter and result types must be resolved again after a reload. }
  Result:=Identity(Value);
  Accept(Result);
end;

end.
