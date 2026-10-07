{ %OPT=-O2 }
program tllvmatomicincdec;

{$mode objfpc}
{$Q+}
{$R+}
{$inline off}

{ The RTL uses these implementation-only operations for reference counts. }
{$ifdef CPULLVM}
function RefIncrement(var Value: LongInt): LongInt; [internproc:fpc_in_refcount_inc];
function RefIncrement(var Value: Int64): Int64; [internproc:fpc_in_refcount_inc];
function RefDecrement(var Value: LongInt): LongInt; [internproc:fpc_in_refcount_dec];
function RefDecrement(var Value: Int64): Int64; [internproc:fpc_in_refcount_dec];
{$endif CPULLVM}

type
  TPacked = packed record
    Prefix: Byte;
    Value: LongInt;
  end;

var
  A: ShortInt;
  B: SmallInt;
  C: LongInt;
  D: Int64;
  U: QWord;
  Calls: LongInt;
  PackedValue: TPacked;

procedure Check(Condition: Boolean);
begin
  if not Condition then Halt(1);
end;

function Target: PLongInt;
begin
  Inc(Calls);
  Result := @C;
end;

procedure Discard;
begin
  AtomicIncrement(C);
  AtomicDecrement(D);
end;

function PackedIncrement: LongInt;
begin
  { Unaligned targets retain the original platform helper. }
  Result := AtomicIncrement(PackedValue.Value);
end;

begin
  A := High(ShortInt);
  Check(AtomicIncrement(A) = Low(ShortInt));
  Check(AtomicDecrement(A) = High(ShortInt));
  B := High(SmallInt);
  Check(AtomicIncrement(B) = Low(SmallInt));
  Check(AtomicDecrement(B) = High(SmallInt));
  C := High(LongInt);
  Check(AtomicIncrement(Target^) = Low(LongInt));
  Check(AtomicDecrement(Target^) = High(LongInt));
  Check(Calls = 2);
  D := High(Int64);
  Check(AtomicIncrement(D) = Low(Int64));
  Check(AtomicDecrement(D) = High(Int64));
  U := High(QWord);
  Check(QWord(AtomicIncrement(U)) = 0);
  Check(QWord(AtomicDecrement(U)) = High(QWord));
  C := 1;
  D := 1;
  Discard;
  Check((C = 2) and (D = 0));
  { These overloads retain their existing helper implementation. }
  Check(AtomicIncrement(C, 3) = 5);
  Check(AtomicDecrement(C, 2) = 3);
  Check(AtomicIncrement(Volatile(C)) = 4);
  Check(AtomicDecrement(Volatile(C)) = 3);
{$ifdef CPULLVM}
  C := High(LongInt);
  Calls := 0;
  Check(RefIncrement(Target^) = Low(LongInt));
  Check(RefDecrement(Target^) = High(LongInt));
  Check(Calls = 2);
  D := High(Int64);
  Check(RefIncrement(D) = Low(Int64));
  Check(RefDecrement(D) = High(Int64));
  C := 1;
  D := 1;
  RefIncrement(C);
  RefDecrement(D);
  Check((C = 2) and (D = 0));
{$endif CPULLVM}
{$if defined(CPU386) or defined(CPUX86_64)}
  PackedValue.Value := 1;
  Check(PackedIncrement = 2);
{$endif}
  WriteLn('ok');
end.
