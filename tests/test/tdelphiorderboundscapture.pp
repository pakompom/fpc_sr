{ %OPT=-O4 -OoNOFASTMATH }
{ Source Integer array bounds retain their scheduling across target-sized
  results, while source casts and wider arguments keep conversion barriers. }
program tdelphiorderboundscapture;
{$IFDEF FPC}{$mode delphi}{$DELPHIORDER OFF}{$ENDIF}
{$APPTYPE CONSOLE}{$Q-}{$R-}{$INLINE ON}
uses Math;
var Values: array of Integer;
  Trace: AnsiString;
  Seen: Int64;

procedure Reset;
begin SetLength(Values,2); Trace:=''; end;

function Mutate: Integer;
begin Trace:=Trace+'M'; SetLength(Values,3); Result:=0; end;

function One: Integer;
begin Trace:=Trace+'O'; Result:=1; end;

procedure Integers(a,b: Integer);
begin Seen:=a; end;

procedure Natives(a: NativeInt; b: Integer);
begin Seen:=a; end;

procedure Wides(a: Int64; b: Integer);
begin Seen:=a; end;

procedure Report(const Name: AnsiString);
begin WriteLn(Name,': ',Trace,' ',Seen); end;

{$IFDEF FPC}{$DELPHIORDER ON}{$ENDIF}
procedure Run;
begin
  Reset; Integers(High(Values),Min(One,Mutate)); Report('integer-high');
  Reset; Integers(Length(Values),Min(One,Mutate)); Report('integer-length');
  Reset; Natives(High(Values),Min(One,Mutate)); Report('native-high');
  Reset; Wides(High(Values),Min(One,Mutate)); Report('wide-high');
  Reset; Integers(Integer(High(Values)),Min(One,Mutate)); Report('integer-cast');
  Reset; Natives(NativeInt(High(Values)),Min(One,Mutate)); Report('native-cast');
  Reset; Wides(Int64(High(Values)),Min(One,Mutate)); Report('wide-cast');
  Reset; Integers(Byte(High(Values)),Min(One,Mutate)); Report('byte-cast');
end;

begin Run; end.
