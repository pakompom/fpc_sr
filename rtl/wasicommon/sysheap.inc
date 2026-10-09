{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2001 by Free Pascal development team

    This file implements all the base types and limits required
    for a minimal POSIX compliant subset required to port the compiler
    to a new OS.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}


{*****************************************************************************
                              Heap Management
*****************************************************************************}

const
  WasmMemoryPageSize=65536;

var
  InitialHeapBlockStart: Pointer;
  InitialHeapBlockEnd: Pointer;
{$ifdef FPC_WASM_THREADS}
  InitialHeapCriticalSection: TRtlCriticalSection;
  InitialHeapCriticalSectionInitialized: Boolean = false;
{$endif FPC_WASM_THREADS}

procedure SetInitialHeapBlockStart(p: Pointer);[Public, Alias : 'FPC_WASM_SETINITIALHEAPBLOCKSTART'];
begin
  InitialHeapBlockStart:=p;
end;

procedure InitInitialHeapBlock;
begin
  InitialHeapBlockEnd:=Pointer(PtrUInt(fpc_wasm32_memory_size)*WasmMemoryPageSize);
end;

{$ifdef FPC_WASM_HOST_ALLOCATOR}
{ A module sharing linear memory with C must obtain arena blocks from the
  same allocator. Independently growing a second heap can overwrite C data.
  Unlike raw WebAssembly memory, this allocator can free and resize blocks.
  Advertise that capability to heap.inc: otherwise it permanently retains
  released Pascal arenas instead of making them reusable by C and pthreads. }
{$define HAS_SYSOSFREE}
{$define FPC_SYSTEM_HAS_SYSOSREALLOC}
function HostMalloc(size: ptruint): pointer; cdecl; external name 'malloc';
procedure HostFree(p: pointer); cdecl; external name 'free';
function HostRealloc(p: pointer; size: ptruint): pointer; cdecl; external name 'realloc';

function SysOSAlloc(size: ptruint): pointer;
begin
  Result:=HostMalloc(size);
end;

procedure SysOSFree(p: pointer; size: ptruint);
begin
  HostFree(p);
end;

function SysOSRealloc(p: pointer; oldsize, newsize: ptruint): pointer;
begin
  Result:=HostRealloc(p,newsize);
end;
{$else FPC_WASM_HOST_ALLOCATOR}
function SysOSAlloc(size: ptruint): pointer;
const
  err = high(longword);
var
  res: ptruint;
  avail: SizeUInt;
  grow_pages: LongInt;
begin
{$ifdef FPC_WASM_THREADS}
  if InitialHeapCriticalSectionInitialized then
    EnterCriticalSection(InitialHeapCriticalSection);
{$endif FPC_WASM_THREADS}
  avail:=PtrUInt(InitialHeapBlockEnd)-PtrUInt(InitialHeapBlockStart);
  if avail>=size then
    begin
      SysOSAlloc:=InitialHeapBlockStart;
      Inc(InitialHeapBlockStart,size);
    end
  else
    begin
      grow_pages:=(size-avail+WasmMemoryPageSize-1) div WasmMemoryPageSize;
      res:=fpc_wasm32_memory_grow(grow_pages);
      if res<>err then
        begin
          SysOSAlloc:=InitialHeapBlockStart;//pointer(res*WasmMemoryPageSize)
          Inc(InitialHeapBlockStart,size);
          Inc(InitialHeapBlockEnd,grow_pages*WasmMemoryPageSize);
        end
      else
        SysOSAlloc:=nil;
      if assigned(WasmGrowMemoryCallback) then
        WasmGrowMemoryCallback(grow_pages);
    end;
{$ifdef FPC_WASM_THREADS}
  if InitialHeapCriticalSectionInitialized then
    LeaveCriticalSection(InitialHeapCriticalSection);
{$endif FPC_WASM_THREADS}
end;

procedure SysOSFree(p: pointer; size: ptruint);
begin
end;
{$endif FPC_WASM_HOST_ALLOCATOR}
