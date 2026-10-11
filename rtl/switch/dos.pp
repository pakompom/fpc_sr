{ BP-compatible DOS services over Switch SysUtils. See COPYING.FPC. }
unit Dos;
{$MODE objfpc}
interface
type
  SearchRec = record
    AnchorPtr: Pointer;
    Attr: Byte;
    Time, Size: LongInt;
    Name: string[255];
  end;
{$i dosh.inc}
implementation
uses
  SysUtils;
{$i nxlibc.inc}
{$DEFINE HAS_GETMSCOUNT}
{$i pathdefs.inc}
{$i dos.inc}
function DosVersion: Word;
begin
  Result := 0;
end;
procedure GetDate(var Year, Month, MDay, WDay: Word);
var
  T: TSystemTime;
begin
  GetLocalTime(T);
  Year := T.Year;
  Month := T.Month;
  MDay := T.Day;
  WDay := T.DayOfWeek;
end;
procedure GetTime(var Hour, Minute, Second, Sec100: Word);
var
  T: TSystemTime;
begin
  GetLocalTime(T);
  Hour := T.Hour;
  Minute := T.Minute;
  Second := T.Second;
  Sec100 := T.Millisecond div 10;
end;
procedure SetDate(Year, Month, Day: Word);
begin
  DosError := 5;
end;
procedure SetTime(Hour, Minute, Second, Sec100: Word);
begin
  DosError := 5;
end;
function GetMsCount: Int64;
begin
  Result := NxTicks;
end;
procedure Exec(const Path: PathStr; const ComLine: ComStr);
begin
  DosError := 5;
end;
function DiskFree(Drive: Byte): Int64;
begin
  Result := SysUtils.DiskFree(Drive);
end;
function DiskSize(Drive: Byte): Int64;
begin
  Result := SysUtils.DiskSize(Drive);
end;
type
  PSearch = ^TSearchRec;
procedure CopySearch(var F: SearchRec);
var
  D: DateTime;
  T: TDateTime;
  MS: Word;
begin
  with PSearch(F.AnchorPtr)^ do begin
    F.Attr := Attr;
    F.Size := Size;
    F.Name := Name;
    T := FileDateToDateTime(Time);
  end;
  DecodeDate(T, D.Year, D.Month, D.Day);
  DecodeTime(T, D.Hour, D.Min, D.Sec, MS);
  PackTime(D, F.Time);
end;
procedure FindFirst(const Path: PathStr; Attr: Word; var F: SearchRec);
var
  P: PSearch;
begin
  New(P);
  F.AnchorPtr := P;
  if SysUtils.FindFirst(Path, Attr, P^) <> 0 then begin
    Dispose(P);
    F.AnchorPtr := nil;
    DosError := 18;
  end
  else begin
    CopySearch(F);
    DosError := 0;
  end;
end;
procedure FindNext(var F: SearchRec);
begin
  if (F.AnchorPtr = nil) or (SysUtils.FindNext(PSearch(F.AnchorPtr)^) <> 0) then
    DosError := 18
  else begin
    CopySearch(F);
    DosError := 0;
  end;
end;
procedure FindClose(var F: SearchRec);
begin
  if F.AnchorPtr <> nil then begin
    SysUtils.FindClose(PSearch(F.AnchorPtr)^);
    Dispose(PSearch(F.AnchorPtr));
  end;
  F.AnchorPtr := nil;
  DosError := 0;
end;
function FSearch(Path: PathStr; DirList: string): PathStr;
begin
  Result := SysUtils.FileSearch(Path, DirList);
end;
procedure GetFTime(var F; var Time: LongInt);
var
  T: TDateTime;
  D: DateTime;
  MS: Word;
begin
  if FileGetDate(FileRec(F).Handle, T) then begin
    DecodeDate(T, D.Year, D.Month, D.Day);
    DecodeTime(T, D.Hour, D.Min, D.Sec, MS);
    PackTime(D, Time);
    DosError := 0;
  end
  else
    DosError := NxDosError;
end;
procedure SetFTime(var F; Time: LongInt);
var
  D: DateTime;
begin
  UnpackTime(Time, D);
  if FileSetDate(
          FileRec(F).Handle,
          DateTimeToFileDate(EncodeDate(D.Year, D.Month, D.Day) + EncodeTime(D.Hour, D.Min, D.Sec, 0)))
      = 0 then
    DosError := 0
  else
    DosError := NxDosError;
end;
procedure GetFAttr(var F; var Attr: Word);
var
  Value: LongInt;
begin
  Value := FileGetAttr(StrPas(@FileRec(F).Name[0]));
  if Value < 0 then
    DosError := NxDosError
  else begin
    Attr := Value;
    DosError := 0;
  end;
end;
procedure SetFAttr(var F; Attr: Word);
begin
  DosError := 5;
end;
function EnvCount: LongInt;
begin
  Result := GetEnvironmentVariableCount;
end;
function EnvStr(Index: LongInt): string;
begin
  Result := GetEnvironmentString(Index);
end;
function GetEnv(EnvVar: string): string;
begin
  Result := GetEnvironmentVariable(EnvVar);
end;
end.
