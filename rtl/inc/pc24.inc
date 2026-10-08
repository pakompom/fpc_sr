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

function fpc_pc24_exp_reduced_impl(a: Double): Double;
const
  Ln2: Double = 0.693147180559945309417232121;
var
  u: TPC24DoubleBits;
  k: LongInt;
  fraction: Single;
begin
  { a is the PC24 product with the original binary80 log2(e) constant.
    Delphi 2007 uses FRNDINT, FSUB, F2XM1, FADD and FSCALE after that
    multiply. The add rounds the significand to 24 bits; scaling must
    retain the result type's exponent range rather than store a Single. }
  u.value:=a;
  if (u.bits and QWord($7ff0000000000000))=QWord($7ff0000000000000) then
    begin
      { The original subtraction of the integral part produces an invalid
        result for either infinity, rather than exp(+Inf)=+Inf. }
      if (u.bits and QWord($000fffffffffffff))=0 then
        begin
          u.value:=a-a;
          u.bits:=u.bits or QWord($8000000000000000);
          exit(u.value);
        end;
      exit(a+a);
    end;
  if a>1024 then
    exit(ldexp(1.0,2048));
  if a< -1076 then
    exit(ldexp(1.0,-2048));
  k:=Round(a);
  { The reduced argument is at most one half. Ordinary Exp here only
    implements F2XM1 + 1 before the explicit PC24 rounding; it does not
    repeat the original, PC24-rounded argument reduction. }
  fraction:=Exp((a-k)*Ln2);
  fpc_pc24_exp_reduced_impl:=ldexp(Double(fraction),k);
end;

function fpc_pc24_exp_reduced(a: Double): Double; compilerproc;
begin
  fpc_pc24_exp_reduced:=fpc_pc24_exp_reduced_impl(a);
end;

function fpc_pc24_exp(a: Double): Double; compilerproc;
const
  { Together these are exactly the x87 FLDL2E binary80 constant:
    significand $b8aa3b295c17f0bc, exponent zero. Keep its low bits when
    the product lies at a binary32 midpoint. }
  Log2EHi: Double = 1.4426950408889634;
  Log2ELo: Double = 2.0383000842727483e-17;
var
  u: TPC24DoubleBits;
begin
  u.value:=a;
  if (u.bits and QWord($7ff0000000000000))=QWord($7ff0000000000000) then
    exit(fpc_pc24_exp_reduced_impl(a));
  { Avoid narrowing a huge finite argument to Single before reducing it.
    Its sign already determines the stored Double overflow/underflow. }
  if a>1024 then
    exit(ldexp(1.0,2048));
  if a< -1024 then
    exit(ldexp(1.0,-2048));
  fpc_pc24_exp:=fpc_pc24_exp_reduced_impl(fpc_pc24_mul_tail_impl(a,Log2EHi,Log2ELo));
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
{$if (defined(CPUX86_64) or defined(CPUI386)) and defined(SUPPORT_EXTENDED)}
{$asmmode att}
function fpc_pc24_exp_extended(a: Extended): Extended; compilerproc; assembler;
var
  oldcw, pc24cw: Word;
asm
  fnstcw oldcw
  movw oldcw,%ax
  andw $0xfcff,%ax
  movw %ax,pc24cw
  fldcw pc24cw
  fldt a
  fldl2e
  fmulp %st,%st(1)
  fld %st
  frndint
  fxch %st(1)
  fsub %st(1),%st
  f2xm1
  fld1
  faddp %st,%st(1)
  fscale
  fstp %st(1)
  fwait
  fldcw oldcw
end;
{$endif}
{$pop}
{$endif}
