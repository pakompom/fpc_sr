{ %target=linux,freebsd,openbsd,netbsd,darwin,solaris }
{$mode objfpc}{$H+}

uses SysUtils, BaseUnix;

procedure Check(Value: Boolean; Code: Integer);
begin
  if not Value then Halt(Code);
end;

procedure CheckFailure(const Path: RawByteString; ArrayArguments: Boolean;
  ExpectedCode: Integer);
begin
  try
    if ArrayArguments then ExecuteProcess(Path,[])
    else ExecuteProcess(Path,'');
  except
    on E: EOSError do
      begin
        Check(E.ErrorCode=ExpectedCode,20);
        Exit;
      end;
  end;
  Halt(21);
end;

var
  Executable, TrueCommand: RawByteString;
begin
  if ParamCount>0 then
    begin
      if ParamStr(1)='arguments' then
        begin
          Check(ParamCount=5,1);
          Check(ParamStr(2)='two words',2);
          Check(ParamStr(3)='',3);
          Check(ParamStr(4)='a"b''c',4);
          Check(ParamStr(5)=GetEnvironmentVariable('PATH'),5);
          Halt(37);
        end;
      if ParamStr(1)='quoted' then
        begin
          Check(ParamCount=3,6);
          Check(ParamStr(2)='two words',7);
          Check(ParamStr(3)='',8);
          Halt(38);
        end;
      if ParamStr(1)='exit127' then Halt(127);
      if ParamStr(1)='signal' then
        begin
          fpKill(fpGetPid,SIGTERM);
          Halt(9);
        end;
      Halt(10);
    end;

  Executable:=ExpandFileName(ParamStr(0));
  Check(ExecuteProcess(Executable,
    ['arguments','two words','','a"b''c',GetEnvironmentVariable('PATH')])=37,11);
  Check(ExecuteProcess(Executable,'quoted "two words" ""')=38,12);
  TrueCommand:='/usr/bin/true';
  if not FileExists(TrueCommand) then TrueCommand:='/bin/true';
  Check(ExecuteProcess(TrueCommand,'')=0,13);
  Check(ExecuteProcess(TrueCommand,[])=0,14);

  CheckFailure(Executable+'.does-not-exist',False,127);
  CheckFailure(Executable+'.does-not-exist',True,127);
  { A directory exists but cannot be executed. }
  CheckFailure(GetCurrentDir,False,127);
  CheckFailure(GetCurrentDir,True,127);
  try
    ExecuteProcess(Executable,['exit127']);
    Halt(15);
  except
    on E: EOSError do Check(E.ErrorCode=127,16);
  end;
  try
    ExecuteProcess(Executable,'signal');
    Halt(17);
  except
    on E: EOSError do Check(E.ErrorCode<0,18);
  end;
end.
