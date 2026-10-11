{ Fixed-width bridge types; C owns SDK-dependent stat, DIR and time layouts. }
function NxErrno: LongInt; cdecl; external name 'fpc_nx_errno';
procedure NxSetErrno(Value: LongInt); cdecl; external name 'fpc_nx_seterrno';
function NxDosError: Word; cdecl; external name 'fpc_nx_doserror';
function NxUnsupported: LongInt; cdecl; external name 'fpc_nx_unsupported';
function NxOpen(Path: PAnsiChar; Mode, CreateMode: LongInt): LongInt; cdecl; external name 'fpc_nx_open';
function NxClose(FD: LongInt): LongInt; cdecl; external name 'close';
function NxRead(FD: LongInt; Buffer: Pointer; Count: SizeUInt): SizeInt; cdecl; external name 'read';
function NxWrite(FD: LongInt; Buffer: Pointer; Count: SizeUInt): SizeInt; cdecl; external name 'write';
function NxSeek(FD: LongInt; Offset: Int64; Origin: LongInt): Int64; cdecl; external name 'lseek';
function NxTruncate(FD: LongInt; Size: Int64): LongInt; cdecl; external name 'ftruncate';
function NxUnlink(Path: PAnsiChar): LongInt; cdecl; external name 'unlink';
function NxRename(OldName, NewName: PAnsiChar): LongInt; cdecl; external name 'rename';
function NxMkdir(Path: PAnsiChar; Mode: LongInt): LongInt; cdecl; external name 'mkdir';
function NxRmdir(Path: PAnsiChar): LongInt; cdecl; external name 'rmdir';
function NxChdir(Path: PAnsiChar): LongInt; cdecl; external name 'chdir';
function NxGetcwd(Buffer: PAnsiChar; Size: SizeUInt): PAnsiChar; cdecl; external name 'getcwd';
function NxIsatty(FD: LongInt): LongInt; cdecl; external name 'isatty';
function NxFileInfo(
    Path: PAnsiChar;
    FD: LongInt;
    out Size, Stamp: Int64
): LongInt; cdecl; external name 'fpc_nx_fileinfo';
function NxTicks: QWord; cdecl; external name 'fpc_nx_ticks';
procedure NxSleep(Milliseconds: Cardinal); cdecl; external name 'fpc_nx_sleep';
function NxMalloc(Size: SizeUInt): Pointer; cdecl; external name 'malloc';
function NxCalloc(Count, Size: SizeUInt): Pointer; cdecl; external name 'calloc';
procedure NxFree(P: Pointer); cdecl; external name 'free';
function NxRealloc(P: Pointer; Size: SizeUInt): Pointer; cdecl; external name 'realloc';
