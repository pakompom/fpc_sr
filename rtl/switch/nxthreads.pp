unit NxThreads;

{$MODE objfpc}
{$H+}
interface

{ Install before units that create threads. Threadvars use libnx TLS slots,
  never LLVM's Linux thread-pointer convention. Foreign threads attach lazily. }
procedure EnsureNxThread;

implementation
{$L nxthread.o}
{$i nxlibc.inc}

type
  TCThreadEntry = function(Argument: Pointer): Pointer; cdecl;
  PThreadStart = ^TThreadStart;
  TThreadStart = record
    Func: TThreadFunc;
    Argument: Pointer;
  end;

function NativeBegin(
    Entry: TCThreadEntry;
    Argument: Pointer;
    StackSize: PtrUInt
): TThreadID; cdecl; external name 'fpc_nx_thread_begin';
function NativeSelf: TThreadID; cdecl; external name 'fpc_nx_thread_self';
procedure NativeExit(Code: DWord); cdecl; external name 'fpc_nx_thread_exit';
function NativeWait(
    Handle: TThreadID;
    Milliseconds: LongInt
): DWord; cdecl; external name 'fpc_nx_thread_wait';
function NativeClose(Handle: TThreadID): DWord; cdecl; external name 'fpc_nx_thread_close';
procedure NativeYield; cdecl; external name 'fpc_nx_thread_yield';
function TLSInit: LongInt; cdecl; external name 'fpc_nx_tls_init';
function TLSGet: Pointer; cdecl; external name 'fpc_nx_tls_get';
procedure TLSSet(P: Pointer); cdecl; external name 'fpc_nx_tls_set';
function NativeStackLow: PtrUInt; cdecl; external name 'fpc_nx_stack_low';
function NativeStackHigh: PtrUInt; cdecl; external name 'fpc_nx_stack_high';
procedure NativeMutexInit(var CS); cdecl; external name 'fpc_nx_mutex_init';
procedure NativeMutexLock(var CS); cdecl; external name 'fpc_nx_mutex_lock';
procedure NativeMutexUnlock(var CS); cdecl; external name 'fpc_nx_mutex_unlock';
function NativeMutexTryLock(var CS): LongInt; cdecl; external name 'fpc_nx_mutex_trylock';
function NativeEventCreate(
    ManualReset,
    Signaled: LongInt
): Pointer; cdecl; external name 'fpc_nx_event_create';
procedure NativeEventDestroy(Event: Pointer); cdecl; external name 'fpc_nx_event_destroy';
procedure NativeEventSet(Event: Pointer); cdecl; external name 'fpc_nx_event_set';
procedure NativeEventReset(Event: Pointer); cdecl; external name 'fpc_nx_event_reset';
function NativeEventWait(
    Event: Pointer;
    Milliseconds: Cardinal
): LongInt; cdecl; external name 'fpc_nx_event_wait';

var
  ThreadVarSize: DWord;

procedure AllocateVars;
var
  P: Pointer;
begin
  P := NxCalloc(1, ThreadVarSize);
  if P = nil then
    Halt(203);
  TLSSet(P);
end;

procedure ReleaseVars;
var
  P: Pointer;
begin
  P := TLSGet;
  TLSSet(nil);
  NxFree(P);
end;

procedure SetStackBounds;
begin
  StackBottom := Pointer(NativeStackLow);
  StackLength := NativeStackHigh - PtrUInt(StackBottom);
end;

procedure EnsureNxThread;
begin
  if TLSGet <> nil then
    Exit;
  AllocateVars;
  InitThread(NativeStackHigh - NativeStackLow);
  SetStackBounds;
end;

procedure CleanupThread; cdecl;
  public name 'fpc_nx_cleanup_thread';
begin
  if TLSGet <> nil then
    DoneThread;
end;

function RunThread(Argument: Pointer): Pointer; cdecl;
var
  Start: TThreadStart;
begin
  EnsureNxThread;
  Start := PThreadStart(Argument)^;
  Dispose(PThreadStart(Argument));
  try
    Result := Pointer(Start.Func(Start.Argument));
  finally
    CleanupThread;
  end;
end;

function StartThread(
    SA: Pointer;
    StackSize: PtrUInt;
    Func: TThreadFunc;
    Argument: Pointer;
    Flags: DWord;
    var ID: TThreadID
): TThreadID;
var
  Start: PThreadStart;
begin
  ID := nil;
  { TThread implements its initial suspension with an RTL event. Arbitrary
    thread suspension is not supported, including CREATE_SUSPENDED here. }
  if Flags <> 0 then
    Exit(nil);
  New(Start);
  Start^.Func := Func;
  Start^.Argument := Argument;
  ID := NativeBegin(@RunThread, Start, StackSize);
  if ID = nil then
    Dispose(Start);
  Result := ID;
end;

procedure FinishThread(Code: DWord);
begin
  CleanupThread;
  NativeExit(Code);
end;

function UnsupportedThread(Handle: TThreadID): DWord;
begin
  Result := DWord(-1);
end;
function CloseThreadHandle(Handle: TThreadID): DWord;
begin
  Result := NativeClose(Handle);
end;
function WaitThread(Handle: TThreadID; Milliseconds: LongInt): DWord;
begin
  Result := NativeWait(Handle, Milliseconds);
end;
procedure YieldThread;
begin
  NativeYield;
end;
function CurrentThreadID: TThreadID;
begin
  Result := NativeSelf;
end;
function SetPriority(Handle: TThreadID; Priority: LongInt): Boolean;
begin
  Result := Priority = 0;
end;
function GetPriority(Handle: TThreadID): LongInt;
begin
  Result := 0;
end;
procedure SetNameA(Handle: TThreadID; const Name: AnsiString);
begin
  { libnx does not expose thread debug names. }
end;
procedure SetNameU(Handle: TThreadID; const Name: UnicodeString);
begin
end;
procedure MutexInit(var CS);
begin
  NativeMutexInit(CS);
end;
procedure MutexDone(var CS);
begin
  { RMutex has no resources to release. }
end;
procedure MutexEnter(var CS);
begin
  NativeMutexLock(CS);
end;
procedure MutexLeave(var CS);
begin
  NativeMutexUnlock(CS);
end;
function MutexTry(var CS): LongInt;
begin
  Result := NativeMutexTryLock(CS);
end;
procedure InitThreadVar(var Offset: DWord; Size: DWord);
begin
  ThreadVarSize := (ThreadVarSize + 15) and not DWord(15);
  Offset := ThreadVarSize;
  Inc(ThreadVarSize, Size);
end;
function RelocateThreadVar(Offset: DWord): Pointer;
begin
  if TLSGet = nil then
    EnsureNxThread;
  Result := PByte(TLSGet) + Offset;
end;
function BasicCreate(
    Attributes: Pointer;
    ManualReset, InitialState: Boolean;
    const Name: AnsiString
): PEventState;
begin
  Result := NativeEventCreate(Ord(ManualReset), Ord(InitialState));
end;
procedure BasicDestroy(Event: PEventState);
begin
  NativeEventDestroy(Event);
end;
procedure BasicSet(Event: PEventState);
begin
  NativeEventSet(Event);
end;
procedure BasicReset(Event: PEventState);
begin
  NativeEventReset(Event);
end;
function BasicWait(Timeout: Cardinal; Event: PEventState; UseComWait: Boolean = False): LongInt;
begin
  Result := NativeEventWait(Event, Timeout);
end;
function RTLCreate: PRTLEvent;
begin
  Result := NativeEventCreate(0, 0);
end;
procedure RTLDestroy(Event: PRTLEvent);
begin
  NativeEventDestroy(Event);
end;
procedure RTLSet(Event: PRTLEvent);
begin
  NativeEventSet(Event);
end;
procedure RTLReset(Event: PRTLEvent);
begin
  NativeEventReset(Event);
end;
procedure RTLWait(Event: PRTLEvent);
begin
  NativeEventWait(Event, High(Cardinal));
end;
procedure RTLWaitTimeout(Event: PRTLEvent; Timeout: LongInt);
begin
  if Timeout < 0 then
    NativeEventWait(Event, High(Cardinal))
  else
    NativeEventWait(Event, Cardinal(Timeout));
end;

function InitializeManager: Boolean;
begin
  if TLSInit < 0 then
    Exit(false);
  InitThreadVars(@RelocateThreadVar);
  ThreadID := NativeSelf;
  SetStackBounds;
  LazyInitThreading;
  IsMultiThread := True;
  Result := True;
end;
function FinalizeManager: Boolean;
begin
  Result := True;
end;

var
  Manager: TThreadManager;
initialization
  FillChar(Manager, SizeOf(Manager), 0);
  Manager.InitManager := @InitializeManager;
  Manager.DoneManager := @FinalizeManager;
  Manager.BeginThread := @StartThread;
  Manager.EndThread := @FinishThread;
  Manager.SuspendThread := @UnsupportedThread;
  Manager.ResumeThread := @UnsupportedThread;
  Manager.KillThread := @UnsupportedThread;
  Manager.CloseThread := @CloseThreadHandle;
  Manager.ThreadSwitch := @YieldThread;
  Manager.WaitForThreadTerminate := @WaitThread;
  Manager.ThreadSetPriority := @SetPriority;
  Manager.ThreadGetPriority := @GetPriority;
  Manager.GetCurrentThreadId := @CurrentThreadID;
  Manager.SetThreadDebugNameA := @SetNameA;
  Manager.SetThreadDebugNameU := @SetNameU;
  Manager.InitCriticalSection := @MutexInit;
  Manager.DoneCriticalSection := @MutexDone;
  Manager.EnterCriticalSection := @MutexEnter;
  Manager.TryEnterCriticalSection := @MutexTry;
  Manager.LeaveCriticalSection := @MutexLeave;
  Manager.InitThreadVar := @InitThreadVar;
  Manager.RelocateThreadVar := @RelocateThreadVar;
  Manager.AllocateThreadVars := @AllocateVars;
  Manager.ReleaseThreadVars := @ReleaseVars;
  Manager.BasicEventCreate := @BasicCreate;
  Manager.BasicEventDestroy := @BasicDestroy;
  Manager.BasicEventResetEvent := @BasicReset;
  Manager.BasicEventSetEvent := @BasicSet;
  Manager.BasicEventWaitFor := @BasicWait;
  Manager.RTLEventCreate := @RTLCreate;
  Manager.RTLEventDestroy := @RTLDestroy;
  Manager.RTLEventSetEvent := @RTLSet;
  Manager.RTLEventResetEvent := @RTLReset;
  Manager.RTLEventWaitFor := @RTLWait;
  Manager.RTLEventWaitForTimeout := @RTLWaitTimeout;
  if not SetThreadManager(Manager) then
    Halt(232);
end.
