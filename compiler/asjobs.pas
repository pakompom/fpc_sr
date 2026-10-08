{
    Copyright (c) 2026 by the Free Pascal development team

    Bounded external assembler jobs. The compiler remains single threaded;
    only independent LLVM object emission runs in child processes.

    This file is part of the Free Pascal compiler and is distributed under
    the GNU General Public License, version 2 or later.
}
unit asjobs;

{$i fpcdefs.inc}
{$H+}

interface

type
  TAssemblerCommand = record
    executable, parameters, outputname: ansistring;
  end;
  TAssemblerCommands = array of TAssemblerCommand;

function ParallelAssemblerSupported: boolean;
procedure WaitForAssemblerFile(const filename: ansistring);
procedure QueueAssembler(const source, objectname, ppuname: ansistring;
  const commands: TAssemblerCommands; keep_source: boolean);
function AssemblerPPUPath(const objectname, ppuname: ansistring): ansistring;
procedure AssemblerPPUWritten(const objectname: ansistring);
procedure WaitForAssemblerJobs;
procedure DoneAssemblerJobs;

implementation

uses
{$ifdef hasunix}
  BaseUnix, Unix,
{$endif}
  SysUtils, cclasses, cfileutl, globals, verbose, cutils;

type
  TAssemblerJob = class
    source, objectname, ppuname, temporaryppu: ansistring;
    commands: TAssemblerCommands;
    nextcommand, pid: longint;
    completed, succeeded, keep_source, ppuready: boolean;
    procedure PublishPPU;
    procedure RemoveOutputs;
  end;

var
  jobs: TFPObjectList;

function ParallelAssemblerSupported: boolean;
begin
{$ifdef hasunix}
  result:=true;
{$else}
  result:=false;
{$endif}
end;

{$ifdef hasunix}
{$if defined(darwin) or (defined(FPC_USE_LIBC) and not defined(android))}
function assembler_posix_spawn(var pid: TPid; path: PAnsiChar;
  actions, attributes: pointer; argv, env: PPAnsiChar): cint;
  cdecl; weakexternal 'c' name 'posix_spawn';
{$endif}

function StartCommand(const command: TAssemblerCommand): longint;
var
  executable, parameters: RawByteString;
  argv: PPAnsiChar;
  child: TPid;
  code: cint;
  error: EOSError;
begin
  if checkverbosity(V_Executable) then
    Comment(V_Executable,'Executing "'+command.executable+'" with command line "'+command.parameters+'"');
  executable:=command.executable;
  UniqueString(executable);
  SetCodePage(executable,DefaultFileSystemCodePage,true);
  parameters:=UnixRequoteWithDoubleQuotes(command.parameters);
  UniqueString(parameters);
  SetCodePage(parameters,DefaultFileSystemCodePage,true);
  argv:=StringToPPChar(PAnsiChar(parameters),1);
  argv^:=PAnsiChar(executable);
  try
    code:=0;
{$if defined(darwin) or (defined(FPC_USE_LIBC) and not defined(android))}
    if @assembler_posix_spawn<>nil then
      code:=assembler_posix_spawn(child,PAnsiChar(executable),nil,nil,argv,envp)
    else
{$endif}
      begin
        child:=fpFork;
        if child=0 then
          begin
            fpExecVE(PAnsiChar(executable),argv,envp);
            fpExit(127);
          end;
        if child<0 then
          code:=fpGetErrNo;
      end;
    if code<>0 then
      begin
        error:=EOSError.Create(SysErrorMessage(code));
        error.ErrorCode:=code;
        raise error;
      end;
    result:=child;
  finally
    FreeMem(argv);
  end;
end;
{$endif hasunix}

procedure TAssemblerJob.PublishPPU;
begin
  if completed and succeeded and ppuready then
    begin
      if not RenameFile(temporaryppu,ppuname) then
        Message(unit_f_ppu_cannot_write);
      temporaryppu:='';
      ppuready:=false;
    end;
end;

procedure TAssemblerJob.RemoveOutputs;
var
  i: longint;
begin
  for i:=0 to high(commands) do
    DeleteFile(commands[i].outputname);
  if temporaryppu<>'' then
    DeleteFile(temporaryppu);
  if ppuname<>'' then
    DeleteFile(ppuname);
end;

function FindJob(const objectname: ansistring): TAssemblerJob;
var
  i: longint;
begin
  result:=nil;
  if assigned(jobs) then
    for i:=jobs.count-1 downto 0 do
      if TAssemblerJob(jobs[i]).objectname=objectname then
        exit(TAssemblerJob(jobs[i]));
end;

procedure StartJobCommand(job: TAssemblerJob);
begin
{$ifdef hasunix}
  try
    job.pid:=StartCommand(job.commands[job.nextcommand]);
  except
    on error: EOSError do
      begin
        job.completed:=true;
        job.RemoveOutputs;
        Message1(exec_e_cant_call_assembler,tostr(error.ErrorCode));
      end;
  end;
{$endif}
end;

function PollJobs: longint;
var
  i: longint;
  job: TAssemblerJob;
{$ifdef hasunix}
  status, waited: cint;
{$endif}
begin
  result:=0;
  if not assigned(jobs) then
    exit;
  for i:=0 to jobs.count-1 do
    begin
      job:=TAssemblerJob(jobs[i]);
      if job.completed then
        continue;
{$ifdef hasunix}
      waited:=fpWaitPid(job.pid,@status,WNOHANG);
      if (waited=0) or ((waited<0) and (fpGetErrNo=ESysEINTR)) then
        begin
          inc(result);
          continue;
        end;
      job.pid:=0;
      if (waited<0) or (status<>0) then
        begin
          job.completed:=true;
          job.RemoveOutputs;
          if waited<0 then
            status:=-1
          else if WIFEXITED(status) then
            status:=WEXITSTATUS(status)
          else
            status:=128+WTERMSIG(status);
          Message1(exec_e_error_while_assembling,job.source+' ('+tostr(status)+')');
          continue;
        end;
      inc(job.nextcommand);
      if job.nextcommand<length(job.commands) then
        begin
          StartJobCommand(job);
          if not job.completed then
            inc(result);
          continue;
        end;
{$endif}
      job.completed:=true;
      job.succeeded:=true;
      if not job.keep_source then
        DeleteFile(job.source);
      job.PublishPPU;
    end;
end;

procedure WaitForAssemblerFile(const filename: ansistring);
var
  i: longint;
  job: TAssemblerJob;
begin
  if not assigned(jobs) then
    exit;
  for i:=0 to jobs.count-1 do
    begin
      job:=TAssemblerJob(jobs[i]);
      if job.source=filename then
        while not job.completed do
          begin
            PollJobs;
            if not job.completed then
              Sleep(1);
          end;
    end;
  if ErrorCount<>0 then
    Message1(unit_f_errors_in_unit,tostr(ErrorCount));
end;

procedure QueueAssembler(const source, objectname, ppuname: ansistring;
  const commands: TAssemblerCommands; keep_source: boolean);
var
  job: TAssemblerJob;
begin
  while PollJobs>=assemblerjobs do
    Sleep(1);
  if ErrorCount<>0 then
    exit;
  if not assigned(jobs) then
    jobs:=TFPObjectList.Create(true);
  job:=TAssemblerJob.Create;
  jobs.Add(job);
  job.source:=source;
  job.objectname:=objectname;
  job.ppuname:=ppuname;
  job.commands:=commands;
  job.keep_source:=keep_source;
  { The old PPU must not survive an interrupted replacement of its object.
    New PPU contents are serialized normally, but published only on success. }
  if ppuname<>'' then
    DeleteFile(ppuname);
  StartJobCommand(job);
end;

function AssemblerPPUPath(const objectname, ppuname: ansistring): ansistring;
var
  job: TAssemblerJob;
begin
  PollJobs;
  if ErrorCount<>0 then
    Message1(unit_f_errors_in_unit,tostr(ErrorCount));
  result:=ppuname;
  job:=FindJob(objectname);
  if assigned(job) and not job.completed then
    begin
      job.ppuname:=ppuname;
      job.temporaryppu:=ppuname+'.tmp.'+tostr(GetProcessID);
      result:=job.temporaryppu;
    end;
end;

procedure AssemblerPPUWritten(const objectname: ansistring);
var
  job: TAssemblerJob;
begin
  job:=FindJob(objectname);
  if assigned(job) and (job.temporaryppu<>'') then
    begin
      job.ppuready:=true;
      job.PublishPPU;
    end;
end;

procedure WaitForAssemblerJobs;
begin
  while PollJobs<>0 do
    Sleep(1);
  if ErrorCount<>0 then
    Message1(unit_f_errors_in_unit,tostr(ErrorCount));
end;

procedure DoneAssemblerJobs;
var
  i: longint;
  job: TAssemblerJob;
{$ifdef hasunix}
  status: cint;
{$endif}
begin
  if not assigned(jobs) then
    exit;
  for i:=0 to jobs.count-1 do
    begin
      job:=TAssemblerJob(jobs[i]);
      if not job.completed then
        begin
{$ifdef hasunix}
          if job.pid>0 then
            begin
              { A driver may have its own child. Killing only the driver can
                leave that child writing objects after cleanup. Finish the
                current command, without starting any remaining LTO pass. }
              while (fpWaitPid(job.pid,@status,0)<0) and (fpGetErrNo=ESysEINTR) do;
            end;
{$endif}
          job.RemoveOutputs;
        end
      else if job.temporaryppu<>'' then
        DeleteFile(job.temporaryppu);
    end;
  FreeAndNil(jobs);
end;

end.
