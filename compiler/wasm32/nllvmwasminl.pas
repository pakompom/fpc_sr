{
    Copyright (c) 2026 by the Free Pascal development team

    Lower WebAssembly intrinsics for the LLVM backend

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit nllvmwasminl;

{$i fpcdefs.inc}

interface

uses
  node,nllvminl,symtype,symdef;

type
  tllvmwasminlinenode = class(tllvminlinenode)
  private
    function atomic_value_type: tdef;
    procedure second_atomic_cpu;
  public
    function pass_typecheck_cpu: tnode; override;
    function first_cpu: tnode; override;
    procedure pass_generate_code_cpu; override;
  end;

implementation

uses
  constexp,compinnr,ncal,ncnv,ncon,ninl,
  globtype,globals,verbose,defutil,cgbase,cgutils,cpubase,
  aasmdata,aasmllvm,llvmbase,hlcgobj,pass_2;

function tllvmwasminlinenode.atomic_value_type: tdef;
var
  variantindex: longint;
begin
  if (inlinenumber>=in_wasm32_i32_atomic_rmw8_add_u) and (inlinenumber<=in_wasm32_i64_atomic_rmw_cmpxchg) then
    variantindex:=(ord(inlinenumber)-ord(in_wasm32_i32_atomic_rmw8_add_u)) mod 7
  else if (inlinenumber>=in_i32_atomic_load8_u) and (inlinenumber<=in_i64_atomic_load) then
    variantindex:=ord(inlinenumber)-ord(in_i32_atomic_load8_u)
  else
    variantindex:=ord(inlinenumber)-ord(in_i32_atomic_store8);
  case variantindex of
    0,3: result:=u8inttype;
    1,4: result:=u16inttype;
    2,5: result:=u32inttype;
    6: result:=u64inttype;
    else internalerror(2026100811);
  end;
end;

function tllvmwasminlinenode.pass_typecheck_cpu: tnode;
var
  variantindex: longint;
begin
  result:=nil;
  case inlinenumber of
    in_wasm32_i32_atomic_rmw8_add_u..in_wasm32_i64_atomic_rmw_cmpxchg:
      begin
        if inlinenumber>=in_wasm32_i32_atomic_rmw8_cmpxchg_u then
          CheckParameters(3)
        else
          CheckParameters(2);
        variantindex:=(ord(inlinenumber)-ord(in_wasm32_i32_atomic_rmw8_add_u)) mod 7;
        if variantindex<3 then resultdef:=u32inttype else resultdef:=u64inttype;
      end;
    in_i32_atomic_load8_u..in_i64_atomic_load:
      begin
        CheckParameters(1);
        if inlinenumber<=in_i32_atomic_load then resultdef:=u32inttype else resultdef:=u64inttype;
      end;
    in_i32_atomic_store8..in_i64_atomic_store:
      begin
        CheckParameters(2);
        resultdef:=voidtype;
      end;
    in_wasm32_atomic_fence:
      begin
        CheckParameters(0);
        resultdef:=voidtype;
      end;
    in_wasm32_memory_atomic_wait32,in_wasm32_memory_atomic_wait64:
      begin
        CheckParameters(3);
        resultdef:=s32inttype;
      end;
    in_wasm32_memory_atomic_notify:
      begin
        CheckParameters(2);
        resultdef:=u32inttype;
      end;
    in_wasm32_tls_size,in_wasm32_tls_align:
      begin
        CheckParameters(0);
        resultdef:=u32inttype;
      end;
    in_wasm32_tls_base:
      begin
        CheckParameters(0);
        resultdef:=voidpointertype;
      end;
    in_wasm32_memory_size:
      begin
        CheckParameters(0);
        resultdef:=u32inttype;
      end;
    in_wasm32_memory_grow:
      begin
        CheckParameters(1);
        resultdef:=u32inttype;
      end;
    in_wasm32_memory_fill,
    in_wasm32_memory_copy:
      begin
        CheckParameters(3);
        resultdef:=voidtype;
      end;
    in_wasm32_unreachable:
      begin
        CheckParameters(0);
        resultdef:=voidtype;
      end;
    else
      result:=inherited;
  end;
end;

function tllvmwasminlinenode.first_cpu: tnode;
var
  callparameters: tnode;
  p: tcallparanode;
begin
  result:=nil;
  case inlinenumber of
    in_wasm32_i32_atomic_rmw8_add_u..in_wasm32_i64_atomic_rmw_cmpxchg,
    in_i32_atomic_load8_u..in_i64_atomic_load:
      expectloc:=LOC_REGISTER;
    in_i32_atomic_store8..in_i64_atomic_store,in_wasm32_atomic_fence:
      expectloc:=LOC_VOID;
    in_wasm32_memory_atomic_wait32,
    in_wasm32_memory_atomic_wait64,
    in_wasm32_memory_atomic_notify:
      begin
        case inlinenumber of
          in_wasm32_memory_atomic_wait32: result:=ccallnode.createintern('llvm_wasm_memory_atomic_wait32',left);
          in_wasm32_memory_atomic_wait64: result:=ccallnode.createintern('llvm_wasm_memory_atomic_wait64',left);
          in_wasm32_memory_atomic_notify: result:=ccallnode.createintern('llvm_wasm_memory_atomic_notify',left);
          else
            internalerror(2026100809);
        end;
        left:=nil;
      end;
    in_wasm32_tls_size: result:=ccallnode.createintern('llvm_wasm_tls_size',nil);
    in_wasm32_tls_align: result:=ccallnode.createintern('llvm_wasm_tls_align',nil);
    in_wasm32_tls_base: result:=ccallnode.createintern('llvm_wasm_tls_base',nil);
    in_wasm32_memory_size:
      result:=ccallnode.createintern('llvm_wasm_memory_size',
        ccallparanode.create(cordconstnode.create(0,s32inttype,false),nil));
    in_wasm32_memory_grow:
      begin
        { CheckParameters accepts both the compact one-argument form and a
          parameter list; preserve the expression and supply memory index 0. }
        if left.nodetype=callparan then
          begin
            callparameters:=tcallparanode(left).left;
            tcallparanode(left).left:=nil;
            left.free;
            left:=callparameters;
          end;
        result:=ccallnode.createintern('llvm_wasm_memory_grow',
          ccallparanode.create(left,
            ccallparanode.create(cordconstnode.create(0,s32inttype,false),nil)));
        left:=nil;
      end;
    in_wasm32_memory_fill,
    in_wasm32_memory_copy:
      begin
        { Parameter lists are in reverse source order: count, value/source,
          destination. Wasm memory.copy is overlap-safe, hence memmove. }
        p:=tcallparanode(tcallparanode(left).right);
        if inlinenumber=in_wasm32_memory_copy then
          p.left:=ctypeconvnode.create_explicit(p.left,voidpointertype)
        else
          p.left:=ctypeconvnode.create_explicit(p.left,u8inttype);
        p:=tcallparanode(p.right);
        p.left:=ctypeconvnode.create_explicit(p.left,voidpointertype);
        callparameters:=ccallparanode.create(cordconstnode.create(0,llvmbool1type,false),left);
        if inlinenumber=in_wasm32_memory_copy then
          result:=ccallnode.createintern('llvm_wasm_memory_copy',callparameters)
        else
          result:=ccallnode.createintern('llvm_wasm_memory_fill',callparameters);
        left:=nil;
      end;
    in_wasm32_unreachable:
      result:=ccallnode.createintern('llvm_trap',nil);
    else
      result:=inherited;
  end;
end;

procedure tllvmwasminlinenode.second_atomic_cpu;
var
  args: array[0..2] of tnode;
  regs: array[0..2] of tregister;
  p: tnode;
  count,i: longint;
  valuedef,argdef: tdef;
  previous: tregister;
begin
  location_reset(location,LOC_VOID,OS_NO);
  if inlinenumber=in_wasm32_atomic_fence then
    begin
      current_asmdata.CurrAsmList.concat(taillvm.op_none(la_fence));
      exit;
    end;
  valuedef:=atomic_value_type;
  count:=0;
  p:=left;
  if p.nodetype<>callparan then
    begin
      args[0]:=p;
      count:=1;
    end
  else
    while assigned(p) do
      begin
        if count>high(args) then internalerror(2026100812);
        args[count]:=tcallparanode(p).left;
        inc(count);
        p:=tcallparanode(p).right;
      end;
  { Internal parameter lists are reversed. Match Wasm's source order,
    evaluating the address once before the value/comparand. }
  for i:=count-1 downto 0 do
    begin
      if i=count-1 then argdef:=cpointerdef.getreusable(valuedef) else argdef:=valuedef;
      secondpass(args[i]);
      hlcg.location_force_reg(current_asmdata.CurrAsmList,args[i].location,args[i].resultdef,argdef,true);
      regs[i]:=args[i].location.register;
    end;
  if (inlinenumber>=in_i32_atomic_store8) and (inlinenumber<=in_i64_atomic_store) then
    begin
      current_asmdata.CurrAsmList.concat(taillvm.atomicstore_size_reg_reg(valuedef,regs[0],regs[1]));
      exit;
    end;
  previous:=hlcg.getintregister(current_asmdata.CurrAsmList,valuedef);
  if (inlinenumber>=in_i32_atomic_load8_u) and (inlinenumber<=in_i64_atomic_load) then
    current_asmdata.CurrAsmList.concat(taillvm.op_reg_size_reg(la_atomicload,previous,valuedef,regs[0]))
  else if inlinenumber>=in_wasm32_i32_atomic_rmw8_cmpxchg_u then
    current_asmdata.CurrAsmList.concat(taillvm.cmpxchg_reg_size_reg_reg_reg(previous,valuedef,regs[2],regs[1],regs[0]))
  else
    current_asmdata.CurrAsmList.concat(taillvm.atomicrmw_reg_size_reg_reg(previous,valuedef,regs[1],regs[0],
      tllvmatomicop((ord(inlinenumber)-ord(in_wasm32_i32_atomic_rmw8_add_u)) div 7),lao_seq_cst));
  location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
  location.register:=hlcg.getintregister(current_asmdata.CurrAsmList,resultdef);
  hlcg.a_load_reg_reg(current_asmdata.CurrAsmList,valuedef,resultdef,previous,location.register);
end;

procedure tllvmwasminlinenode.pass_generate_code_cpu;
begin
  case inlinenumber of
    in_wasm32_i32_atomic_rmw8_add_u..in_wasm32_i64_atomic_rmw_cmpxchg,
    in_i32_atomic_load8_u..in_i64_atomic_store,
    in_wasm32_atomic_fence:
      second_atomic_cpu;
    else inherited;
  end;
end;

begin
  cinlinenode:=tllvmwasminlinenode;
end.
