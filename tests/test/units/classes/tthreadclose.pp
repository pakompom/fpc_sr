{ %SKIPTARGET=$nothread }
program tthreadclose;

{$mode objfpc}

uses
{$ifdef unix}
  cthreads,
{$endif}
  Classes;

type
  TTestThread = class(TThread)
  protected
    procedure Execute; override;
  end;

var
  OriginalManager, TestManager: TThreadManager;
  ExpectedHandle: TThreadID;
  CloseCount: Integer;

procedure TTestThread.Execute;
begin
end;

function CountCloseThread(Handle: TThreadID): DWord;
begin
  if Handle = ExpectedHandle then
    begin
      Inc(CloseCount);
      { A duplicate close may access a released handle. Count it without
        forwarding it, so the regression fails without corrupting the heap. }
      if CloseCount > 1 then
        Exit(0);
    end;
  Result := OriginalManager.CloseThread(Handle);
end;

procedure CheckClose(WaitFirst: Boolean);
var
  Worker: TTestThread;
begin
  CloseCount := 0;
  Worker := TTestThread.Create(False);
  ExpectedHandle := Worker.Handle;
  if WaitFirst then
    Worker.WaitFor;
  Worker.Free;
  if CloseCount <> 1 then
    begin
      WriteLn('WaitFirst=', WaitFirst, ': CloseThread called ', CloseCount, ' times');
      Halt(1);
    end;
end;

begin
  GetThreadManager(OriginalManager);
  TestManager := OriginalManager;
  TestManager.CloseThread := @CountCloseThread;
  if not SetThreadManager(TestManager) then
    Halt(2);
  CheckClose(True);
  CheckClose(False);
  if not SetThreadManager(OriginalManager) then
    Halt(3);
  WriteLn('ok');
end.
