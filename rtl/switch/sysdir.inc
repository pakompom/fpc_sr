procedure do_mkdir(const S: RawByteString);
begin
  if NxMkdir(PAnsiChar(S), &777) <> 0 then
    NxIOError;
end;
procedure do_rmdir(const S: RawByteString);
begin
  if NxRmdir(PAnsiChar(S)) <> 0 then
    NxIOError;
end;
procedure do_chdir(const S: RawByteString);
begin
  if NxChdir(PAnsiChar(S)) <> 0 then
    NxIOError;
end;
procedure do_GetDir(DriveNr: Byte; var Dir: RawByteString);
var
  Buffer: array[0..MaxPathLen] of AnsiChar;
begin
  if NxGetcwd(@Buffer, SizeOf(Buffer)) = nil then
  begin
    NxIOError;
    Dir := '';
  end
  else
    Dir := StrPas(@Buffer);
end;
