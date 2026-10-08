{ Software binary64 fused multiply-add for PC24 residuals on targets without
  an FMA instruction or a C math library. The integer product and alignment
  follow musl src/math/fma.c; packing below rounds directly to nearest-even,
  including subnormals, without an intermediate floating-point rounding.
  Like the other PC24 helpers, this does not reproduce exception flags.

  Copyright (c) 2005-2020 Rich Felker, et al.

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. }

type
  TPC24FMANumber = record
    significand: QWord;
    exponent: LongInt;
    negative: Boolean;
  end;

function pc24_fma_normalize(x: Double): TPC24FMANumber; inline;
var
  u: TPC24DoubleBits;
  e: LongInt;
begin
  u.value:=x;
  Result.negative:=(u.bits shr 63)<>0;
  e:=(u.bits shr 52) and $7ff;
  if e=0 then
    begin
      u.value:=x*9223372036854775808.0; { 2^63 normalizes every subnormal. }
      e:=(u.bits shr 52) and $7ff;
      if e<>0 then dec(e,63) else e:=$800;
    end;
  Result.significand:=((u.bits and QWord($000fffffffffffff)) or
    (QWord(1) shl 52)) shl 1;
  Result.exponent:=e-1076;
end;

function pc24_fma(a,b,c: Double): Double;
const
  ZeroInfNaN = $7ff-1076;
var
  x,y,z: TPC24FMANumber;
  rhi,rlo,zhi,zlo,t,u,v,half,remainder: QWord;
  e,d,bias: LongInt;
  negative: Boolean;
  bits: TPC24DoubleBits;
begin
  x:=pc24_fma_normalize(a);
  y:=pc24_fma_normalize(b);
  z:=pc24_fma_normalize(c);
  if (x.exponent>=ZeroInfNaN) or (y.exponent>=ZeroInfNaN) then
    exit(a*b+c);
  if z.exponent>=ZeroInfNaN then
    if z.exponent>ZeroInfNaN then exit(a*b) else exit(c);

  { Exact 54 by 54 bit product. The cross-products cannot overflow. }
  t:=QWord(LongWord(x.significand))*LongWord(y.significand);
  u:=QWord(LongWord(x.significand))*(y.significand shr 32)+
    (x.significand shr 32)*LongWord(y.significand);
  rlo:=t+(u shl 32);
  rhi:=(x.significand shr 32)*(y.significand shr 32)+
    (u shr 32)+Ord(t>rlo);

  { Align at a shared exponent, retaining a sticky low bit. }
  e:=x.exponent+y.exponent;
  d:=z.exponent-e;
  if d>0 then
    if d<64 then
      begin zlo:=z.significand shl d; zhi:=z.significand shr (64-d); end
    else
      begin
        zlo:=0;
        zhi:=z.significand;
        e:=z.exponent-64;
        dec(d,64);
        if d>=64 then
          begin rlo:=1; rhi:=0; end
        else if d<>0 then
          begin
            rlo:=(rhi shl (64-d)) or (rlo shr d) or Ord((rlo shl (64-d))<>0);
            rhi:=rhi shr d;
          end;
      end
  else
    begin
      zhi:=0;
      d:=-d;
      if d=0 then zlo:=z.significand
      else if d<64 then zlo:=(z.significand shr d) or Ord((z.significand shl (64-d))<>0)
      else zlo:=1;
    end;

  negative:=x.negative xor y.negative;
  if negative=z.negative then
    begin
      inc(rlo,zlo);
      inc(rhi,zhi+Ord(rlo<zlo));
    end
  else
    begin
      t:=rlo;
      dec(rlo,zlo);
      rhi:=rhi-zhi-Ord(t<rlo);
      if (rhi shr 63)<>0 then
        begin
          rlo:=-rlo;
          rhi:=-rhi-Ord(rlo<>0);
          negative:=not negative;
        end;
    end;

  { Put the leading bit at bit 62, retaining all discarded bits in bit 0. }
  if rhi<>0 then
    begin
      inc(e,64);
      d:=62-LongInt(BsrQWord(rhi));
      rhi:=(rhi shl d) or (rlo shr (64-d)) or Ord((rlo shl d)<>0);
    end
  else if rlo<>0 then
    begin
      d:=62-LongInt(BsrQWord(rlo));
      if d<0 then rhi:=(rlo shr 1) or (rlo and 1) else rhi:=rlo shl d;
    end
  else
    exit(a*b+c); { Exact zero; preserve its sign. }
  dec(e,d);

  { One nearest-even rounding, at binary64 precision or the subnormal step. }
  bias:=e+1085;
  if bias>0 then d:=10 else d:=11-bias;
  if d>=64 then v:=0
  else
    begin
      half:=QWord(1) shl (d-1);
      remainder:=rhi and ((half shl 1)-1);
      v:=rhi shr d;
      if (remainder>half) or ((remainder=half) and Odd(v)) then inc(v);
    end;
  if bias>0 then
    begin
      if v=(QWord(1) shl 53) then begin v:=v shr 1; inc(bias); end;
      if bias>=$7ff then v:=QWord($7ff0000000000000)
      else v:=(QWord(bias-1) shl 52)+v;
    end;
  bits.bits:=v or (QWord(Ord(negative)) shl 63);
  pc24_fma:=bits.value;
end;
