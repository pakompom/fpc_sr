unit udelphiinteger32;
{$mode delphi}

interface

function DefaultProduct(a, b: LongInt): Int64; inline;
function DelphiProduct(a, b: LongInt): Int64; inline;
function RestoredProduct(a, b: LongInt): Int64; inline;

implementation

{ No directive: the compatibility setting must default to OFF. }
function DefaultProduct(a, b: LongInt): Int64;
begin
  Result := a * b;
end;

{$push}
{$DELPHIINTEGER32 ON}
function DelphiProduct(a, b: LongInt): Int64;
begin
  Result := a * b;
end;
{$pop}

function RestoredProduct(a, b: LongInt): Int64;
begin
  Result := a * b;
end;

end.
