{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2006 by Florian Klaempfl and Pavel Ozerski
    member of the Free Pascal development team.

    FPC Pascal system unit for the Win64 API.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit System;

interface

{$define FPC_IS_SYSTEM}
{ $define SYSTEMEXCEPTIONDEBUG}

{$ifdef SYSTEMDEBUG}
  {$define SYSTEMEXCEPTIONDEBUG}
{$endif SYSTEMDEBUG}

{$define DISABLE_NO_THREAD_MANAGER}
{$define HAS_WIDESTRINGMANAGER}
{$define DISABLE_NO_DYNLIBS_MANAGER}
{$define FPC_SYSTEM_HAS_SYSDLH}
{$define FPC_HAS_SETCTRLBREAKHANDLER}

{$if defined(CPULLVM) and defined(CPUX86_64)}
{ LLVM can lower memory operations and arithmetic intrinsics to C runtime
  calls even in Pascal-only programs and the bootstrap's fpcmemdll. }
{$linklib msvcrt}
{$linklib clang_rt.builtins-x86_64}
{$endif}

{$if defined(FPC_USE_WIN64_SEH) or defined(CPUAARCH64)}
{$define SYSTEM_USE_WIN_SEH}
{$endif}

{$ifdef SYSTEM_USE_WIN_SEH}
  {$define FPC_SYSTEM_HAS_RAISEEXCEPTION}
  {$define FPC_SYSTEM_HAS_RERAISE}
  {$define FPC_SYSTEM_HAS_CAPTUREBACKTRACE}
{$endif SYSTEM_USE_WIN_SEH}

{$ifdef VER3_2}
  {$define FPC_ABI_WIN64}
{$endif VER3_2}

{ include system-independent routine headers }
{$I systemh.inc}
{ include common windows headers }
{$I syswinh.inc}

var
  MainInstance : qword;

{$if defined(CPULLVM) and not defined(SYSTEM_USE_WIN_SEH)}
var
  Win64DefaultErrorProc: TErrorProc;
{ Used by SysUtils after an ErrorProc hook delegates the original fault. }
function Win64NativeErrorObject(error: longint; addr: CodePointer; frame: pointer): TObject;
{$endif}

implementation

var
  FPCSysInstance : PQWord;public name '_FPC_SysInstance';

{$define FPC_SYSTEM_HAS_OSSETUPENTRYINFORMATION}
procedure OsSetupEntryInformation(constref info: TEntryInformation); forward;

procedure SetupEntryInformation(constref info: TEntryInformation);forward;

{$define FPC_SYSTEM_HAS_STACKTOP}
{$ifdef SYSTEM_USE_WIN_SEH}
function main_wrapper(arg: Pointer; proc: Pointer): ptrint; forward;
{$endif}

{ include system independent routines }
{$I system.inc}

{$ifndef SYSTEM_USE_WIN_SEH}
procedure install_exception_handlers;forward;
{$endif SYSTEM_USE_WIN_SEH}

{$I cpuwin.inc}

{*****************************************************************************
                         System Dependent Exit code
*****************************************************************************}


{ include code common with win32 }
{$I syswin.inc}

procedure OsSetupEntryInformation(constref info: TEntryInformation);
begin
  TlsKey := info.OS.TlsKeyAddr;
  FPCSysInstance := info.OS.SysInstance;
  WStrInitTablesTable := info.OS.WideInitTables;
end;

Procedure system_exit;
begin
  { see comments in win32/system.pp about this logic }
  if IsLibrary then
  begin
    if DllInitState in [DLL_PROCESS_ATTACH,DLL_PROCESS_DETACH] then
      LongJmp(DLLBuf,1)
    else
      DllProcessAttachPerformed:=false;
  end;
  if not IsConsole then
   begin
     Close(stderr);
     Close(stdout);
     Close(erroutput);
     Close(Input);
     Close(Output);
     { what about Input and Output ?? PM }
     { now handled, FPK }
   end;
  if Ole32Dll <> 0 then
    begin
      WinFreeLibrary(Ole32Dll); { Careful, FreeLibrary should not be called from DllMain. }
      Ole32Dll := 0;
    end;
  if OleAut32Dll <> 0 then
    begin
      WinFreeLibrary(OleAut32Dll);
      OleAut32Dll := 0;
    end;

  { call exitprocess, with cleanup as required }
  ExitProcess(exitcode);
end;

//
// Hardware exception handling
//
{$I seh64.inc}

type
  TVectoredExceptionHandler = function (excep : PExceptionPointers) : Longint;

function AddVectoredExceptionHandler(FirstHandler : DWORD;VectoredHandler : TVectoredExceptionHandler) : longint;
        external 'kernel32' name 'AddVectoredExceptionHandler';

{$ifndef SYSTEM_USE_WIN_SEH}
const
  MaxExceptionLevel = 16;
  exceptLevel : Byte = 0;

var
  exceptRip       : array[0..MaxExceptionLevel-1] of Int64;
  exceptError     : array[0..MaxExceptionLevel-1] of Byte;
  resetFPU        : array[0..MaxExceptionLevel-1] of Boolean;

{$ifdef SYSTEMEXCEPTIONDEBUG}
procedure DebugHandleErrorAddrFrame(error : longint; addr, frame : pointer);
begin
  if IsConsole then
    begin
      write(stderr,'HandleErrorAddrFrame(error=',error);
      write(stderr,',addr=',hexstr(int64(addr),16));
      writeln(stderr,',frame=',hexstr(int64(frame),16),')');
    end;
  HandleErrorAddrFrame(error,addr,frame);
end;
{$endif SYSTEMEXCEPTIONDEBUG}

{$ifdef CPULLVM}
type
  PLLVMErrorFrame = ^TLLVMErrorFrame;
  TLLVMErrorFrame = packed record
    IP, CS, Flags, SP, SS: QWord;
  end;
  PLLVMNativeError = ^TLLVMNativeError;
  TLLVMNativeError = record
    ExceptionRecord: TExceptionRecord;
    ResetFPU: Boolean;
  end;
  PLLVMErrorContext = ^TLLVMErrorContext;
  TLLVMErrorContext = record
    Native: PLLVMNativeError;
    Error: longint;
    Addr: CodePointer;
    Frame: pointer;
  end;

threadvar
  LLVMErrorContext: PLLVMErrorContext;

function Win64NativeErrorObject(error: longint; addr: CodePointer; frame: pointer): TObject;
var
  context: PLLVMErrorContext;
  native: PLLVMNativeError;
begin
  Win64NativeErrorObject:=nil;
  context:=LLVMErrorContext;
  if (context=nil) or (context^.Error<>error) or
     (context^.Addr<>addr) or (context^.Frame<>frame) then
    exit;
  native:=context^.Native;
  { Consume before calling user code or allocating the exception. A runtime
    error raised inside the factory must not inherit the original OS record. }
  context^.Native:=nil;
  if (native<>nil) and Assigned(ExceptObjProc) then
    Win64NativeErrorObject:=TObject(TExceptObjProc(ExceptObjProc)(error,native^.ExceptionRecord));
end;

procedure LLVMHandleNativeError(error: longint; addr, frame: pointer;
  native: PLLVMNativeError); [public,alias: 'FPC_WIN64_HANDLE_NATIVE_ERROR'];
var
  context: TLLVMErrorContext;
  previous: PLLVMErrorContext;
  obj: TObject;
begin
  if native^.ResetFPU then
    SysResetFPU;
  { The unhooked SysUtils path needs no pending context or cleanup unwind.
    An outer hook's context must still be isolated when it changes ErrorProc. }
  if Assigned(Win64DefaultErrorProc) and
     (CodePointer(ErrorProc)=CodePointer(Win64DefaultErrorProc)) and
     (LLVMErrorContext=nil) then
    begin
      if Assigned(ExceptObjProc) then
        begin
          obj:=TObject(TExceptObjProc(ExceptObjProc)(error,native^.ExceptionRecord));
          if obj<>nil then
            raise obj at addr,frame;
        end;
      HandleErrorAddrFrame(error,addr,frame);
      exit;
    end;
  context.Native:=native;
  context.Error:=error;
  context.Addr:=addr;
  context.Frame:=frame;
  previous:=LLVMErrorContext;
  LLVMErrorContext:=@context;
  try
    { Preserve ErrorProc, including hooks that replace, delegate or decline
      translation. SysUtils copies the record before this stack is unwound. }
    HandleErrorAddrFrame(error,addr,frame);
  finally
    LLVMErrorContext:=previous;
  end;
end;

{ The exception context supplies a machine frame. Describe it to SEH so
  unwinding restores the faulting stack even when LLVM omitted RBP. }
procedure LLVMHandleErrorFrame; assembler; nostackframe;
asm
  .seh_pushframe
  subq $40,%rsp
  .seh_stackalloc 40
  .seh_endprologue
  call LLVMHandleNativeError
  int3
end;
{$else}
procedure JumpToHandleErrorFrame;
  var
    rip, rbp : int64;
    error : longint;
  begin
    // save ebp
    {$ifdef CPUX86_64}
    asm
      movq (%rbp),%rax
      movq %rax,rbp
    end;
    {$endif}
    if exceptLevel>0 then
      dec(exceptLevel);

    rip:=exceptRip[exceptLevel];
    error:=exceptError[exceptLevel];
{$ifdef SYSTEMEXCEPTIONDEBUG}
    if IsConsole then
      writeln(stderr,'In JumpToHandleErrorFrame error=',error);
{$endif SYSTEMEXCEPTIONDEBUG}
    if resetFPU[exceptLevel] then
      SysResetFPU;
    { build a fake stack }
    {$ifdef CPUX86_64}
    asm
      movq   rbp,%r8
      movq   rip,%rdx
      movl   error,%ecx
      pushq  rip
      movq   rbp,%rbp // Change frame pointer

{$ifdef SYSTEMEXCEPTIONDEBUG}
      jmpl   DebugHandleErrorAddrFrame
{$else not SYSTEMEXCEPTIONDEBUG}
      jmpl   HandleErrorAddrFrame
{$endif SYSTEMEXCEPTIONDEBUG}
    end;
    {$endif}
  end;


{$endif CPULLVM}

function syswin64_x86_64_exception_handler(excep : PExceptionPointers) : Longint;public;
  var
    res: longint;
    err: byte;
    must_reset_fpu: boolean;
{$ifdef CPULLVM}
    frame: PLLVMErrorFrame;
    native: PLLVMNativeError;
    native_record: TExceptionRecord;
{$endif}
  begin
    res:=EXCEPTION_CONTINUE_SEARCH;
{$ifdef SYSTEMEXCEPTIONDEBUG}
    if IsConsole then
      Writeln(stderr,'syswin64_x86_64_exception_handler called');
{$endif SYSTEMEXCEPTIONDEBUG}
    if excep^.ContextRecord^.SegSs=_SS then
      begin
        err := 0;
        must_reset_fpu := true;
{$ifdef SYSTEMEXCEPTIONDEBUG}
        if IsConsole then Writeln(stderr,'Exception ',
          hexstr(excep^.ExceptionRecord^.ExceptionCode,8));
{$endif SYSTEMEXCEPTIONDEBUG}
        case cardinal(excep^.ExceptionRecord^.ExceptionCode) of
          STATUS_INTEGER_DIVIDE_BY_ZERO,
          STATUS_FLOAT_DIVIDE_BY_ZERO :
            err := 208;
          STATUS_ARRAY_BOUNDS_EXCEEDED :
            begin
              err := 201;
              must_reset_fpu := false;
            end;
          STATUS_STACK_OVERFLOW :
            begin
              err := 202;
              must_reset_fpu := false;
            end;
          STATUS_FLOAT_OVERFLOW :
            err := 205;
          STATUS_FLOAT_DENORMAL_OPERAND,
          STATUS_FLOAT_UNDERFLOW :
            err := 206;
            { excep^.ContextRecord^.FloatSave.StatusWord := excep^.ContextRecord^.FloatSave.StatusWord and $ffffff00;}
          STATUS_FLOAT_INEXACT_RESULT,
          STATUS_FLOAT_INVALID_OPERATION,
          STATUS_FLOAT_STACK_CHECK :
            err := 207;
          STATUS_INTEGER_OVERFLOW :
            begin
              err := 215;
              must_reset_fpu := false;
            end;
          STATUS_ILLEGAL_INSTRUCTION:
            err := 216;
          STATUS_IN_PAGE_ERROR:
            begin
              err := 216;
              must_reset_fpu := false;
            end;
          STATUS_ACCESS_VIOLATION:
            { Athlon prefetch bug? }
            if is_prefetch(pointer(excep^.ContextRecord^.rip)) then
              begin
                { if yes, then retry }
                excep^.ExceptionRecord^.ExceptionCode := 0;
                res:=EXCEPTION_CONTINUE_EXECUTION;
              end
            else
              err := 216;

          STATUS_CONTROL_C_EXIT:
            err := 217;
          STATUS_PRIVILEGED_INSTRUCTION:
            begin
              err := 218;
              must_reset_fpu := false;
            end;
          else
            { Vectored handlers run before a library's structured handlers.
              Leave foreign exceptions (including MSVC C++ exceptions) alone,
              even when their severity is ERROR. Translating them to error 217
              bypasses their native handlers and incorrectly raises EControlC. }
            res:=EXCEPTION_CONTINUE_SEARCH;
        end;

        if (err <> 0) and (exceptLevel < MaxExceptionLevel) then
          begin
{$ifdef CPULLVM}
            { The OS record may overlap the space below the faulting RSP.
              Snapshot it before clearing it or constructing the bridge. }
            native_record:=excep^.ExceptionRecord^;
{$endif}
            excep^.ExceptionRecord^.ExceptionCode := 0;
{$ifdef CPULLVM}
            { Keep the OS record on the faulting stack until SysUtils copies it. }
            native:=PLLVMNativeError((excep^.ContextRecord^.Rsp and not QWord(15))-
              ((SizeOf(TLLVMNativeError)+15) and not SizeUInt(15)));
            native^.ExceptionRecord:=native_record;
            native^.ResetFPU:=must_reset_fpu;
            frame:=PLLVMErrorFrame(PtrUInt(native)-SizeOf(TLLVMErrorFrame));
            frame^.IP:=excep^.ContextRecord^.Rip+1;
            frame^.CS:=excep^.ContextRecord^.SegCs;
            frame^.Flags:=excep^.ContextRecord^.EFlags;
            frame^.SP:=excep^.ContextRecord^.Rsp;
            frame^.SS:=excep^.ContextRecord^.SegSs;
            excep^.ContextRecord^.Rcx:=err;
            excep^.ContextRecord^.Rdx:=excep^.ContextRecord^.Rip;
            excep^.ContextRecord^.R8:=excep^.ContextRecord^.Rbp;
            excep^.ContextRecord^.R9:=QWord(native);
            excep^.ContextRecord^.Rsp:=QWord(frame);
            excep^.ContextRecord^.Rip:=QWord(@LLVMHandleErrorFrame);
{$else}
            exceptRip[exceptLevel] := excep^.ContextRecord^.Rip;
            exceptError[exceptLevel] := err;
            resetFPU[exceptLevel] := must_reset_fpu;
            inc(exceptLevel);

            excep^.ContextRecord^.Rip := Int64(@JumpToHandleErrorFrame);
{$endif}

            res := EXCEPTION_CONTINUE_EXECUTION;
{$ifdef SYSTEMEXCEPTIONDEBUG}
            if IsConsole then begin
              writeln(stderr,'Hardware exception redirected to ',
                      hexstr(excep^.ContextRecord^.Rip,16), ' error=', err);
            end;
{$endif SYSTEMEXCEPTIONDEBUG}
        end;
    end;
    syswin64_x86_64_exception_handler := res;
  end;



procedure install_exception_handlers;
  begin
    AddVectoredExceptionHandler(1,@syswin64_x86_64_exception_handler);
  end;
{$endif ndef SYSTEM_USE_WIN_SEH}

{$ifdef FPC_SECTION_THREADVARS}
function fpc_tls_add(addr: pointer): pointer; assembler; nostackframe;
  [public,alias: 'FPC_TLS_ADD']; compilerproc;
  asm
      sub   $56,%rsp                  { 32 spill area + 16 local vars + 8 misalignment }
  .seh_stackalloc 56
  .seh_endprologue
      lea   tls_data_start(%rip),%rax
      sub   %rax,%rcx
      cmpb  $0,IsLibrary(%rip)
      mov   _tls_index(%rip),%eax
      jnz   .L1
      mov   %gs:(88),%rdx
      add   (%rdx,%rax,8),%rcx
      mov   %rcx,%rax
      jmp   .L3
.L1:
      mov   %rcx,32(%rsp)
      call  GetLastError
      mov   %rax,40(%rsp)             { save LastError }
      mov   _tls_index(%rip),%ecx
      call  TlsGetValue
      test  %rax,%rax
      jnz   .L2
      { This can happen when a thread existed before DLL was loaded,
        or if DisableThreadLibraryCalls was called. }
      call  SysAllocateThreadVars
      mov   $0x1000000,%rcx
      call  InitThread
      mov   _tls_index(%rip),%ecx
      call  TlsGetValue
.L2:
      add   %rax,32(%rsp)
      mov   40(%rsp),%rcx
      call  SetLastError
      mov   32(%rsp),%rax
.L3:
      add   $56,%rsp
  end;
{$endif FPC_SECTION_THREADVARS}

function CheckInitialStkLen(stklen : SizeUInt) : SizeUInt;
  type
    tdosheader = packed record
       e_magic : word;
       e_cblp : word;
       e_cp : word;
       e_crlc : word;
       e_cparhdr : word;
       e_minalloc : word;
       e_maxalloc : word;
       e_ss : word;
       e_sp : word;
       e_csum : word;
       e_ip : word;
       e_cs : word;
       e_lfarlc : word;
       e_ovno : word;
       e_res : array[0..3] of word;
       e_oemid : word;
       e_oeminfo : word;
       e_res2 : array[0..9] of word;
       e_lfanew : longint;
    end;
    tpeheader = packed record
       PEMagic : longint;
       Machine : word;
       NumberOfSections : word;
       TimeDateStamp : longint;
       PointerToSymbolTable : longint;
       NumberOfSymbols : longint;
       SizeOfOptionalHeader : word;
       Characteristics : word;
       Magic : word;
       MajorLinkerVersion : byte;
       MinorLinkerVersion : byte;
       SizeOfCode : longint;
       SizeOfInitializedData : longint;
       SizeOfUninitializedData : longint;
       AddressOfEntryPoint : longint;
       BaseOfCode : longint;
{$ifdef win32}
       BaseOfData : longint;
{$endif win32}
       ImageBase : PtrInt;
       SectionAlignment : longint;
       FileAlignment : longint;
       MajorOperatingSystemVersion : word;
       MinorOperatingSystemVersion : word;
       MajorImageVersion : word;
       MinorImageVersion : word;
       MajorSubsystemVersion : word;
       MinorSubsystemVersion : word;
       Reserved1 : longint;
       SizeOfImage : longint;
       SizeOfHeaders : longint;
       CheckSum : longint;
       Subsystem : word;
       DllCharacteristics : word;
       SizeOfStackReserve : PtrInt;
       SizeOfStackCommit : PtrInt;
       SizeOfHeapReserve : PtrInt;
       SizeOfHeapCommit : PtrInt;
       LoaderFlags : longint;
       NumberOfRvaAndSizes : longint;
       DataDirectory : array[1..$80] of byte;
    end;
  begin
    result:=tpeheader((pointer(getmodulehandle(nil))+(tdosheader(pointer(getmodulehandle(nil))^).e_lfanew))^).SizeOfStackReserve;
  end;

initialization
  { pass dummy value }
  StackLength := CheckInitialStkLen($1000000);
  StackBottom := StackTop - StackLength;
  SetThreadStackGuaranteeTo(StackMargin);

  { get some helpful informations }
  GetStartupInfo(@startupinfo);
  { some misc Win32 stuff }
  if not IsLibrary then
    FPCSysInstance^:=getmodulehandle(nil);
  MainInstance:=FPCSysInstance^;
  cmdshow:=startupinfo.wshowwindow;
  { Setup heap and threading, these may be already initialized from TLS callback }
  if not Assigned(CurrentTM.BeginThread) then
  begin
    InitHeap;
    InitSystemThreads;
  end;
  SysInitExceptions;
  initunicodestringmanager;
  InitWin32Widestrings;
  SysInitStdIO;
  { Arguments }
  setup_arguments;
  InitSystemDynLibs;
  { Reset IO Error }
  InOutRes:=0;
  DispCallByIDProc:=@DoDispCallByIDError;

finalization
  WinFinalizeSystem;

end.
