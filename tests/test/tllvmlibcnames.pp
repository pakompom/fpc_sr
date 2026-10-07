{ %TARGET=darwin }
{ %CPU=aarch64,x86_64 }
{ %OPT=-O2 }
program tllvmlibcnames;

{$mode objfpc}
{$ifdef CPUX86_64}{$asmmode att}{$endif}

procedure LibCopy(const Source; var Destination; Count: SizeUInt); cdecl;
  external 'c' name 'bcopy';
function LibLength(Value: PAnsiChar): SizeUInt; cdecl;
  external 'c' name 'strlen';

var
  CData: LongInt; public name '_llvm_name_data';
  CDataAlias: LongInt; external name '_llvm_name_data';
  RawData: LongInt; public name 'raw_name_data';
  RawDataAlias: LongInt; external name 'raw_name_data';

function CFunction: LongInt; public name '_llvm_name_function';
begin
  Result := CData;
end;

function CFunctionAlias: LongInt; cdecl; external name 'llvm_name_function';

function RawFunction: LongInt; public name 'raw_name_function';
begin
  Result := RawData;
end;

function RawFunctionAlias: LongInt; external name 'raw_name_function';

{ Removing the underscore must not turn this exact symbol into an intrinsic. }
function ReservedName: LongInt; public name '_llvm.not_an_intrinsic';
begin
  Result := 7;
end;

function ReservedAlias: LongInt; external name '_llvm.not_an_intrinsic';

function ThroughAsm: LongInt; assembler; nostackframe;
asm
{$ifdef CPUAARCH64}
  stp x29,x30,[sp,#-16]!
  bl CFunctionAlias
  ldp x29,x30,[sp],#16
{$else}
  subq $8,%rsp
  call CFunctionAlias
  addq $8,%rsp
{$endif}
end;

function CopyWord(Value: LongWord): LongWord;
begin
  LibCopy(Value, Result, SizeOf(Result));
end;

begin
  CDataAlias := 31;
  RawDataAlias := 11;
  if (CFunctionAlias <> 31) or (RawFunctionAlias <> 11) or
     (ReservedAlias <> 7) or (ThroughAsm <> 31) then
    Halt(1);
  if (CopyWord($12345678) <> $12345678) or
     (LibLength('llvm') <> 4) then
    Halt(2);
  WriteLn('ok');
end.
