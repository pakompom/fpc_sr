{ Nintendo Switch ELF linking through the devkitA64 GCC driver. The driver
  supplies libnx startup objects, newlib, libgcc unwinding and switch.specs.
  -Cn retains the response file for applications with a custom C entry point. }
unit t_switch;
{$i fpcdefs.inc}
interface
uses link,import;
type
  TImportLibSwitch = class(TImportLib)
    procedure generatelib; override;
  end;
  TLinkerSwitch = class(TExternalLinker)
    procedure SetDefaultInfo; override;
    function MakeExecutable: boolean; override;
  end;
implementation
uses sysutils,cutils,cfileutl,cclasses,cscript,export,expunix,ogbase,globals,globtype,systems,fmodule,i_switch;
procedure TImportLibSwitch.generatelib;
var
  i: LongInt;
  lib: TImportLibrary;
begin
  for i:=0 to current_module.ImportLibraryList.Count-1 do
    begin
      lib:=TImportLibrary(current_module.ImportLibraryList[i]);
      current_module.linkothersharedlibs.add(lib.Name,link_always);
    end;
end;
procedure TLinkerSwitch.SetDefaultInfo;
begin
  Info.ExeCmd[1]:='aarch64-none-elf-gcc $OPT @$RES -o $EXE';
end;
function TLinkerSwitch.MakeExecutable: boolean;
var
  response: TLinkRes;
  path: TCmdStrListItem;
  binstr,cmdstr,sdk: TCmdStr;
begin
  sdk:=GetEnvironmentVariable('DEVKITPRO');
  if sdk='' then
    sdk:='/opt/devkitpro';
  sdk:=FixPath(sdk,false);
  response:=TLinkRes.Create(outputexedir+Info.ResName,true);
  response.Add('-specs='+maybequoted(sdk+'libnx/switch.specs'));
  response.Add('-fPIE -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft');
  response.Add('-L'+maybequoted(sdk+'libnx/lib'));
  response.Add('-L'+maybequoted(sdk+'portlibs/switch/lib'));
  path:=TCmdStrListItem(LibrarySearchPath.First);
  while assigned(path) do
    begin
      response.Add('-L'+maybequoted(path.Str));
      path:=TCmdStrListItem(path.Next);
    end;
  while not ObjectFiles.Empty do
    response.AddFileName(maybequoted(ObjectFiles.GetFirst));
  response.Add('-Wl,--start-group');
  while not StaticLibFiles.Empty do
    response.AddFileName(maybequoted(StaticLibFiles.GetFirst));
  while not SharedLibFiles.Empty do
    response.Add('-l'+SharedLibFiles.GetFirst);
  response.Add('-lnx -lm -lc -lgcc -Wl,--end-group');
  response.WriteToDisk;
  response.Free;
  SplitBinCmd(Info.ExeCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$OPT',Info.ExtraOptions);
  Replace(cmdstr,'$RES',maybequoted(outputexedir+Info.ResName));
  Replace(cmdstr,'$EXE',maybequoted(current_module.exefilename));
  binstr:=FindUtil(sdk+'devkitA64/bin/'+binstr);
{$ifdef unix}
  { switch.specs resolves its linker script through GCC's environment. Use
    env for both immediate linking and the command recorded by -Cn. }
  cmdstr:=maybequoted('DEVKITPRO='+ExcludeTrailingPathDelimiter(sdk))+' '+maybequoted(binstr)+' '+cmdstr;
  binstr:=FindUtil('env');
{$endif unix}
  Result:=DoExec(binstr,cmdstr,true,false);
  if Result and not(cs_link_nolink in current_settings.globalswitches) then
    DeleteFile(outputexedir+Info.ResName);
end;
initialization
  RegisterLinker(ld_switch,TLinkerSwitch);
  RegisterImport(system_aarch64_switch,TImportLibSwitch);
  RegisterExport(system_aarch64_switch,TExportLibUnix);
  RegisterTarget(system_aarch64_switch_info);
end.
