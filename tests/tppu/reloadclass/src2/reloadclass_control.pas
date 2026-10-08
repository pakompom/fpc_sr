unit reloadclass_control;

{$mode objfpc}
{$inline on}

interface

uses reloadclass_base, reloadclass_child;

const Factor = 2; // changes the interface CRC, forcing base to be recompiled

{ LLVM emits these initializers while parsing the interface, before base's
  types are replaced. Their type references must survive the later reload. }
const
  Empty: TBase = nil;
  Data: array[0..1] of TBaseData = (
    (Item: nil; Callback: @IdentityBase),
    (Item: nil; Callback: @IdentityBase));

procedure Test(Value: TBase);

implementation

procedure Test(Value: TBase);
begin
  Accept(Value);
  if Inlined(Value)<>Value then
    Halt(1);
  if (Empty<>nil) or (Data[0].Item<>nil) or
     (Data[1].Callback(Value)<>Value) then
    Halt(3);
end;

end.
