unit uvmtancestry;
{$mode objfpc}
interface

type
  TAncestryBase = class
    function Value: Integer; virtual;
  end;
  TAncestryChild = class(TAncestryBase)
    function Value: Integer; override;
  end;
  TAncestryOther = class end;

implementation

function TAncestryBase.Value: Integer;
begin
  Result := 7;
end;

function TAncestryChild.Value: Integer;
begin
  Result := 11;
end;

end.
