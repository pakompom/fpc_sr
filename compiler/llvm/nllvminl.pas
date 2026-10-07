{
    Copyright (c) 2014 by Jonas Maebe

    Generate LLVM bytecode for inline nodes

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
unit nllvminl;

{$i fpcdefs.inc}

interface

    uses
      node,
      ncginl;

    type
      tllvminlinenode = class(tcginlinenode)
       protected
        procedure maybe_remove_round_trunc_typeconv;
        function lower_real_to_int64: tnode;

        function first_get_frame: tnode; override;
        function first_abs_real: tnode; override;
        function first_atomic: tnode; override;
        function first_bitscan: tnode; override;
        function first_fma: tnode; override;
        function first_sqr_real: tnode; override;
        function first_sqrt_real: tnode; override;
        function first_round_real: tnode; override;
        function first_trunc_real: tnode; override;
        function first_int_real: tnode; override;
        function first_popcnt: tnode; override;
       public
        procedure pass_generate_code_cpu; override;
        procedure second_length; override;
        procedure second_high; override;
        procedure second_sqr_real; override;
        procedure second_trunc_real; override;
      end;


implementation

     uses
       verbose,globals,globtype,constexp,cutils,
       aasmbase, aasmdata,
       symconst,symtype,symdef,defutil,symtable,
       compinnr,
       nutils,nadd,nbas,ncal,ncnv,ncon,nflw,ninl,nld,nmat,nmem,htypechk,
       pass_2,
       cgbase,cgutils,tgobj,hlcgobj,paramgr,parabase,
       cpubase,
       llvmbase,llvminfo,aasmllvm,aasmllvmmetadata;

    function tllvminlinenode.first_atomic: tnode;
      begin
{$if defined(aarch64) or defined(x86_64)}
        if ((inlinenumber<>in_atomic_inc) and (inlinenumber<>in_atomic_dec) and
            (inlinenumber<>in_refcount_inc) and (inlinenumber<>in_refcount_dec)) or
           assigned(tcallparanode(left).right) or
           not is_integer(resultdef) or not(resultdef.size in [1,2,4,8]) then
          exit(inherited first_atomic);
        make_not_regable(tcallparanode(left).left,[ra_addr_regable]);
        expectloc:=LOC_REGISTER;
        result:=nil;
{$else}
        { Older ARM targets need the RTL's kuser/lock helpers. LLVM may emit
          external __sync_* calls that are not part of the Pascal runtime. }
        result:=inherited first_atomic;
{$endif}
      end;


    procedure tllvminlinenode.pass_generate_code_cpu;
      var
        target: tnode;
        address,increment,previous: tregister;
        op: topcg;
        helpername: TIDString;
        pd: tprocdef;
        argument,callresult: tcgpara;
        subtract: boolean;
        ordering: tllvmatomicordering;
      begin
        if ((inlinenumber<>in_atomic_inc) and (inlinenumber<>in_atomic_dec) and
            (inlinenumber<>in_refcount_inc) and (inlinenumber<>in_refcount_dec)) then
          begin
            inherited;
            exit;
          end;
        subtract:=(inlinenumber=in_atomic_dec) or (inlinenumber=in_refcount_dec);
        if (inlinenumber=in_refcount_inc) or (inlinenumber=in_refcount_dec) then
          { Match the RTL's relaxed reference-count operations without
            weakening the public atomic intrinsics. }
          ordering:=lao_monotonic
        else
          ordering:=lao_seq_cst;
        target:=tcallparanode(left).left;
        secondpass(target);
        if not(target.location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
          internalerror(2026100701);
        address:=hlcg.getaddressregister(current_asmdata.CurrAsmList,
          cpointerdef.getreusable(resultdef));
        hlcg.a_loadaddr_ref_reg(current_asmdata.CurrAsmList,resultdef,
          cpointerdef.getreusable(resultdef),target.location.reference,address);
        location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
        location.register:=hlcg.getintregister(current_asmdata.CurrAsmList,resultdef);
        if (target.location.reference.alignment<resultdef.size) or
           (target.location.reference.volatility<>[]) then
          begin
            { Keep the existing helper for unaligned or explicitly volatile
              storage; this atomicrmw fast path assumes natural alignment. }
            if subtract then
              helpername:='fpc_atomic_dec_'
            else
              helpername:='fpc_atomic_inc_';
            pd:=search_system_proc(helpername+tostr(resultdef.size*8));
            argument.init;
            paramanager.getcgtempparaloc(current_asmdata.CurrAsmList,pd,1,argument);
            hlcg.a_load_reg_cgpara(current_asmdata.CurrAsmList,
              cpointerdef.getreusable(resultdef),address,argument);
            paramanager.freecgpara(current_asmdata.CurrAsmList,argument);
            callresult:=hlcg.g_call_system_proc(current_asmdata.CurrAsmList,pd,[@argument],nil);
            hlcg.gen_load_cgpara_loc(current_asmdata.CurrAsmList,resultdef,callresult,location,false);
            callresult.resetiftemp;
            callresult.done;
            argument.done;
            exit;
          end;
        increment:=hlcg.getintregister(current_asmdata.CurrAsmList,resultdef);
        hlcg.a_load_const_reg(current_asmdata.CurrAsmList,resultdef,1,increment);
        previous:=hlcg.getintregister(current_asmdata.CurrAsmList,resultdef);
        current_asmdata.CurrAsmList.concat(taillvm.atomicrmw_reg_size_reg_reg(
          previous,resultdef,address,increment,subtract,ordering));
        if subtract then
          op:=OP_SUB
        else
          op:=OP_ADD;
        hlcg.a_op_const_reg_reg(current_asmdata.CurrAsmList,op,resultdef,1,
          previous,location.register);
      end;

     procedure tllvminlinenode.maybe_remove_round_trunc_typeconv;
       var
         temp: tnode;
       begin
         { the prototype of trunc()/round() in the system unit is declared
           with valreal as parameter type, so the argument will always be
           extended -> remove the typeconversion to extended if any; not done
           in ninl, because there are other code generators that assume that
           the parameter to trunc has been converted to valreal (e.g. PowerPC).

           (copy from code in nx64inl, should be refactored)
         }
         if (left.nodetype=typeconvn) and
            not(nf_explicit in left.flags) and
            (ttypeconvnode(left).left.resultdef.typ=floatdef) then
           begin
             { get rid of the type conversion, so the use_vectorfpu will be
               applied to the original type }
             temp:=ttypeconvnode(left).left;
             ttypeconvnode(left).left:=nil;
             left.free;
             left:=temp;
           end;
       end;


     function tllvminlinenode.first_get_frame: tnode;
       begin
         result:=ccallnode.createintern('llvm_frameaddress',
           ccallparanode.create(genintconstnode(0),nil));
       end;

    { in general, generate regular expression rather than intrinsics: according
      to the "Performance Tips for Frontend Authors", "The optimizer is quite
      good at reasoning about general control flow and arithmetic, it is not
      anywhere near as strong at reasoning about the various intrinsics. If
      profitable for code generation purposes, the optimizer will likely form
      the intrinsics itself late in the optimization pipeline." }

    function tllvminlinenode.first_abs_real: tnode;
      var
        argument: pnode;
        intrinsic: string[20];
      begin
        if left.nodetype=callparan then
          argument:=@tcallparanode(left).left
        else
          argument:=@left;
        case tfloatdef(argument^.resultdef).floattype of
          s32real:
            intrinsic:='llvm_fabs_f32';
          s64real:
            intrinsic:='llvm_fabs_f64';
          s80real,sc80real:
            intrinsic:='llvm_fabs_f80';
          s128real:
            intrinsic:='llvm_fabs_f128';
          else
            internalerror(2026100901);
        end;
        { Abs only clears the sign bit: it does not round, quiet NaNs, or raise
          floating-point exceptions. A comparison/negation also preserves -0
          and may raise invalid for a signaling NaN. }
        result:=ccallnode.createintern(intrinsic,
          ccallparanode.create(argument^,nil));
        argument^:=nil;
      end;


    function tllvminlinenode.first_bitscan: tnode;
      var
        leftdef: tdef;
        resulttemp,
        lefttemp: ttempcreatenode;
        stat: tstatementnode;
        block: tblocknode;
        cntresult: tnode;
        procname: string[15];
      begin
        {
          if left<>0 then
            result:=llvm_ctlz/cttz(unsigned(left),true)
          else
            result:=255;
        }
        if inlinenumber=in_bsr_x then
          procname:='LLVM_CTLZ'
        else
          procname:='LLVM_CTTZ';
        leftdef:=left.resultdef;
        block:=internalstatements(stat);
        resulttemp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,false);
        addstatement(stat,resulttemp);
        lefttemp:=maybereplacewithtemp(left,block,stat,left.resultdef.size,true);
        cntresult:=
          ccallnode.createintern(
            procname,
            ccallparanode.create(cordconstnode.create(1,llvmbool1type,false),
              ccallparanode.create(
                ctypeconvnode.create_explicit(left,get_unsigned_inttype(leftdef)),nil
              )
            )
          );
        { ctlz returns the number of leading zero bits, while bsr returns the bit
          number of the first non-zero bit (with the least significant bit as 0)
          -> invert result }
        if inlinenumber=in_bsr_x then
          begin
            cntresult:=
              caddnode.create(xorn,
                cntresult,
                genintconstnode(leftdef.size*8-1)
              );
          end;
        addstatement(stat,
          cifnode.create(caddnode.create(unequaln,left.getcopy,genintconstnode(0)),
            cassignmentnode.create(
              ctemprefnode.create(resulttemp),
              cntresult
            ),
            cassignmentnode.create(
              ctemprefnode.create(resulttemp),
              genintconstnode(255)
            )
          )
        );
        if assigned(lefttemp) then
          addstatement(stat,ctempdeletenode.create(lefttemp));
        addstatement(stat,ctempdeletenode.create_normal_temp(resulttemp));
        addstatement(stat,ctemprefnode.create(resulttemp));
        left:=nil;
        result:=block;
      end;


    function tllvminlinenode.first_fma: tnode;
      var
        exceptmode: ansistring;
        procname: string[40];
      begin
        if cs_opt_fastmath in current_settings.optimizerswitches then
          begin
            case inlinenumber of
              in_fma_single:
                procname:='llvm_fma_f32';
              in_fma_double:
                procname:='llvm_fma_f64';
              in_fma_extended:
                procname:='llvm_fma_f80';
              in_fma_float128:
                procname:='llvm_fma_f128';
              else
                internalerror(2018122101);
            end;
            result:=ccallnode.createintern(procname,left);
          end
        else
          begin
            case inlinenumber of
              in_fma_single,
              in_fma_double,
              in_fma_extended,
              in_fma_float128:
                procname:='LLVM_EXPERIMENTAL_CONSTRAINED_FMA';
              else
                internalerror(2019122811);
            end;
            exceptmode:=llvm_constrainedexceptmodestring;
            result:=ccallnode.createintern(procname,
              ccallparanode.create(cstringconstnode.createpchar(ansistring2pchar(exceptmode),length(exceptmode),llvm_metadatatype),
                ccallparanode.create(cstringconstnode.createpchar(ansistring2pchar('round.dynamic'),length('round.dynamic'),llvm_metadatatype),
                  left
                )
              )
            );
          end;
        left:=nil;
      end;


    function tllvminlinenode.first_sqr_real: tnode;
      begin
        result:=nil;
        if use_vectorfpu(left.resultdef) then
          expectloc:=LOC_MMREGISTER
        else
          expectloc:=LOC_FPUREGISTER;
      end;


    function tllvminlinenode.first_sqrt_real: tnode;
      var
        exceptmode,roundmode: ansistring;
        intrinsic: string[40];
      begin
        if left.resultdef.typ<>floatdef then
          internalerror(2018121601);
        if (cs_opt_fastmath in current_settings.optimizerswitches) and
           not(inf_pc24_lowered in inlinenodeflags) then
          begin
            case tfloatdef(left.resultdef).floattype of
              s32real:
                intrinsic:='llvm_sqrt_f32';
              s64real:
                intrinsic:='llvm_sqrt_f64';
              s80real,sc80real:
                intrinsic:='llvm_sqrt_f80';
              s128real:
                intrinsic:='llvm_sqrt_f128';
              else
                internalerror(2018121602);
            end;
            result:=ccallnode.createintern(intrinsic, ccallparanode.create(left,nil));
          end
        else
          begin
            case tfloatdef(left.resultdef).floattype of
              s32real,
              s64real,
              s80real,sc80real,
              s128real:
                intrinsic:='LLVM_EXPERIMENTAL_CONSTRAINED_SQRT';
              else
                internalerror(2019122810);
            end;
            exceptmode:=llvm_constrainedexceptmodestring;
            if inf_pc24_lowered in inlinenodeflags then
              roundmode:='round.tonearest'
            else
              roundmode:='round.dynamic';
            result:=ccallnode.createintern(intrinsic,
              ccallparanode.create(cstringconstnode.createpchar(ansistring2pchar(exceptmode),length(exceptmode),llvm_metadatatype),
                ccallparanode.create(cstringconstnode.createpchar(ansistring2pchar(roundmode),length(roundmode),llvm_metadatatype),
                  ccallparanode.create(left,nil)
                )
              )
            );
          end;
        left:=nil;
      end;


    function tllvminlinenode.lower_real_to_int64: tnode;
{$ifdef aarch64}
      var
        statements: tstatementnode;
        argumenttemp, resulttemp: ttempcreatenode;
        argument: pnode;
        bits, condition, fastcall, slowcall: tnode;
        callparameters: tcallparanode;
        intrinsic, helper: string;
{$endif aarch64}
      begin
        result:=nil;
{$ifdef aarch64}
        { These intrinsics match the AArch64 RTL's instructions and exception
          behavior. Retain the RTL path for other targets and older LLVM. }
        if current_settings.llvmversion<llvmver_17_0 then
          exit;
        if left.nodetype=callparan then
          argument:=@tcallparanode(left).left
        else
          argument:=@left;
        if not is_double(argument^.resultdef) then
          exit;
        result:=internalstatements(statements);
        argumenttemp:=ctempcreatenode.create(s64floattype,8,tt_persistent,true);
        resulttemp:=ctempcreatenode.create(s64inttype,8,tt_persistent,false);
        addstatement(statements,argumenttemp);
        addstatement(statements,resulttemp);
        addstatement(statements,cassignmentnode.create(ctemprefnode.create(argumenttemp),argument^));
        argument^:=nil;
        { Inspect the bits without raising an exception on a signaling NaN.
          |x|<2^63 excludes every invalid conversion. Its largest binary64
          value is 1024 below 2^63, so all rounding modes are safe. LLVM leaves
          invalid integer results unspecified; preserve the RTL fallback for
          those values, including the exactly representable -2^63 boundary. }
        bits:=cderefnode.create(ctypeconvnode.create_internal(
          caddrnode.create_internal(ctemprefnode.create(argumenttemp)),
          cpointerdef.getreusable(u64inttype)));
        condition:=caddnode.create(ltn,
          caddnode.create(andn,bits,cordconstnode.create(qword($7fffffffffffffff),u64inttype,false)),
          cordconstnode.create(qword($43e0000000000000),u64inttype,false));
        callparameters:=ccallparanode.create(ctemprefnode.create(argumenttemp),nil);
        if inlinenumber=in_round_real then
          begin
            intrinsic:='llvm_experimental_constrained_lrint_i64_f64';
            helper:='fpc_round_real';
            callparameters:=ccallparanode.create(cstringconstnode.createpchar(
              ansistring2pchar('round.dynamic'),length('round.dynamic'),llvm_metadatatype),callparameters);
          end
        else
          begin
            intrinsic:='llvm_experimental_constrained_fptosi_i64_f64';
            helper:='fpc_trunc_real';
          end;
        callparameters:=ccallparanode.create(cstringconstnode.createpchar(
          ansistring2pchar('fpexcept.strict'),length('fpexcept.strict'),llvm_metadatatype),callparameters);
        fastcall:=ccallnode.createintern(intrinsic,callparameters);
        include(tcallnode(fastcall).callnodeflags,cnf_check_fpu_exceptions);
        slowcall:=ccallnode.createintern(helper,
          ccallparanode.create(ctemprefnode.create(argumenttemp),nil));
        include(tcallnode(slowcall).callnodeflags,cnf_check_fpu_exceptions);
        addstatement(statements,cifnode.create(condition,
          cassignmentnode.create(ctemprefnode.create(resulttemp),fastcall),
          cassignmentnode.create(ctemprefnode.create(resulttemp),slowcall)));
        addstatement(statements,ctempdeletenode.create(argumenttemp));
        addstatement(statements,ctempdeletenode.create_normal_temp(resulttemp));
        addstatement(statements,ctemprefnode.create(resulttemp));
{$endif aarch64}
      end;


    function tllvminlinenode.first_round_real: tnode;
      begin
        result:=lower_real_to_int64;
        if not assigned(result) then
          result:=inherited;
      end;


    function tllvminlinenode.first_trunc_real: tnode;
      begin
        { Fast math already permits fptosi's undefined out-of-range result. }
        if cs_opt_fastmath in current_settings.optimizerswitches then
          begin
            maybe_remove_round_trunc_typeconv;
            expectloc:=LOC_REGISTER;
            result:=nil;
          end
        else
          begin
            result:=lower_real_to_int64;
            if not assigned(result) then
              result:=inherited;
          end;
      end;


    function tllvminlinenode.first_int_real: tnode;
{$ifdef aarch64}
      var
        argument: pnode;
{$endif aarch64}
      begin
{$ifdef aarch64}
        if left.nodetype=callparan then
          argument:=@tcallparanode(left).left
        else
          argument:=@left;
        if (current_settings.llvmversion>=llvmver_17_0) and
           is_double(argument^.resultdef) then
          begin
            { Like the RTL's FRINTZ, this rounds towards zero without raising
              inexact, while preserving invalid exceptions and NaN handling. }
            result:=ccallnode.createintern('llvm_experimental_constrained_trunc_f64',
              ccallparanode.create(cstringconstnode.createpchar(
                ansistring2pchar('fpexcept.strict'),length('fpexcept.strict'),llvm_metadatatype),
                ccallparanode.create(argument^,nil)));
            include(tcallnode(result).callnodeflags,cnf_check_fpu_exceptions);
            argument^:=nil;
            exit;
          end;
{$endif aarch64}
        result:=inherited;
      end;


    function tllvminlinenode.first_popcnt: tnode;
      begin
        result:=ctypeconvnode.create(ccallnode.createintern('LLVM_CTPOP', ccallparanode.create(left,nil)),resultdef);
        left:=nil;
      end;


    procedure tllvminlinenode.second_length;
      var
        hreg: tregister;
      begin
        second_high;
        { Dynamic arrays do not have their length attached but their maximum index }
        if is_dynamic_array(left.resultdef) then
          begin
            hreg:=hlcg.getintregister(current_asmdata.CurrAsmList,resultdef);
            hlcg.a_op_const_reg_reg(current_asmdata.CurrAsmList,OP_ADD,resultdef,1,location.register,hreg);
            location.register:=hreg;
          end;
      end;


    procedure tllvminlinenode.second_high;
      var
        lengthlab, nillab: tasmlabel;
        hregister: tregister;
        href: treference;
        lendef: tdef;
      begin
        secondpass(left);
        if is_shortstring(left.resultdef) then
         begin
            if not(left.location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              internalerror(2014080806);
           { typecast the shortstring reference into a length byte reference }
           location_reset_ref(location,left.location.loc,def_cgsize(resultdef),left.location.reference.alignment,left.location.reference.volatility);
           hregister:=hlcg.getaddressregister(current_asmdata.CurrAsmList,cpointerdef.getreusable(resultdef));
           hlcg.a_loadaddr_ref_reg(current_asmdata.CurrAsmList,left.resultdef,cpointerdef.getreusable(resultdef),left.location.reference,hregister);
           hlcg.reference_reset_base(location.reference,cpointerdef.getreusable(resultdef),hregister,0,left.location.reference.temppos,left.location.reference.alignment,left.location.reference.volatility);
         end
        else
         begin
           { length in ansi/wide strings and high in dynamic arrays is at offset
             -sizeof(sizeint), for widestrings it's at -4 }
           if is_widestring(left.resultdef) then
             lendef:=u32inttype
           else
             lendef:=ossinttype;
           hlcg.location_force_reg(current_asmdata.CurrAsmList,left.location,
             left.resultdef,cpointerdef.getreusable(lendef),true);
           current_asmdata.getjumplabel(nillab);
           current_asmdata.getjumplabel(lengthlab);
           hlcg.a_cmp_const_reg_label(current_asmdata.CurrAsmList,cpointerdef.getreusable(lendef),OC_EQ,0,left.location.register,nillab);
           { volatility of the ansistring/widestring refers to the volatility of the
             string pointer, not of the string data }
           hlcg.reference_reset_base(href,cpointerdef.getreusable(lendef),left.location.register,-lendef.size,ctempposinvalid,lendef.alignment,[]);
           hregister:=hlcg.getintregister(current_asmdata.CurrAsmList,resultdef);
           hlcg.a_load_ref_reg(current_asmdata.CurrAsmList,lendef,resultdef,href,hregister);
           if is_widestring(left.resultdef) then
             hlcg.a_op_const_reg(current_asmdata.CurrAsmList,OP_SHR,resultdef,1,hregister);
           hlcg.a_jmp_always(current_asmdata.CurrAsmList,lengthlab);

           hlcg.a_label(current_asmdata.CurrAsmList,nillab);
           if is_dynamic_array(left.resultdef) then
             hlcg.a_load_const_reg(current_asmdata.CurrAsmList,resultdef,-1,hregister)
           else
             hlcg.a_load_const_reg(current_asmdata.CurrAsmList,resultdef,0,hregister);

           hlcg.a_label(current_asmdata.CurrAsmList,lengthlab);
           location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
           location.register:=hregister;
         end;
      end;


    procedure tllvminlinenode.second_sqr_real;
      begin
        secondpass(left);
        { Consumers need the result size, in particular when converting an
          extended square to an SSE-sized argument on x86. }
        location_reset(location,expectloc,def_cgsize(resultdef));
        if expectloc=LOC_MMREGISTER then
          begin
            hlcg.location_force_mmregscalar(current_asmdata.CurrAsmList,left.location,left.resultdef,true);
            location.register:=hlcg.getmmregister(current_asmdata.CurrAsmList,resultdef);
          end
        else
          begin
            hlcg.location_force_fpureg(current_asmdata.CurrAsmList,left.location,left.resultdef,true);
            location.register:=hlcg.getfpuregister(current_asmdata.CurrAsmList,resultdef);
          end;
        current_asmdata.CurrAsmList.concat(
          taillvm.op_reg_size_reg_reg(la_fmul,
            location.register,resultdef,
            left.location.register,left.location.register
          )
        );
      end;


    procedure tllvminlinenode.second_trunc_real;
      begin
        secondpass(left);
        if use_vectorfpu(left.resultdef) then
          hlcg.location_force_mmregscalar(current_asmdata.CurrAsmList,left.location,left.resultdef,true)
        else
          hlcg.location_force_fpureg(current_asmdata.CurrAsmList,left.location,left.resultdef,true);
        location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
        location.register:=hlcg.getregisterfordef(current_asmdata.CurrAsmList,resultdef);
        current_asmdata.CurrAsmList.concat(
          taillvm.op_reg_size_reg_size(la_fptosi,location.register,left.resultdef,left.location.register,resultdef)
        );
      end;

begin
  cinlinenode:=tllvminlinenode;
end.

