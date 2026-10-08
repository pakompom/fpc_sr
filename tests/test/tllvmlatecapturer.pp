{ Earlier closure loads must follow a capturer moved into a nested frame. }
{ %OPT=-O2 }
program tllvmlatecapturer;
{$mode delphi}
{$interfaces COM}
type
  TIntRef = reference to function(Delta: Integer): Integer;
  IProbe = interface
    function Touch: Integer;
  end;
  TProbe = class(TInterfacedObject, IProbe)
    constructor Create;
    destructor Destroy; override;
    function Touch: Integer;
  end;
var
  Alive, Destroyed: Integer;

constructor TProbe.Create;
begin
  inherited Create;
  Inc(Alive);
end;

destructor TProbe.Destroy;
begin
  Dec(Alive);
  Inc(Destroyed);
  inherited Destroy;
end;

function TProbe.Touch: Integer;
begin
  Result := 1000;
end;

function Factory(Kind, Seed: Integer): TIntRef;
var
  State: Integer;
  Text: UnicodeString;
  Guard: IProbe;
  Selected, Folded: TIntRef;
begin
  State := Seed;
  Text := 'abc';
  Guard := TProbe.Create;
  Selected := case Kind of
    1: function(Delta: Integer): Integer
       begin
         Inc(State, Delta);
         Text := Text + 'x';
         Result := State + Length(Text) + Guard.Touch + Seed;
       end;
    2: function(Delta: Integer): Integer
       begin
         Inc(State, Delta);
         Text := Text + 'y';
         Result := State + Length(Text) + Guard.Touch + Seed;
       end;
    else function(Delta: Integer): Integer
         begin
           Inc(State, Delta);
           Text := Text + 'z';
           Result := State + Length(Text) + Guard.Touch + Seed;
         end
  end;
  { The discarded branch leaves a nested routine that moves the capturer. }
  Folded := if True then function(Delta: Integer): Integer
              begin Result := State + Delta; end
            else function(Delta: Integer): Integer
              begin Result := State - Delta; end;
  if Folded(0) <> Seed then Halt(1);
  Result := Selected;
end;

function ClobberStack(Value: PtrUInt): PtrUInt;
var
  Buffer: array[0..2047] of PtrUInt;
  I: Integer;
begin
  for I := Low(Buffer) to High(Buffer) do Buffer[I] := Value xor PtrUInt(I);
  Result := 0;
  for I := Low(Buffer) to High(Buffer) do Result := Result xor Buffer[I];
end;

procedure RunOne(Kind: Integer);
var
  Escaped, AliasRef: TIntRef;
  Dummy: PtrUInt;
begin
  Escaped := Factory(Kind, Kind * 100);
  if Alive <> 1 then Halt(2);
  Dummy := ClobberStack(PtrUInt(@Escaped));
  AliasRef := Escaped;
  Escaped := nil;
  if Alive <> 1 then Halt(3);
  if AliasRef(2) <> Kind * 200 + 1006 then Halt(4);
  if AliasRef(3) <> Kind * 200 + 1010 then Halt(5);
  AliasRef := nil;
  if Dummy <> 0 then Halt(7);
end;

var
  Kind: Integer;
begin
  for Kind := 1 to 3 do
  begin
    RunOne(Kind);
    { Hidden interface temporaries have also been finalized at scope exit. }
    if (Alive <> 0) or (Destroyed <> Kind) then
    begin
      WriteLn('Alive=', Alive, ' Destroyed=', Destroyed);
      Halt(6);
    end;
  end;
  WriteLn('ok');
end.
