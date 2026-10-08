unit reloadclass_base;

{$mode objfpc}

interface

type
  TBase = class
    Value: LongInt;
  end;
  TBaseCallback = function(Value: TBase): TBase;
  TBaseData = record
    Item: TBase;
    Callback: TBaseCallback;
  end;

function IdentityBase(Value: TBase): TBase;

implementation

uses reloadclass_control;

function IdentityBase(Value: TBase): TBase;
begin
  Result:=Value;
end;

end.
