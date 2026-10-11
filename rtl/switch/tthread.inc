{
    This file is part of the Free Component Library (FCL)
    Copyright (c) 1999-2000 by the Free Pascal development team
    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 **********************************************************************}
{ Adapted from rtl/wasicommon/tthread.inc (FPC_WASM_THREADS implementation).
  Uses the same event-gated construction and cooperative suspension lifecycle.
  Switch waits through NxThreads and leaves handle closure to the common
  TThread.Destroy; the native reaper safely closes FreeOnTerminate threads
  after they exit. External suspension and priorities remain unsupported. }
{****************************************************************************}
{*                             TThread                                      *}
{****************************************************************************}
procedure TThread.CallOnTerminate;
begin
  FOnTerminate(self);
end;
function TThread.GetPriority: TThreadPriority;
begin
  GetPriority := tpNormal;
end;
procedure TThread.SetPriority(Value: TThreadPriority);
begin
  // Not supported
end;
procedure TThread.SetSuspended(Value: Boolean);
begin
  if Value <> FSuspended then
    if Value then
      Suspend
    else
      Resume;
end;
procedure TThread.DoTerminate;
begin
  if Assigned(FOnTerminate) then
    Synchronize(@CallOnTerminate);
end;
function ThreadFunc(parameter: Pointer): ptrint;
var
  LThread: TThread absolute parameter;
  LFreeOnTerminate: Boolean;
begin
  try
    if LThread.FInitialSuspended then begin
      RtlEventWaitFor(LThread.FSuspendEvent);
      if not LThread.FTerminated and not LThread.FSuspended then begin
        LThread.FInitialSuspended := false;
        CurrentThreadVar := LThread;
        LThread.Execute;
      end
    end
    else begin
      // The suspend internal is needed due to bug 16884
      LThread.FSuspendedInternal := True;
      RtlEventWaitFor(LThread.FSuspendEvent);
      CurrentThreadVar := LThread;
      LThread.Execute;
    end;
  except
    on e: exception do begin
      LThread.FFatalException := TObject(AcquireExceptionObject);
      if e is EThreadDestroyCalled then
        LThread.FFreeOnTerminate := true;
    end;
  end;
  Result := LThread.FReturnValue;
  LFreeOnTerminate := LThread.FreeOnTerminate;
  LThread.DoTerminate;
  LThread.FFinished := True;
  if LFreeOnTerminate then begin
    LThread.Free;
  end;
  EndThread(Result);
end;
procedure TThread.SysCreate(CreateSuspended: Boolean; const StackSize: SizeUInt);
begin
  FSuspendEvent := RtlEventCreate;
  FSuspended := CreateSuspended;
  FThreadReaped := false;
  FInitialSuspended := CreateSuspended;
  FSuspendedInternal := not CreateSuspended;
  FFatalException := nil;
  FHandle := BeginThread(@ThreadFunc, Pointer(Self), FThreadID, StackSize);
  if FHandle = TThreadID(0) then begin
    raise EThread.create('Failed to create new thread');
  end;
end;
procedure TThread.SysDestroy;
begin
  { exception in constructor }
  if not assigned(FSuspendEvent) then
    exit;
  { exception in constructor }
  if (FHandle = TThreadID(0)) then begin
    RtlEventDestroy(FSuspendEvent);
    exit;
  end;
  { Thread itself called destroy ? }
  if (FThreadID = GetCurrentThreadID) then begin
    if not (FFreeOnTerminate) and not FFinished then begin
      raise EThreadDestroyCalled.Create(
          'A thread cannot destroy itself except by setting FreeOnTerminate and leaving!');
    end;
    FFreeOnTerminate := false;
  end
  else begin
    { avoid recursion}
    FFreeOnTerminate := false;
    { you can't join yourself, so only for FThreadID<>GetCurrentThreadID }
    { and you can't join twice -> make sure we didn't join already       }
    if not FThreadReaped then begin
      Terminate;
      if (FSuspendedInternal or FInitialSuspended) then begin
        Resume;
      end;
      // Before calling WaitFor, signal main thread with WakeMainThread, so pending checksynchronize calls are handled.
      if assigned(WakeMainThread) then
        WakeMainThread(Self);
      WaitFor;
    end;
  end;
  RtlEventDestroy(FSuspendEvent);
  FFatalException.Free;
  FFatalException := nil;
  { The common TThread.Destroy closes FHandle after SysDestroy returns. }
end;
procedure TThread.Resume;
begin
  if FSuspendedInternal
      and (InterLockedExchange(longint(FSuspendedInternal), ord(false)) = longint(longbool(true))) then
  begin
    RtlEventSetEvent(FSuspendEvent);
  end
  else begin
    { don't compare with ord(true) or ord(longbool(true)), }
    { because a longbool's "true" value is anything <> false}
    if FSuspended and (InterLockedExchange(longint(FSuspended), longint(false)) <> longint(longbool(false))) then begin
      RtlEventSetEvent(FSuspendEvent);
    end;
  end
end;
procedure TThread.Suspend;
begin
  if FThreadID <> GetCurrentThreadID then
    raise EThread.create('Suspending another thread is unsupported on Nintendo Switch');
  { don't compare with ord(true) or ord(longbool(true)), }
  { because a longbool's "true" value is anything <> false}
  if not FSuspended
      and (InterLockedExchange(longint(FSuspended), longint(longbool(true))) = longint(longbool(false))) then
    RtlEventWaitFor(FSuspendEvent)
end;
function TThread.WaitFor: Integer;
begin
  if (MainThreadID = GetCurrentThreadID) then
    {
     FFinished is set after DoTerminate, which does a synchronize of OnTerminate,
     so make sure synchronize works (or indeed any other synchronize that may be
     in progress)
    }
    while not FFinished do
      CheckSynchronize(100);
  WaitFor := WaitForThreadTerminate(FThreadID, -1);
  { should actually check for errors in WaitForThreadTerminate, but no }
  { error api is defined for that function                             }
  FThreadReaped := true;
end;
