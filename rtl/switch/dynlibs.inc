{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2026 by the Free Pascal development team.

    Nintendo Switch static homebrew dynamic-library failure semantics.
    Applications can still query optional libraries through the
    ordinary DynLibs API and receive a normal load failure.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

function NxLoadLibraryA(const Name: RawByteString): TLibHandle;
begin
  Result:=NilHandle;
end;

function NxLoadLibraryU(const Name: UnicodeString): TLibHandle;
begin
  Result:=NilHandle;
end;

function NxGetProcAddress(Lib: TLibHandle; const ProcName: AnsiString): Pointer;
begin
  Result:=nil;
end;

function NxGetProcAddressOrdinal(Lib: TLibHandle; Ordinal: TOrdinalEntry): Pointer;
begin
  Result:=nil;
end;

function NxUnloadLibrary(Lib: TLibHandle): Boolean;
begin
  Result:=false;
end;

function NxGetLoadErrorStr: AnsiString;
begin
  Result:='Dynamic library loading is not supported on Nintendo Switch.';
end;

const
  NxDynLibsManager: TDynLibsManager = (
    LoadLibraryU: @NxLoadLibraryU;
    LoadLibraryA: @NxLoadLibraryA;
    GetProcAddress: @NxGetProcAddress;
    GetProcAddressOrdinal: @NxGetProcAddressOrdinal;
    UnloadLibrary: @NxUnloadLibrary;
    GetLoadErrorStr: @NxGetLoadErrorStr
  );

procedure InitDynLibs;
begin
  SetDynLibsManager(NxDynLibsManager);
end;
