{ Exact Delphi constant arithmetic for LEGACYPC24.
  Decimal parsing reproduces Delphi 2007's binary80 rounding steps and its
  scaled-decimal constant representation. Constant expressions retain 64
  significant bits independently of the runtime PC24 rounding policy.
  Integer arithmetic also proves the optional hardware multiplication
  coefficients. Parsing, folding and proofs do not use host floating-point
  arithmetic; conversion routines materialize the result for the host. }
unit pc24const;

{$mode objfpc}{$H+}{$Q-}{$R-}

interface

type
  tpc24binary80 = array[0..9] of byte;

  tpc24real = record
    valid, negative: boolean;
    significand: qword;
    exponent: longint;
    { Delphi decimal literals with at most four fractional places can retain
      a 10000 scale during compile-time arithmetic. The canonical value above
      is always unscaled; these fields preserve the separate raw operand. }
    scaled: boolean;
    scaled_significand: qword;
    scaled_exponent: longint;
  end;

function pc24_from_delphi_literal(const s: string; out r: tpc24real): boolean;
function pc24_named(const r: tpc24real): tpc24real;
function pc24_from_double(d: double): tpc24real;
function pc24_from_extended(e: extended): tpc24real;
function pc24_from_int(v: int64): tpc24real;
function pc24_from_uint(v: qword): tpc24real;
function pc24_to_double(const r: tpc24real): double;
function pc24_to_extended(const r: tpc24real): extended;
function pc24_to_binary80(const r: tpc24real): tpc24binary80;
function pc24_exact_double(const r: tpc24real): boolean;
function pc24_exact_single(const r: tpc24real): boolean;
function pc24_split(const r: tpc24real; out hi,lo: double): boolean;
function pc24_storage(const r: tpc24real; precision: byte): tpc24real;
function pc24_sqrt(const a: tpc24real; precision: byte; out r: tpc24real): boolean;
function pc24_compare(const a,b: tpc24real; out order: longint): boolean;
function pc24_integer(const r: tpc24real; nearest: boolean;
  out magnitude: qword; out negative: boolean): boolean;
function pc24_int(const r: tpc24real; out v: tpc24real): boolean;
function pc24_frac(const r: tpc24real; out v: tpc24real): boolean;
function pc24_fold(op: char; const a,b: tpc24real; precision: byte;
  out r: tpc24real): boolean;
function pc24_coefficient(const r: tpc24real; input_bits: byte;
  out d: double): boolean;

implementation

function pc24_from_delphi_decimal(const s: string; out r: tpc24real): boolean; forward;

type
  tnat = record
    limbs: array of longword;
  end;
  tcertificatecache = record
    value: tpc24real;
    input_bits: byte;
    proved: boolean;
    coefficient: double;
  end;

var
  decimalpowers: array[0..55] of tpc24real;
  decimalpowersready: boolean;
  certificatecache: array[0..255] of tcertificatecache;
  certificatecount,certificatenext: longint;

function bn(v: qword): tnat;
begin
  result.limbs:=nil;
  if v=0 then exit;
  if v shr 32=0 then setlength(result.limbs,1)
  else setlength(result.limbs,2);
  result.limbs[0]:=longword(v);
  if length(result.limbs)>1 then result.limbs[1]:=v shr 32;
end;

function pc24_named(const r: tpc24real): tpc24real;
var raw,limit: tpc24real; order: longint;
begin
  result:=r;
  if not r.scaled then exit;
  raw:=r; raw.significand:=r.scaled_significand; raw.exponent:=r.scaled_exponent;
  raw.negative:=false;
  limit:=pc24_from_uint(0); limit.significand:=qword($d1b71758e2196800); limit.exponent:=-14;
  if pc24_compare(raw,limit,order) and (order>0) then result.scaled:=false;
end;

function pc24_from_delphi_literal(const s: string; out r: tpc24real): boolean;
var i,point,order: longint; raw,limit,factor,actual: tpc24real;
begin
  result:=pc24_from_delphi_decimal(s,r);
  if not result then exit;
  point:=0;
  for i:=1 to length(s) do
    begin
      if s[i] in ['e','E'] then exit;
      if s[i]='.' then point:=i;
    end;
  if (point=0) or (length(s)-point>4) then exit;
  limit:=pc24_from_uint(0); limit.significand:=qword($d1b71758e2196800); limit.exponent:=-14;
  raw:=r; raw.negative:=false;
  if not pc24_compare(raw,limit,order) or (order>0) then exit;
  if not pc24_from_delphi_decimal(s+'e4',raw) then exit(false);
  factor:=pc24_from_uint(10000);
  if not pc24_fold('/',raw,factor,64,actual) then exit(false);
  r:=actual;
  r.scaled:=true; r.scaled_significand:=raw.significand; r.scaled_exponent:=raw.exponent;
end;

procedure trim(var a: tnat);
var n: sizeint;
begin
  n:=length(a.limbs);
  while (n>0) and (a.limbs[n-1]=0) do dec(n);
  setlength(a.limbs,n);
end;

function bits(const a: tnat): longint;
var v: longword;
begin
  result:=length(a.limbs)*32;
  if result=0 then exit;
  v:=a.limbs[high(a.limbs)];
  while v<$80000000 do begin dec(result); v:=v shl 1; end;
end;

function cmp(const a,b: tnat): longint;
var i: sizeint;
begin
  if length(a.limbs)<length(b.limbs) then exit(-1);
  if length(a.limbs)>length(b.limbs) then exit(1);
  for i:=high(a.limbs) downto 0 do
    begin
      if a.limbs[i]<b.limbs[i] then exit(-1);
      if a.limbs[i]>b.limbs[i] then exit(1);
    end;
  result:=0;
end;

operator +(const a,b: tnat) r: tnat;
var i,n: sizeint; v: qword;
begin
  r.limbs:=nil;
  n:=length(a.limbs);
  if length(b.limbs)>n then n:=length(b.limbs);
  setlength(r.limbs,n+1);
  v:=0;
  for i:=0 to n-1 do
    begin
      if i<length(a.limbs) then v:=v+a.limbs[i];
      if i<length(b.limbs) then v:=v+b.limbs[i];
      r.limbs[i]:=longword(v);
      v:=v shr 32;
    end;
  r.limbs[n]:=v;
  trim(r);
end;

operator -(const a,b: tnat) r: tnat;
var i: sizeint; v,borrow: qword;
begin
  r.limbs:=nil;
  setlength(r.limbs,length(a.limbs));
  borrow:=0;
  for i:=0 to high(a.limbs) do
    begin
      v:=qword(a.limbs[i])-borrow;
      if i<length(b.limbs) then v:=v-b.limbs[i];
      r.limbs[i]:=longword(v);
      borrow:=v shr 63;
    end;
  trim(r);
end;

operator *(const a,b: tnat) r: tnat;
var i,j: sizeint; v: qword;
begin
  r.limbs:=nil;
  setlength(r.limbs,length(a.limbs)+length(b.limbs));
  for i:=0 to high(a.limbs) do
    begin
      v:=0;
      for j:=0 to high(b.limbs) do
        begin
          v:=v+qword(a.limbs[i])*b.limbs[j]+r.limbs[i+j];
          r.limbs[i+j]:=longword(v);
          v:=v shr 32;
        end;
      r.limbs[i+length(b.limbs)]:=v;
    end;
  trim(r);
end;

function shift(const a: tnat; n: longint): tnat;
var i,w,s: longint; v: qword;
begin
  result.limbs:=nil;
  if (length(a.limbs)=0) or (bits(a)+n<=0) then exit;
  if n>=0 then
    begin
      w:=n div 32; s:=n mod 32;
      setlength(result.limbs,length(a.limbs)+w+1);
      v:=0;
      for i:=0 to high(a.limbs) do
        begin
          v:=v or (qword(a.limbs[i]) shl s);
          result.limbs[i+w]:=longword(v);
          v:=v shr 32;
        end;
      result.limbs[length(a.limbs)+w]:=v;
    end
  else
    begin
      n:=-n; w:=n div 32; s:=n mod 32;
      setlength(result.limbs,length(a.limbs)-w);
      for i:=w to high(a.limbs) do
        begin
          v:=a.limbs[i];
          if i<high(a.limbs) then v:=v or (qword(a.limbs[i+1]) shl 32);
          result.limbs[i-w]:=longword(v shr s);
        end;
    end;
  trim(result);
end;

procedure divmod(const a,b: tnat; out q,r: tnat);
var n,i: longint; v: tnat;
begin
  q:=bn(0); r:=a;
  if length(b.limbs)=0 then exit;
  n:=bits(a)-bits(b);
  if n<0 then exit;
  setlength(q.limbs,n div 32+1);
  v:=shift(b,n);
  for i:=n downto 0 do
    begin
      if cmp(r,v)>=0 then
        begin
          r:=r-v;
          q.limbs[i div 32]:=q.limbs[i div 32] or (longword(1) shl (i mod 32));
        end;
      v:=shift(v,-1);
    end;
  trim(q);
end;

operator div(const a,b: tnat) r: tnat;
var rem: tnat;
begin divmod(a,b,r,rem); end;

operator mod(const a,b: tnat) r: tnat;
var q: tnat;
begin divmod(a,b,q,r); end;

function uq(const a: tnat): qword;
begin
  result:=0;
  if length(a.limbs)>0 then result:=a.limbs[0];
  if length(a.limbs)>1 then result:=result or (qword(a.limbs[1]) shl 32);
end;

function roundratio(const num,den: tnat): tnat;
var rem: tnat; c: longint;
begin
  divmod(num,den,result,rem);
  c:=cmp(shift(rem,1),den);
  if (c>0) or ((c=0) and (uq(result) and 1<>0)) then result:=result+bn(1);
end;

function fromratio(num,den: tnat; scale: longint; negative: boolean;
  precision: byte): tpc24real;
var e,s: longint; q: tnat;
begin
  fillchar(result,sizeof(result),0);
  if (length(den.limbs)=0) or (precision=0) or (precision>64) then exit;
  result.valid:=true; result.negative:=negative;
  if length(num.limbs)=0 then exit;
  e:=bits(num)-bits(den);
  if e>=0 then
    begin if cmp(num,shift(den,e))<0 then dec(e); end
  else if cmp(shift(num,-e),den)<0 then dec(e);
  s:=precision-1-e;
  if s>=0 then num:=shift(num,s) else den:=shift(den,-s);
  q:=roundratio(num,den);
  if bits(q)>precision then begin q:=shift(q,-1); inc(e); end;
  result.significand:=uq(shift(q,64-precision));
  result.exponent:=e+scale-63;
  { Do not invent an infinity, subnormal binary80, or wrapped exponent. }
  if (result.exponent < -16445) or (result.exponent>16320) then result.valid:=false;
end;

function pc24_from_decimal(const s: string; out r: tpc24real): boolean;
var n,d: tnat; i,fracdigits,exponent,esign,digits: longint;
    neg,dot: boolean;
begin
  fillchar(r,sizeof(r),0);
  n:=bn(0); d:=bn(1); i:=1; fracdigits:=0; neg:=false; dot:=false; digits:=0;
  if (i<=length(s)) and (s[i] in ['+','-']) then
    begin neg:=s[i]='-'; inc(i); end;
  while i<=length(s) do
    begin
      if s[i]='.' then
        begin if dot then exit(false); dot:=true; end
      else if s[i] in ['0'..'9'] then
        begin
          n:=n*bn(10)+bn(ord(s[i])-ord('0'));
          inc(digits); if dot then inc(fracdigits);
        end
      else break;
      inc(i);
    end;
  if digits=0 then exit(false);
  exponent:=0;
  if (i<=length(s)) and (s[i] in ['e','E']) then
    begin
      inc(i); esign:=1;
      if (i<=length(s)) and (s[i] in ['+','-']) then
        begin if s[i]='-' then esign:=-1; inc(i); end;
      digits:=0;
      while (i<=length(s)) and (s[i] in ['0'..'9']) do
        begin
          exponent:=exponent*10+ord(s[i])-ord('0');
          if exponent>6000 then exit(false);
          inc(i); inc(digits);
        end;
      if digits=0 then exit(false);
      exponent:=exponent*esign;
    end;
  if i<=length(s) then exit(false);
  exponent:=exponent-fracdigits;
  if abs(exponent)>6000 then exit(false);
  for i:=1 to abs(exponent) do
    if exponent>=0 then n:=n*bn(5) else d:=d*bn(5);
  r:=fromratio(n,d,exponent,neg,64);
  result:=r.valid;
end;

function pc24_from_uint(v: qword): tpc24real;
begin result:=fromratio(bn(v),bn(1),0,false,64); end;

function pc24_from_delphi_decimal(const s: string; out r: tpc24real): boolean;
var i,j,fraction,exponent,esign,digits,power: longint;
    negative,dot: boolean; digit,work,factor: tpc24real; text: string;
    operation: char;
begin
  fillchar(r,sizeof(r),0);
  { Delphi 2007 _ValExt uses separately rounded binary80 digit operations
    and the three _Pow10 tables; a single rational rounding is different. }
  if not decimalpowersready then
    begin
      for j:=0 to 55 do
        begin
          if j<32 then power:=j
          else if j<47 then power:=(j-31)*32
          else power:=(j-46)*512;
          str(power,text);
          if not pc24_from_decimal('1e'+text,decimalpowers[j]) then exit(false);
        end;
      decimalpowersready:=true;
    end;
  i:=1; fraction:=0; negative:=false; dot:=false; digits:=0;
  if (i<=length(s)) and (s[i] in ['+','-']) then
    begin negative:=s[i]='-'; inc(i); end;
  r:=pc24_from_uint(0);
  while i<=length(s) do
    begin
      if s[i]='.' then
        begin if dot then exit(false); dot:=true; end
      else if s[i] in ['0'..'9'] then
        begin
          digit:=pc24_from_uint(ord(s[i])-ord('0'));
          if not pc24_fold('*',r,decimalpowers[1],64,work) or
            not pc24_fold('+',work,digit,64,r) then exit(false);
          inc(digits); if dot then inc(fraction);
        end
      else break;
      inc(i);
    end;
  if digits=0 then exit(false);
  exponent:=0;
  if (i<=length(s)) and (s[i] in ['e','E']) then
    begin
      inc(i); esign:=1;
      if (i<=length(s)) and (s[i] in ['+','-']) then
        begin if s[i]='-' then esign:=-1; inc(i); end;
      digits:=0;
      while (i<=length(s)) and (s[i] in ['0'..'9']) do
        begin
          exponent:=exponent*10+ord(s[i])-ord('0');
          if exponent>100000 then exit(false);
          inc(i); inc(digits);
        end;
      if digits=0 then exit(false);
      exponent:=exponent*esign;
    end;
  if i<=length(s) then exit(false);
  power:=exponent-fraction;
  if power<=-5120 then r:=pc24_from_uint(0)
  else
    begin
      if power>=5120 then exit(false);
      j:=abs(power);
      if power<0 then operation:='/' else operation:='*';
      if j<>0 then
        begin
          factor:=decimalpowers[j mod 32];
          if not pc24_fold(operation,r,factor,64,work) then exit(false);
          r:=work;
          if j div 32 mod 16<>0 then
            begin
              factor:=decimalpowers[31+j div 32 mod 16];
              if not pc24_fold(operation,r,factor,64,work) then exit(false);
              r:=work;
            end;
          if j div 512<>0 then
            begin
              factor:=decimalpowers[46+j div 512];
              if not pc24_fold(operation,r,factor,64,work) then exit(false);
              r:=work;
            end;
        end;
    end;
  r.negative:=negative;
  result:=r.valid;
end;

function pc24_from_int(v: int64): tpc24real;
begin
  if v<0 then result:=fromratio(bn(qword(-v)),bn(1),0,true,64)
  else result:=pc24_from_uint(v);
end;

function pc24_from_double(d: double): tpc24real;
var u,m: qword; e: longint;
begin
  move(d,u,sizeof(u));
  e:=(u shr 52) and $7ff; m:=u and $fffffffffffff;
  fillchar(result,sizeof(result),0);
  if e=$7ff then exit;
  if e=0 then e:=-1074
  else begin m:=m or (qword(1) shl 52); e:=e-1023-52; end;
  result:=fromratio(bn(m),bn(1),e,u shr 63<>0,64);
end;

function pc24_to_double(const r: tpc24real): double;
var e,s: longint; m,u: qword; n: tnat;
begin
  u:=0;
  if r.negative then u:=qword(1) shl 63;
  if r.significand<>0 then
    begin
      e:=r.exponent+63;
      if e>1023 then u:=u or $7ff0000000000000
      else
        begin
          s:=11;
          if e < -1022 then s:=-1074-r.exponent;
          n:=bn(r.significand);
          if s>0 then n:=roundratio(n,shift(bn(1),s)) else n:=shift(n,-s);
          m:=uq(n);
          if m>=qword(1) shl 53 then begin m:=m shr 1; inc(e); end;
          if e>1023 then u:=u or $7ff0000000000000
          else if e < -1022 then u:=u or m
          else u:=u or (qword(e+1023) shl 52) or (m and $fffffffffffff);
        end;
    end;
  move(u,result,sizeof(result));
end;

{$if sizeof(extended)=10}
type
  { Host binary80 layout, also used by FPC's software Extended type. }
  textendedbits = packed record
{$ifdef FPC_LITTLE_ENDIAN}
    significand: qword;
    sign_exponent: word;
{$else}
    sign_exponent: word;
    significand: qword;
{$endif}
  end;
{$endif}

function pc24_from_extended(e: extended): tpc24real;
{$if sizeof(extended)=10}
var bits: textendedbits; exponent: longint;
begin
  move(e,bits,sizeof(bits));
  exponent:=bits.sign_exponent and $7fff;
  if exponent=$7fff then
    begin
      fillchar(result,sizeof(result),0);
      exit;
    end;
  if exponent=0 then exponent:=1;
  result:=fromratio(bn(bits.significand),bn(1),exponent-16383-63,
    (bits.sign_exponent and $8000)<>0,64);
end;
{$else}
begin
  result:=pc24_from_double(e);
end;
{$endif}

function pc24_to_binary80(const r: tpc24real): tpc24binary80;
var significand: qword; sign_exponent: word; exponent,i: longint;
begin
  significand:=0;
  sign_exponent:=0;
  if r.significand<>0 then
    begin
      exponent:=r.exponent+63+16383;
      if exponent>=$7fff then
        begin
          sign_exponent:=$7fff;
          significand:=qword(1) shl 63;
        end
      else if exponent<=0 then
        begin
          significand:=uq(roundratio(bn(r.significand),shift(bn(1),1-exponent)));
          if significand>=qword(1) shl 63 then
            sign_exponent:=1;
        end
      else
        begin
          sign_exponent:=exponent;
          significand:=r.significand;
        end;
    end;
  if r.negative then sign_exponent:=sign_exponent or $8000;
  { x87 storage is little-endian, independently of the compiler host. }
  for i:=0 to 7 do
    result[i]:=significand shr (i*8);
  result[8]:=sign_exponent;
  result[9]:=sign_exponent shr 8;
end;

function pc24_to_extended(const r: tpc24real): extended;
{$if sizeof(extended)=10}
var bits: tpc24binary80;
begin
  bits:=pc24_to_binary80(r);
  move(bits,result,sizeof(bits));
end;
{$else}
begin
  result:=pc24_to_double(r);
end;
{$endif}

function pc24_exact_double(const r: tpc24real): boolean;
var v: tpc24real;
begin
  v:=pc24_from_double(pc24_to_double(r));
  result:=r.valid and v.valid and (r.significand=v.significand) and
    ((r.significand=0) or (r.exponent=v.exponent));
end;

function pc24_exact_single(const r: tpc24real): boolean;
begin
  result:=r.valid and ((r.significand=0) or
    ((r.significand and $ffffffffff=0) and (r.exponent+63<=127) and
      (r.exponent+63>=-126)));
end;

function pc24_split(const r: tpc24real; out hi,lo: double): boolean;
var upper,lower: tpc24real;
begin
  hi:=pc24_to_double(r); lo:=0;
  upper:=pc24_from_double(hi);
  result:=r.valid and upper.valid and pc24_fold('-',r,upper,64,lower) and
    pc24_exact_double(lower);
  if result then lo:=pc24_to_double(lower);
end;

function pc24_storage(const r: tpc24real; precision: byte): tpc24real;
var scale,minscale,maxexp,s: longint; n: tnat;
begin
  result:=r;
  result.scaled:=false;
  if not r.valid or (r.significand=0) then exit;
  case precision of
    24: begin minscale:=-149; maxexp:=127; end;
    53: begin minscale:=-1074; maxexp:=1023; end;
    else begin result.valid:=false; exit; end;
  end;
  scale:=r.exponent+64-precision;
  if scale<minscale then scale:=minscale;
  s:=scale-r.exponent;
  n:=bn(r.significand);
  if s>0 then n:=roundratio(n,shift(bn(1),s)) else n:=shift(n,-s);
  result:=fromratio(n,bn(1),scale,r.negative,64);
  if (result.significand<>0) and (result.exponent+63>maxexp) then result.valid:=false;
end;

function pc24_sqrt(const a: tpc24real; precision: byte; out r: tpc24real): boolean;
var n,d,q,trial,mid,rootbit: tnat; e,scale,s,i,c: longint;
begin
  fillchar(r,sizeof(r),0);
  if not a.valid or ((a.significand<>0) and a.negative) or
    (precision=0) or (precision>64) then exit(false);
  if a.significand=0 then begin r:=a; r.scaled:=false; exit(true); end;
  e:=a.exponent+63;
  if e<0 then e:=(e-1) div 2 else e:=e div 2;
  scale:=e-precision+1;
  s:=a.exponent-2*scale;
  n:=bn(a.significand); d:=bn(1);
  if s>=0 then n:=shift(n,s) else d:=shift(d,-s);
  { Construct floor(sqrt(n/d)) one bit at a time. Only 64 bits are needed. }
  q:=bn(0);
  for i:=precision-1 downto 0 do
    begin
      rootbit:=shift(bn(1),i); trial:=q+rootbit;
      if cmp(trial*trial*d,n)<=0 then q:=trial;
    end;
  mid:=shift(q,1)+bn(1);
  c:=cmp(shift(n,2),mid*mid*d);
  if (c>0) or ((c=0) and (uq(q) and 1<>0)) then q:=q+bn(1);
  r:=fromratio(q,bn(1),scale,false,64);
  result:=r.valid;
end;

function pc24_compare(const a,b: tpc24real; out order: longint): boolean;
begin
  order:=0;
  result:=a.valid and b.valid;
  if not result then exit;
  if (a.significand=0) and (b.significand=0) then exit;
  if a.negative<>b.negative then
    begin
      if a.negative then order:=-1 else order:=1;
      exit;
    end;
  if a.significand=0 then order:=-1
  else if b.significand=0 then order:=1
  else if a.exponent<b.exponent then order:=-1
  else if a.exponent>b.exponent then order:=1
  else if a.significand<b.significand then order:=-1
  else if a.significand>b.significand then order:=1;
  if a.negative then order:=-order;
end;

function pc24_integer(const r: tpc24real; nearest: boolean;
  out magnitude: qword; out negative: boolean): boolean;
var n: tnat;
begin
  magnitude:=0; negative:=r.negative;
  result:=r.valid;
  if not result or (r.significand=0) then exit;
  if r.exponent>=0 then
    begin
      if r.exponent>0 then exit(false);
      magnitude:=r.significand; exit;
    end;
  n:=bn(r.significand);
  if nearest then n:=roundratio(n,shift(bn(1),-r.exponent))
  else n:=shift(n,r.exponent);
  if bits(n)>64 then exit(false);
  magnitude:=uq(n);
end;

function pc24_int(const r: tpc24real; out v: tpc24real): boolean;
begin
  v:=r; v.scaled:=false; result:=r.valid;
  if not result or (r.significand=0) or (r.exponent>=0) then exit;
  v:=fromratio(shift(bn(r.significand),r.exponent),bn(1),0,r.negative,64);
end;

function pc24_frac(const r: tpc24real; out v: tpc24real): boolean;
var n: qword;
begin
  v:=r; v.scaled:=false; result:=r.valid;
  if not result or (r.significand=0) then exit;
  if r.exponent>=0 then
    begin v.significand:=0; v.exponent:=0; end
  else if r.exponent>-64 then
    begin
      n:=r.significand and ((qword(1) shl -r.exponent)-1);
      v:=fromratio(bn(n),bn(1),r.exponent,r.negative,64);
    end;
end;

function raw_fold(op: char; const a,b: tpc24real; precision: byte;
  out r: tpc24real): boolean;
var n,d,x,y: tnat; e: longint; neg,bneg: boolean;
begin
  fillchar(r,sizeof(r),0);
  if not a.valid or not b.valid then exit(false);
  n:=bn(a.significand); d:=bn(b.significand);
  neg:=a.negative xor b.negative;
  case op of
    '*': r:=fromratio(n*d,bn(1),a.exponent+b.exponent,neg,precision);
    '/': r:=fromratio(n,d,a.exponent-b.exponent,neg,precision);
    '+','-':
      begin
        e:=a.exponent; if b.exponent<e then e:=b.exponent;
        x:=shift(n,a.exponent-e); y:=shift(d,b.exponent-e);
        bneg:=b.negative xor (op='-'); neg:=a.negative;
        if neg=bneg then n:=x+y
        else if cmp(x,y)>=0 then n:=x-y
        else begin n:=y-x; neg:=bneg; end;
        if bits(n)=0 then neg:=a.negative and bneg;
        r:=fromratio(n,bn(1),e,neg,precision);
      end;
    else exit(false);
  end;
  result:=r.valid;
end;

function pc24_fold(op: char; const a,b: tpc24real; precision: byte;
  out r: tpc24real): boolean;
var x,y,raw,factor: tpc24real; scaled: boolean;
begin
  x:=a; y:=b; scaled:=false;
  if (precision=64) and a.scaled and b.scaled then
    begin
      case op of
        '+','-','/':
          begin
            x.significand:=a.scaled_significand; x.exponent:=a.scaled_exponent;
            y.significand:=b.scaled_significand; y.exponent:=b.scaled_exponent;
            scaled:=op<>'/';
          end;
        '*':
          begin
            y.significand:=b.scaled_significand; y.exponent:=b.scaled_exponent;
            scaled:=true;
          end;
        else ;
      end;
    end;
  x.scaled:=false; y.scaled:=false;
  result:=raw_fold(op,x,y,precision,raw);
  if not result then begin r:=raw; exit; end;
  if scaled then
    begin
      factor:=pc24_from_uint(10000);
      result:=raw_fold('/',raw,factor,64,r);
      if result then
        begin
          r.scaled:=true; r.scaled_significand:=raw.significand;
          r.scaled_exponent:=raw.exponent;
        end;
    end
  else r:=raw;
end;

{ Euclidean floor sum: sum(floor((a*i+b)/m), i=0..n-1). }
function floors(n,m,a,b: tnat): tnat;
var top,t: tnat;
begin
  result:=bn(0);
  while true do
    begin
      result:=result+(n*(n-bn(1)) div bn(2))*(a div m)+n*(b div m);
      a:=a mod m; b:=b mod m;
      top:=a*n+b;
      if cmp(top,m)<0 then exit;
      n:=top div m; b:=top mod m; t:=m; m:=a; a:=t;
    end;
end;

function rounded(const n: tnat; precision: byte): tnat;
var s: longint;
begin
  s:=bits(n)-precision;
  if s<=0 then result:=n
  else result:=shift(roundratio(n,shift(bn(1),s)),s);
end;

function certifies(c,d: tnat; precision: byte): boolean;
var lo,hi,start,stop,cut,l,r,h,f,diff,cross,exact,bias: tnat;
    cuts: array[0..7] of tnat; count,i,j,k,p,coarse,fine: longint;
begin
  result:=false;
  if (precision<24) or (precision>32) or (bits(c)<>64) or (bits(d)=0) then exit;
  if cmp(c,d)>=0 then diff:=c-d else diff:=d-c;
  if cmp(diff,bn(8192))>0 then exit;
  lo:=shift(bn(1),precision-1); hi:=shift(lo,1);
  cuts[0]:=lo; cuts[1]:=hi; count:=2;
  for p:=62 to 64 do
    for k:=0 to 1 do
      begin
        if k=0 then cut:=c else cut:=d;
        cut:=(shift(bn(1),precision+p)+cut-bn(1)) div cut;
        if cmp(cut,lo)<0 then cut:=lo;
        if cmp(cut,hi)>0 then cut:=hi;
        cuts[count]:=cut; inc(count);
      end;
  for i:=1 to count-1 do
    begin
      cut:=cuts[i]; j:=i;
      while (j>0) and (cmp(cuts[j-1],cut)>0) do
        begin cuts[j]:=cuts[j-1]; dec(j); end;
      cuts[j]:=cut;
    end;
  for i:=0 to count-2 do
    begin
      start:=cuts[i]; stop:=cuts[i+1];
      if cmp(start,stop)=0 then continue;
      coarse:=bits(start*c)-24; fine:=bits(start*d)-53;
      if coarse<>fine+29 then
        begin
          if (cmp(stop-start,bn(1))<>0) or
            (cmp(rounded(start*c,24),rounded(rounded(start*d,53),24))<>0) then exit;
          continue;
        end;
      h:=shift(bn(1),coarse-1); f:=shift(bn(1),fine-1);
      cross:=stop;
      if bits(diff)<>0 then cross:=f div diff+bn(1);
      if (cmp(cross,start)<=0) or (cmp(cross,stop)>=0) then cross:=stop;
      l:=start;
      while cmp(l,stop)<0 do
        begin
          r:=cross;
          for k:=0 to 1 do
            begin
              if k=0 then begin exact:=bn(3)*h-bn(1); bias:=exact-f; end
              else begin exact:=h; bias:=h+f; end;
              if cmp(floors(r-l,shift(h,2),c,c*l+exact),
                floors(r-l,shift(h,2),d,d*l+bias))<>0 then exit;
            end;
          l:=r; cross:=stop;
        end;
    end;
  result:=true;
end;

function find_coefficient(const r: tpc24real; input_bits: byte;
  out d: double): boolean;
const offsets: array[0..8] of shortint=(0,-1,1,-2,2,-3,3,-4,4);
var nearest,u: qword; candidate: double; v: tpc24real; n: tnat; i: integer;
begin
  result:=false;
  if not r.valid or (input_bits<24) or (input_bits>32) then exit;
  d:=pc24_to_double(r);
  if r.significand=0 then exit(true);
  { The certificate assumes a normal binary64 coefficient. }
  move(d,nearest,sizeof(nearest));
  nearest:=nearest and $7fffffffffffffff;
  if (nearest shr 52=0) or (nearest shr 52=$7ff) then exit;
  for i:=0 to high(offsets) do
    begin
      u:=nearest+qword(int64(offsets[i])); move(u,candidate,sizeof(candidate));
      v:=pc24_from_double(candidate);
      if not v.valid then continue;
      n:=shift(bn(v.significand),v.exponent-r.exponent);
      if certifies(bn(r.significand),n,input_bits) then
        begin
          if r.negative then u:=u or (qword(1) shl 63);
          move(u,d,sizeof(d)); exit(true);
        end;
    end;
end;

function pc24_coefficient(const r: tpc24real; input_bits: byte;
  out d: double): boolean;
var i: longint;
begin
  d:=0;
  if not r.valid then exit(false);
  for i:=0 to certificatecount-1 do
    if (certificatecache[i].value.significand=r.significand) and
      (certificatecache[i].value.exponent=r.exponent) and
      (certificatecache[i].value.negative=r.negative) and
      (certificatecache[i].input_bits=input_bits) then
      begin d:=certificatecache[i].coefficient; exit(certificatecache[i].proved); end;
  result:=find_coefficient(r,input_bits,d);
  certificatecache[certificatenext].value:=r;
  certificatecache[certificatenext].input_bits:=input_bits;
  certificatecache[certificatenext].proved:=result;
  certificatecache[certificatenext].coefficient:=d;
  if certificatecount<length(certificatecache) then inc(certificatecount);
  certificatenext:=(certificatenext+1) mod length(certificatecache);
end;

end.
