{ Free Pascal RTL for Nintendo Switch (libnx/newlib).
  Distributed under the RTL license in COPYING.FPC. }
unit System;
interface
{$DEFINE FPC_IS_SYSTEM}
{$DEFINE HAS_CMDLINE}
{$DEFINE USE_NOTHREADMANAGER}
{$DEFINE FPC_SYSTEM_EXIT_NO_RETURN}
{$i systemh.inc}
const
  LineEnding = #10;
  LFNSupport = true;
  DirectorySeparator = '/';
  DriveSeparator = ':';
  ExtensionSeparator = '.';
  PathSeparator = ';';
  AllowDirectorySeparators: set of AnsiChar = ['/', '\'];
  AllowDriveSeparators: set of AnsiChar = [':'];
  maxExitCode = 255;
  MaxPathLen = 4096;
  AllFilesMask = '*';
  SharedSuffix = 'so';
  UnusedHandle = -1;
  StdInputHandle = 0;
  StdOutputHandle = 1;
  StdErrorHandle = 2;
  FileNameCaseSensitive: boolean = false;
  FileNameCasePreserving: boolean = true;
  CtrlZMarksEOF: boolean = false;
  sLineBreak = LineEnding;
  DefaultTextLineBreakStyle: TTextLineBreakStyle = tlbsLF;
var
  argc: LongInt;
  external name 'fpc_nx_argc';
  argv: PPAnsiChar;
  external name 'fpc_nx_argv';
  envp: PPAnsiChar;
  cmdline: PAnsiChar;
implementation
{$L nxlibc.o}
{$L nx_start.o}
{$i nxlibc.inc}
{$i system.inc}
procedure NxExit(Code: LongInt); cdecl; external name 'fpc_nx_exit';
function NativeStackLow: PtrUInt; cdecl; external name 'fpc_nx_stack_low';
function NativeStackHigh: PtrUInt; cdecl; external name 'fpc_nx_stack_high';
procedure System_exit;
  noreturn;
begin
  NxExit(ExitCode);
  while true do
    ;
end;
function GetProcessID: SizeUInt;
begin
  Result := 1;
end;
procedure Randomize;
begin
  RandSeed := LongInt(NxTicks);
end;
function ParamCount: LongInt;
begin
  if argc > 0 then
    Result := argc - 1
  else
    Result := 0;
end;
function ParamStr(l: LongInt): ShortString;
begin
  if (l >= 0) and (l < argc) then
    Result := StrPas(argv[l])
  else
    Result := '';
end;
procedure SysInitStdIO;
begin
  OpenStdIO(Input, fmInput, StdInputHandle);
  OpenStdIO(Output, fmOutput, StdOutputHandle);
  OpenStdIO(ErrOutput, fmOutput, StdErrorHandle);
  OpenStdIO(StdOut, fmOutput, StdOutputHandle);
  OpenStdIO(StdErr, fmOutput, StdErrorHandle);
end;
function CheckInitialStkLen(stklen: SizeUInt): SizeUInt;
begin
  Result := stklen;
end;
begin
  IsConsole := true;
  StackBottom := Pointer(NativeStackLow);
  StackLength := NativeStackHigh - PtrUInt(StackBottom);
  InitHeap;
  SysInitExceptions;
  DefaultSystemCodePage := CP_UTF8;
  DefaultFileSystemCodePage := CP_UTF8;
  DefaultRTLFileSystemCodePage := CP_UTF8;
  InitUnicodeStringManager;
  SysInitStdIO;
  InOutRes := 0;
  InitSystemThreads;
end.
