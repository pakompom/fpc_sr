{ Nintendo Switch SysUtils. See COPYING.FPC for the RTL license. }
unit SysUtils;
{$MODE objfpc}
{$H+}
{$MODESWITCH out}
{$MODESWITCH typehelpers}
{$MODESWITCH advancedrecords}
interface
{$DEFINE HAS_OSERROR}
{$DEFINE HAS_SLEEP}
{$DEFINE HAS_GETTICKCOUNT64}
{$DEFINE HAS_LOCALTIMEZONEOFFSET}
{$DEFINE OS_FILESETDATEBYNAME}
{$DEFINE SYSUTILS_HAS_ANSISTR_FILEUTIL_IMPL}
{$DEFINE SYSUTILS_HAS_ANSISTR_ENVVAR_IMPL}
{$i sysutilh.inc}
implementation
uses
  SysConst;
{$i nxlibc.inc}
{$i pathdefs.inc}
function EpochFromParts(Local: LongInt; Y, M, D, H, N, S: Word): Int64; cdecl; external name 'fpc_nx_epoch_from_parts';
procedure EpochToParts(
    Local: LongInt;
    Epoch: Int64;
    out Y, M, D, H, N, S: Word
); cdecl; external name 'fpc_nx_epoch_to_parts';
function LocalToEpoch(Y, M, D, H, N, S: Word): Int64;
begin
  Result := EpochFromParts(1, Y, M, D, H, N, S);
end;
function UniversalToEpoch(Y, M, D, H, N, S: Word): Int64;
begin
  Result := EpochFromParts(0, Y, M, D, H, N, S);
end;
procedure EpochToLocal(Epoch: Int64; out Y, M, D, H, N, S: Word);
begin
  EpochToParts(1, Epoch, Y, M, D, H, N, S);
end;
procedure EpochToUniversal(Epoch: Int64; out Y, M, D, H, N, S: Word);
begin
  EpochToParts(0, Epoch, Y, M, D, H, N, S);
end;
{$i sysutils.inc}
function NativeFindOpen(Path: PAnsiChar): Pointer; cdecl; external name 'fpc_nx_findopen';
function NativeFindNext(
    Handle: Pointer;
    Name: PAnsiChar;
    Capacity: SizeUInt;
    out Size, Stamp: Int64
): LongInt; cdecl; external name 'fpc_nx_findnext';
procedure NativeFindClose(Handle: Pointer); cdecl; external name 'fpc_nx_findclose';
function NativeTime(Local: LongInt; var Value: TSystemTime): LongInt; cdecl; external name 'fpc_nx_systemtime';
function NativeTimeOffset(Epoch: Int64; out Offset, IsDST: LongInt): LongInt; cdecl; external name 'fpc_nx_timeoffset';
function NativeError(Code: LongInt): PAnsiChar; cdecl; external name 'strerror';
function NativeGetEnv(Name: PAnsiChar): PAnsiChar; cdecl; external name 'getenv';
function NativeEnvCount: LongInt; cdecl; external name 'fpc_nx_envcount';
function NativeEnvStr(Index: LongInt): PAnsiChar; cdecl; external name 'fpc_nx_envstr';
function NativeSetDate(Path: PAnsiChar; FD: LongInt; Stamp: Int64): LongInt; cdecl; external name 'fpc_nx_setdate';
function NativeDiskSize(FreeSpace: LongInt): Int64; cdecl; external name 'fpc_nx_diskspace';
function FileOpen(const FileName: RawByteString; Mode: Integer): THandle;
begin
  Result := NxOpen(PAnsiChar(FileName), Mode and 3, 0);
end;
function FileCreate(const FileName: RawByteString): THandle;
begin
  Result := NxOpen(PAnsiChar(FileName), 2, 1);
end;
function FileCreate(const FileName: RawByteString; Rights: Integer): THandle;
begin
  Result := FileCreate(FileName);
end;
function FileCreate(const FileName: RawByteString; ShareMode: Integer; Rights: Integer): THandle;
begin
  Result := FileCreate(FileName);
end;
function FileRead(Handle: THandle; out Buffer; Count: LongInt): LongInt;
begin
  Result := NxRead(Handle, @Buffer, Count);
end;
function FileWrite(Handle: THandle; const Buffer; Count: LongInt): LongInt;
begin
  Result := NxWrite(Handle, @Buffer, Count);
end;
function FileSeek(Handle: THandle; FOffset, Origin: LongInt): LongInt;
begin
  Result := NxSeek(Handle, FOffset, Origin);
end;
function FileSeek(Handle: THandle; FOffset: Int64; Origin: LongInt): Int64;
begin
  Result := NxSeek(Handle, FOffset, Origin);
end;
procedure FileClose(Handle: THandle);
begin
  NxClose(Handle);
end;
function FileTruncate(Handle: THandle; Size: Int64): Boolean;
begin
  Result := NxTruncate(Handle, Size) = 0;
end;
function FileGetDate(Handle: THandle): Int64;
var
  Size: Int64;
begin
  if NxFileInfo(nil, Handle, Size, Result) < 0 then
    Result := -1;
end;
function FileSetDate(Handle: THandle; Age: Int64): LongInt;
begin
  Result := NativeSetDate(nil, Handle, Age);
  if Result < 0 then
    Result := NxErrno;
end;
function FileSetDate(const FileName: RawByteString; Age: Int64): LongInt;
begin
  Result := NativeSetDate(PAnsiChar(FileName), -1, Age);
  if Result < 0 then
    Result := NxErrno;
end;
function FileAge(const FileName: RawByteString): Int64;
var
  Size: Int64;
begin
  if NxFileInfo(PAnsiChar(FileName), -1, Size, Result) < 0 then
    Result := -1;
end;
function DeleteFile(const FileName: RawByteString): Boolean;
begin
  Result := NxUnlink(PAnsiChar(FileName)) = 0;
end;
function RenameFile(const OldName, NewName: RawByteString): Boolean;
begin
  Result := NxRename(PAnsiChar(OldName), PAnsiChar(NewName)) = 0;
end;
function FileGetAttr(const FileName: RawByteString): LongInt;
var
  Size, Stamp: Int64;
begin
  Result := NxFileInfo(PAnsiChar(FileName), -1, Size, Stamp);
end;
function FileSetAttr(const FileName: RawByteString; Attr: LongInt): LongInt;
begin
  { libnx devoptab has no portable DOS attribute setter. }
  Result := NxUnsupported;
end;
function FileExists(const FileName: RawByteString; FollowLink: Boolean): Boolean;
var
  Attr: LongInt;
begin
  Attr := FileGetAttr(FileName);
  Result := (Attr >= 0) and ((Attr and faDirectory) = 0);
end;
function DirectoryExists(const Directory: RawByteString; FollowLink: Boolean): Boolean;
var
  Attr: LongInt;
begin
  Attr := FileGetAttr(Directory);
  Result := (Attr >= 0) and ((Attr and faDirectory) <> 0);
end;
function FileGetSymLinkTarget(const FileName: RawByteString; out SymLinkRec: TRawbyteSymLinkRec): Boolean;
begin
  Result := false;
end;
function InternalFindNext(var Rslt: TAbstractSearchRec; var Name: RawByteString): LongInt;
var
  Buffer: array[0..MaxPathLen] of AnsiChar;
  Attr: LongInt;
begin
  repeat
    Attr := NativeFindNext(Pointer(Rslt.FindHandle), @Buffer, SizeOf(Buffer), Rslt.Size, Rslt.Time);
    if Attr < 0 then
      Exit(-1);
  until (Attr and Rslt.ExcludeAttr) = 0;
  Rslt.Attr := Attr;
  Name := StrPas(@Buffer);
  Result := 0;
end;
function InternalFindFirst(
    const Path: RawByteString;
    Attr: LongInt;
    out Rslt: TAbstractSearchRec;
    var Name: RawByteString
): LongInt;
begin
  Rslt.FindHandle := THandle(NativeFindOpen(PAnsiChar(Path)));
  if Rslt.FindHandle = 0 then
    Exit(-1);
  Rslt.ExcludeAttr := (not Attr) and (faHidden or faSysFile or faDirectory or faVolumeId);
  Result := InternalFindNext(Rslt, Name);
  if Result <> 0 then begin
    NativeFindClose(Pointer(Rslt.FindHandle));
    Rslt.FindHandle := 0;
  end;
end;
procedure InternalFindClose(var Handle: THandle);
begin
  if Handle <> 0 then
    NativeFindClose(Pointer(Handle));
  Handle := 0;
end;
procedure AddDisk(const Path: string);
begin
end;
function DiskFree(Drive: Byte): Int64;
begin
  Result := NativeDiskSize(1);
end;
function DiskSize(Drive: Byte): Int64;
begin
  Result := NativeDiskSize(0);
end;
procedure SysBeep;
begin
end;
procedure Sleep(Milliseconds: Cardinal);
begin
  NxSleep(Milliseconds);
end;
function GetTickCount64: QWord;
begin
  Result := NxTicks;
end;
procedure GetLocalTime(var SystemTime: TSystemTime);
begin
  NativeTime(1, SystemTime);
end;
function GetUniversalTime(var SystemTime: TSystemTime): Boolean;
begin
  Result := NativeTime(0, SystemTime) = 0;
end;
function GetLocalTimeOffset(
    const DateTime: TDateTime;
    const InputIsUTC: Boolean;
    out Offset: Integer;
    out IsDST: Boolean
): Boolean;
var
  Y, M, D, H, N, S, MS: Word;
  Epoch: Int64;
  DST: LongInt;
begin
  DecodeDate(DateTime, Y, M, D);
  DecodeTime(DateTime, H, N, S, MS);
  Epoch := EpochFromParts(Ord(not InputIsUTC), Y, M, D, H, N, S);
  Result := NativeTimeOffset(Epoch, Offset, DST) = 0;
  IsDST := DST > 0;
end;
function GetLocalTimeOffset: Integer;
var
  DST: Boolean;
begin
  if not GetLocalTimeOffset(Now, false, Result, DST) then
    Result := 0;
end;
function SysErrorMessage(ErrorCode: Integer): string;
begin
  Result := StrPas(NativeError(ErrorCode));
end;
function GetLastOSError: Integer;
begin
  Result := NxErrno;
end;
procedure SetLastOSError(ErrorCode: LongInt);
begin
  NxSetErrno(ErrorCode);
end;
function GetEnvironmentVariable(const EnvVar: string): string;
var
  P: PAnsiChar;
begin
  P := NativeGetEnv(PAnsiChar(EnvVar));
  if P = nil then
    Result := ''
  else
    Result := StrPas(P);
end;
function GetEnvironmentVariableCount: Integer;
begin
  Result := NativeEnvCount;
end;
function GetEnvironmentString(Index: Integer): string;
var
  P: PAnsiChar;
begin
  P := NativeEnvStr(Index);
  if P = nil then
    Result := ''
  else
    Result := StrPas(P);
end;
function ExecuteProcess(const Path, ComLine: RawByteString; Flags: TExecuteFlags = []): Integer;
begin
  Result := NxUnsupported;
  RaiseLastOSError;
end;
function ExecuteProcess(
    const Path: RawByteString;
    const ComLine: array of RawByteString;
    Flags: TExecuteFlags = []
): Integer;
begin
  Result := NxUnsupported;
  RaiseLastOSError;
end;
function ExecuteProcess(const Path, ComLine: UnicodeString; Flags: TExecuteFlags = []): Integer;
begin
  Result := NxUnsupported;
  RaiseLastOSError;
end;
function ExecuteProcess(
    const Path: UnicodeString;
    const ComLine: array of UnicodeString;
    Flags: TExecuteFlags = []
): Integer;
begin
  Result := NxUnsupported;
  RaiseLastOSError;
end;
procedure InitInternational;
var
  I: Integer;
begin
  InitInternationalGeneric;
  for I := 0 to 255 do begin
    UpperCaseTable[I] := AnsiChar(I);
    LowerCaseTable[I] := AnsiChar(I);
  end;
  for I := Ord('a') to Ord('z') do
    UpperCaseTable[I] := AnsiChar(I - 32);
  for I := Ord('A') to Ord('Z') do
    LowerCaseTable[I] := AnsiChar(I + 32);
  Move(CPISO88591UCT, UpperCaseTable[192], SizeOf(CPISO88591UCT));
  Move(CPISO88591LCT, LowerCaseTable[192], SizeOf(CPISO88591LCT));
end;
initialization
  InitExceptions;
  InitInternational;
  OnBeep := @SysBeep;
finalization
  FreeTerminateProcs;
  DoneExceptions;
end.
