{ Hardware PC24 arithmetic for finite binary32 results.
  Double operands (including exact Int32 loads) are never narrowed before the
  operation. Only a binary32 midpoint needs the error-free residual; changing
  the Double approximation by one ulp then makes conversion round correctly.
  The mask includes binary32 subnormal midpoints. This is intentionally not
  an implementation of x87's extended exponent range or exception state.
  Actual native Extended operands use separate x87 routines below. }
{$ifdef FPC_HAS_PC24_HELPERS}
{$push}
{$optimization nofastmath}
{$Q-}{$R-}

type
  TPC24DoubleBits = record
    case Boolean of
      False: (value: Double);
      True: (bits: QWord);
  end;

{$ifdef CPULLVM}
{ LLVM lowers the intrinsic to an instruction or an exact library operation,
  including on baseline x86-64 processors without the FMA instruction set. }
function pc24_fma(a,b,c: Double): Double; inline;
begin
  pc24_fma:=FMADouble(a,b,c);
end;
{$else CPULLVM}
{$ifdef CPUAARCH64}
{ Also supported by the 3.2 bootstrap compiler. }
function pc24_fma(a,b,c: Double): Double; assembler; nostackframe;
asm
  fmadd d0,d0,d1,d2
end;
{$else CPUAARCH64}
{ The native bootstrap compiler may not support an FMA intrinsic for its
  selected CPU. libc fma provides the required single rounding nevertheless. }
function pc24_fma(a,b,c: Double): Double; cdecl;
  external {$ifdef DARWIN}'c'{$else}'m'{$endif} name 'fma';
{$endif CPUAARCH64}
{$endif CPULLVM}

function fpc_pc24_midpoint(v: Double): Boolean; inline;
var
  u: TPC24DoubleBits;
  e, discarded: LongInt;
  significand, mask: QWord;
begin
  u.value:=v;
  e:=(u.bits shr 52) and $7ff;
  { Most operations are normal binary32 values. Keep their fixed mask
    ahead of the cold subnormal mask calculation. }
  if e>=897 then
    exit((e<=1150) and ((u.bits and QWord($1fffffff))=QWord($10000000)));
  if e<873 then
    exit(False);
  discarded:=926-e;
  significand:=(u.bits and QWord($000fffffffffffff)) or (QWord(1) shl 52);
  mask:=(QWord(1) shl discarded)-1;
  fpc_pc24_midpoint:=(significand and mask)=(QWord(1) shl (discarded-1));
end;

function fpc_pc24_adjust(v,error: Double): Single; inline;
var
  u: TPC24DoubleBits;
begin
  u.value:=v;
  if error<>0 then
    if (error>0)=(v>0) then
      inc(u.bits)
    else
      dec(u.bits);
  fpc_pc24_adjust:=Single(u.value);
end;

function fpc_pc24_add_impl(a,b: Double): Single; inline;
var
  v,z,error: Double;
begin
  v:=a+b;
  if fpc_pc24_midpoint(v) then
    begin
      z:=v-a;
      error:=(a-(v-z))+(b-z);
      exit(fpc_pc24_adjust(v,error));
    end;
  fpc_pc24_add_impl:=Single(v);
end;

function fpc_pc24_sub_impl(a,b: Double): Single; inline;
begin
  fpc_pc24_sub_impl:=fpc_pc24_add_impl(a,-b);
end;

function fpc_pc24_mul_impl(a,b: Double): Single; inline;
var
  v,error: Double;
begin
  v:=a*b;
  if fpc_pc24_midpoint(v) then
    begin
      error:=pc24_fma(a,b,-v);
      exit(fpc_pc24_adjust(v,error));
    end;
  fpc_pc24_mul_impl:=Single(v);
end;

function fpc_pc24_div_impl(a,b: Double): Single; inline;
var
  v,error: Double;
begin
  v:=a/b;
  if fpc_pc24_midpoint(v) then
    begin
      { Only the sign is needed. Avoid dividing a tiny residual by b. }
      error:=pc24_fma(-v,b,a);
      if b<0 then
        error:=-error;
      exit(fpc_pc24_adjust(v,error));
    end;
  fpc_pc24_div_impl:=Single(v);
end;

function fpc_pc24_sqr_single_impl(a: Single): Single; inline;
begin
  fpc_pc24_sqr_single_impl:=a*a;
end;

function fpc_pc24_sqr_impl(a: Double): Single; inline;
begin
  fpc_pc24_sqr_impl:=fpc_pc24_mul_impl(a,a);
end;

function fpc_pc24_sqrt_impl(a: Double): Single; inline;
var
  v,error: Double;
begin
  v:=Sqrt(a);
  if fpc_pc24_midpoint(v) then
    begin
      error:=pc24_fma(-v,v,a);
      exit(fpc_pc24_adjust(v,error));
    end;
  fpc_pc24_sqrt_impl:=Single(v);
end;
{ The literal b+tail is exact. These paths are needed only when no
  coefficient certificate covers the other operand's significand width. }
function fpc_pc24_add_tail_impl(a,b,tail: Double): Single; inline;
var
  v,z,e,t,w: Double;
begin
  v:=a+b;
  z:=v-a;
  e:=(a-(v-z))+(b-z);
  t:=v+tail;
  if fpc_pc24_midpoint(t) then
    begin
      z:=t-v;
      w:=(v-(t-z))+(tail-z);
      exit(fpc_pc24_adjust(t,e+w));
    end;
  fpc_pc24_add_tail_impl:=Single(t);
end;

function fpc_pc24_sub_tail_impl(a,b,tail: Double): Single; inline;
begin
  fpc_pc24_sub_tail_impl:=fpc_pc24_add_tail_impl(a,-b,-tail);
end;

function fpc_pc24_rsub_tail_impl(a,b,tail: Double): Single; inline;
begin
  fpc_pc24_rsub_tail_impl:=fpc_pc24_add_tail_impl(-a,b,tail);
end;

function fpc_pc24_sum3(x,y,z: Double): Double; inline;
var
  t: Double;
begin
  { Adding the two largest terms first preserves the sign of their exact
    sum with the third, even when the leading residuals cancel. }
  if Abs(x)<Abs(y) then begin t:=x; x:=y; y:=t; end;
  if Abs(y)<Abs(z) then begin t:=y; y:=z; z:=t; end;
  if Abs(x)<Abs(y) then begin t:=x; x:=y; y:=t; end;
  fpc_pc24_sum3:=(x+y)+z;
end;

function fpc_pc24_mul_tail_impl(a,b,tail: Double): Single; inline;
var
  p,q,v,z,e: Double;
begin
  p:=a*b;
  q:=a*tail;
  v:=p+q;
  if fpc_pc24_midpoint(v) then
    begin
      z:=v-p;
      e:=(p-(v-z))+(q-z);
      e:=fpc_pc24_sum3(e,pc24_fma(a,b,-p),pc24_fma(a,tail,-q));
      exit(fpc_pc24_adjust(v,e));
    end;
  fpc_pc24_mul_tail_impl:=Single(v);
end;

function fpc_pc24_div_tail_impl(a,b,tail: Double): Single; inline;
var
  v,p,e: Double;
begin
  v:=a/b;
  v:=v+(pc24_fma(-v,b,a)-v*tail)/b;
  if fpc_pc24_midpoint(v) then
    begin
      p:=v*tail;
      e:=fpc_pc24_sum3(pc24_fma(-v,b,a),-p,-pc24_fma(v,tail,-p));
      if b<0 then e:=-e;
      exit(fpc_pc24_adjust(v,e));
    end;
  fpc_pc24_div_tail_impl:=Single(v);
end;

function fpc_pc24_rdiv_tail_impl(a,b,tail: Double): Single; inline;
var
  v,e: Double;
begin
  v:=b/a;
  v:=v+(pc24_fma(-v,a,b)+tail)/a;
  if fpc_pc24_midpoint(v) then
    begin
      e:=pc24_fma(-v,a,b)+tail;
      if a<0 then e:=-e;
      exit(fpc_pc24_adjust(v,e));
    end;
  fpc_pc24_rdiv_tail_impl:=Single(v);
end;
function fpc_pc24_add(a,b: Double): Single; compilerproc; inline;
begin
  fpc_pc24_add:=fpc_pc24_add_impl(a,b);
end;

function fpc_pc24_sub(a,b: Double): Single; compilerproc; inline;
begin
  fpc_pc24_sub:=fpc_pc24_sub_impl(a,b);
end;

function fpc_pc24_mul(a,b: Double): Single; compilerproc; inline;
begin
  fpc_pc24_mul:=fpc_pc24_mul_impl(a,b);
end;

function fpc_pc24_div(a,b: Double): Single; compilerproc; inline;
begin
  fpc_pc24_div:=fpc_pc24_div_impl(a,b);
end;

function fpc_pc24_sqr_single(a: Single): Single; compilerproc; inline;
begin
  fpc_pc24_sqr_single:=fpc_pc24_sqr_single_impl(a);
end;

function fpc_pc24_sqr(a: Double): Single; compilerproc; inline;
begin
  fpc_pc24_sqr:=fpc_pc24_sqr_impl(a);
end;

function fpc_pc24_sqrt(a: Double): Single; compilerproc; inline;
begin
  fpc_pc24_sqrt:=fpc_pc24_sqrt_impl(a);
end;

function fpc_pc24_add_tail(a,b,tail: Double): Single; compilerproc; inline;
begin
  fpc_pc24_add_tail:=fpc_pc24_add_tail_impl(a,b,tail);
end;

function fpc_pc24_sub_tail(a,b,tail: Double): Single; compilerproc; inline;
begin
  fpc_pc24_sub_tail:=fpc_pc24_sub_tail_impl(a,b,tail);
end;

function fpc_pc24_rsub_tail(a,b,tail: Double): Single; compilerproc; inline;
begin
  fpc_pc24_rsub_tail:=fpc_pc24_rsub_tail_impl(a,b,tail);
end;

function fpc_pc24_mul_tail(a,b,tail: Double): Single; compilerproc; inline;
begin
  fpc_pc24_mul_tail:=fpc_pc24_mul_tail_impl(a,b,tail);
end;

function fpc_pc24_div_tail(a,b,tail: Double): Single; compilerproc; inline;
begin
  fpc_pc24_div_tail:=fpc_pc24_div_tail_impl(a,b,tail);
end;

function fpc_pc24_rdiv_tail(a,b,tail: Double): Single; compilerproc; inline;
begin
  fpc_pc24_rdiv_tail:=fpc_pc24_rdiv_tail_impl(a,b,tail);
end;
function fpc_pc24_unrepresentable_equal(a: Double): Boolean; compilerproc; inline;
begin
  { The compiler uses this only against a finite non-binary64 literal.
    Keep the actual argument evaluation, including its side effects. }
  fpc_pc24_unrepresentable_equal:=False;
end;
{$if defined(CPUX86_64) and defined(SUPPORT_EXTENDED)}
{ Native binary80 operands cannot be narrowed to Double before an operation.
  Keep the complete operation inside one assembler routine so LLVM cannot
  move arithmetic across the precision-control changes. These cold paths
  preserve the caller's rounding mode and restore its original control word. }
{$asmmode att}
function fpc_pc24_add_extended(a,b: Extended): Extended; compilerproc; assembler;
var
  oldcw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  fldcw pc24cw
  fldt a
  fldt b
  faddp %st,%st(1)
  fwait
  fldcw oldcw
end;

function fpc_pc24_sub_extended(a,b: Extended): Extended; compilerproc; assembler;
var
  oldcw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  fldcw pc24cw
  fldt a
  fldt b
  fsubrp %st,%st(1)
  fwait
  fldcw oldcw
end;

function fpc_pc24_mul_extended(a,b: Extended): Extended; compilerproc; assembler;
var
  oldcw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  fldcw pc24cw
  fldt a
  fldt b
  fmulp %st,%st(1)
  fwait
  fldcw oldcw
end;

function fpc_pc24_div_extended(a,b: Extended): Extended; compilerproc; assembler;
var
  oldcw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  fldcw pc24cw
  fldt a
  fldt b
  fdivrp %st,%st(1)
  fwait
  fldcw oldcw
end;

function fpc_pc24_sqr_extended(a: Extended): Extended; compilerproc; assembler;
var
  oldcw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  fldcw pc24cw
  fldt a
  fld %st
  fmulp %st,%st(1)
  fwait
  fldcw oldcw
end;

function fpc_pc24_sqrt_extended(a: Extended): Extended; compilerproc; assembler;
var
  oldcw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  fldcw pc24cw
  fldt a
  fsqrt
  fwait
  fldcw oldcw
end;

function fpc_pc24_frac_extended(a: Extended): Extended; compilerproc; assembler;
var
  oldcw, truncw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  orw $0x0f00,%ax
  movw %ax,truncw
  fldt a
  fld %st
  fldcw truncw
  frndint
  fldcw pc24cw
  fsubrp %st,%st(1)
  fwait
  fldcw oldcw
end;
{$endif}
{$pop}
{$endif}
