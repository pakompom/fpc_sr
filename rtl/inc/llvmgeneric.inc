{
    This file is part of the Free Pascal run time library.

    LLVM memory primitives for hosted targets. See COPYING.FPC for details.
}

{ LLVM can lower a large or variable-sized operation to a libc call. Record
  that dependency even when FPC_USE_LIBC is off, and let libc provide those
  symbols rather than defining recursive intrinsic-based fallbacks here. }
{$linklib c}

{$if not defined(FPC_SYSTEM_HAS_MOVE) and not defined(USE_CPU_MOVE)}
{$define FPC_SYSTEM_HAS_MOVE}
{ LLVM 7.0+ specifies alignment on pointer arguments. Leaving it unspecified
  permits byte-aligned accesses. Move permits overlap, so use memmove. }
procedure llvm_move64(dest, source: pointer; count: qword; isvolatile: LLVMBool1);
  external name 'llvm.memmove.p0i8.p0i8.i64';

procedure Move(const source;var dest;count:SizeInt);[public, alias: 'FPC_MOVE'];{$ifdef SYSTEMINLINE}inline;{$endif}
begin
  if count<=0 then
    exit;
  llvm_move64(@dest,@source,qword(count),False);
end;
{$endif}

{$ifndef FPC_SYSTEM_HAS_FILLCHAR}
{$define FPC_SYSTEM_HAS_FILLCHAR}
procedure llvm_fill64(dest: pointer; value: byte; count: qword; isvolatile: LLVMBool1);
  external name 'llvm.memset.p0i8.i64';

procedure FillChar(var x;count:SizeInt;value:byte);{$ifdef SYSTEMINLINE}inline;{$endif}
begin
  { Keep the zero-length call, as in the libc implementation, so the compiler
    considers x initialized. Negative Pascal counts must not become unsigned
    memory lengths. }
  if count<0 then
    count:=0;
  llvm_fill64(@x,value,qword(count),False);
end;
{$endif FPC_SYSTEM_HAS_FILLCHAR}
