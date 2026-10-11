{$define HAS_SYSOSFREE}
{$define FPC_SYSTEM_HAS_SYSOSREALLOC}
function SysOSAlloc(Size: PtrUInt): Pointer;
begin
  Result := NxMalloc(Size);
end;
procedure SysOSFree(P: Pointer; Size: PtrUInt);
begin
  NxFree(P);
end;
function SysOSRealloc(P: Pointer; OldSize, NewSize: PtrUInt): Pointer;
begin
  Result := NxRealloc(P, NewSize);
end;
