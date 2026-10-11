procedure NxIOError;
begin
  InOutRes := NxDosError;
end;
procedure do_close(Handle: THandle);
begin
  if NxClose(Handle) <> 0 then
    NxIOError;
end;
procedure do_erase(P: PAnsiChar; Changeable: Boolean);
begin
  if NxUnlink(P) <> 0 then
    NxIOError;
end;
procedure do_rename(P1, P2: PAnsiChar; C1, C2: Boolean);
begin
  if NxRename(P1, P2) <> 0 then
    NxIOError;
end;
function do_write(Handle: THandle; Addr: Pointer; Len: LongInt): LongInt;
begin
  Result := NxWrite(Handle, Addr, Len);
  if Result < 0 then begin
    NxIOError;
    Result := 0;
  end;
end;
function do_read(Handle: THandle; Addr: Pointer; Len: LongInt): LongInt;
begin
  Result := NxRead(Handle, Addr, Len);
  if Result < 0 then begin
    NxIOError;
    Result := 0;
  end;
end;
function do_filepos(Handle: THandle): Int64;
begin
  Result := NxSeek(Handle, 0, 1);
  if Result < 0 then
    NxIOError;
end;
procedure do_seek(Handle: THandle; Pos: Int64);
begin
  if NxSeek(Handle, Pos, 0) < 0 then
    NxIOError;
end;
function do_seekend(Handle: THandle): Int64;
begin
  Result := NxSeek(Handle, 0, 2);
  if Result < 0 then
    NxIOError;
end;
function do_filesize(Handle: THandle): Int64;
var
  Stamp: Int64;
begin
  if NxFileInfo(nil, Handle, Result, Stamp) < 0 then begin
    NxIOError;
    Result := -1;
  end;
end;
procedure do_truncate(Handle: THandle; Pos: Int64);
begin
  if NxTruncate(Handle, Pos) <> 0 then
    NxIOError;
end;
procedure do_open(var F; P: PAnsiChar; Flags: LongInt; Changeable: Boolean);
var
  Creation: LongInt;
begin
  if (Flags and $10000) = 0 then
    case FileRec(F).Mode of
      fmInput, fmOutput, fmInOut: do_close(FileRec(F).Handle);
      fmClosed:;
    else
      InOutRes := 102;
      Exit;
    end;
  case Flags and 3 of
    0: FileRec(F).Mode := fmInput;
    1: FileRec(F).Mode := fmOutput;
    2: FileRec(F).Mode := fmInOut;
  end;
  if P^ = #0 then begin
    if FileRec(F).Mode = fmInput then
      FileRec(F).Handle := 0
    else
      FileRec(F).Handle := 1;
    Exit;
  end;
  Creation := 0;
  if (Flags and $1000) <> 0 then
    Creation := 1
  else if (Flags and $100) <> 0 then
    Creation := 2;
  FileRec(F).Handle := NxOpen(P, Flags and 3, Creation);
  if FileRec(F).Handle < 0 then begin
    FileRec(F).Mode := fmClosed;
    NxIOError;
  end;
end;
function do_isdevice(Handle: THandle): Boolean;
begin
  Result := NxIsatty(Handle) <> 0;
end;
