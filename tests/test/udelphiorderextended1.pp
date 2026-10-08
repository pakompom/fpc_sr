unit udelphiorderextended1;
{$mode delphi}{$DELPHIORDER OFF}{$INLINE OFF}

interface

type
  TExtendedAlias = Extended;
  TExtendedDistinct = type Extended;
  TDoubleAlias = Double;
  TExtendedGetter = function: TExtendedAlias;
  TDoubleGetter = function: TDoubleAlias;
  TRealSource = class
    Tag: Char;
    Value: Double;
    function AsExtended: TExtendedAlias;
    function AsDistinct: TExtendedDistinct;
    function AsDouble: TDoubleAlias;
  end;

var Trace: AnsiString;

function ExtendedLeft: TExtendedAlias;
function ExtendedRight: TExtendedAlias;
function DistinctLeft: TExtendedDistinct;
function DoubleLeft: TDoubleAlias;
function DoubleRight: TDoubleAlias;

implementation

function TRealSource.AsExtended: TExtendedAlias;
begin Trace:=Trace+Tag; Result:=Value; end;

function TRealSource.AsDistinct: TExtendedDistinct;
begin Trace:=Trace+Tag; Result:=Value; end;

function TRealSource.AsDouble: TDoubleAlias;
begin Trace:=Trace+Tag; Result:=Value; end;

function ExtendedLeft: TExtendedAlias;
begin Trace:=Trace+'L'; Result:=2; end;

function ExtendedRight: TExtendedAlias;
begin Trace:=Trace+'R'; Result:=4; end;

function DistinctLeft: TExtendedDistinct;
begin Trace:=Trace+'L'; Result:=2; end;

function DoubleLeft: TDoubleAlias;
begin Trace:=Trace+'L'; Result:=2; end;

function DoubleRight: TDoubleAlias;
begin Trace:=Trace+'R'; Result:=4; end;

end.
