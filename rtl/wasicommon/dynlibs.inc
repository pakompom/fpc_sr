{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2026 by the Free Pascal development team.

    WASI dynamic-library failure semantics. WASI Preview 1 has no dynamic
    loader; applications can still query optional libraries through the
    ordinary DynLibs API and receive a normal load failure.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

function WasiLoadLibraryA(const Name: RawByteString): TLibHandle;
begin
  Result:=NilHandle;
end;

function WasiLoadLibraryU(const Name: UnicodeString): TLibHandle;
begin
  Result:=NilHandle;
end;

function WasiGetProcAddress(Lib: TLibHandle; const ProcName: AnsiString): Pointer;
begin
  Result:=nil;
end;

function WasiGetProcAddressOrdinal(Lib: TLibHandle; Ordinal: TOrdinalEntry): Pointer;
begin
  Result:=nil;
end;

function WasiUnloadLibrary(Lib: TLibHandle): Boolean;
begin
  Result:=false;
end;

function WasiGetLoadErrorStr: AnsiString;
begin
  Result:='Dynamic library loading is not supported on WASI.';
end;

const
  WasiDynLibsManager: TDynLibsManager = (
    LoadLibraryU: @WasiLoadLibraryU;
    LoadLibraryA: @WasiLoadLibraryA;
    GetProcAddress: @WasiGetProcAddress;
    GetProcAddressOrdinal: @WasiGetProcAddressOrdinal;
    UnloadLibrary: @WasiUnloadLibrary;
    GetLoadErrorStr: @WasiGetLoadErrorStr
  );

procedure InitDynLibs;
begin
  SetDynLibsManager(WasiDynLibsManager);
end;
