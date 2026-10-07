{ %FAIL }

{ Constant expressions still diagnose overflow with runtime checking off. }
program tdelphiinteger32const;
{$mode delphi}
{$DELPHIINTEGER32 ON}{$Q-}
const
  Product = 65536 * 65536;
begin
  Writeln(Product);
end.
