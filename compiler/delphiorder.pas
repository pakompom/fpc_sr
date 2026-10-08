{ Delphi 2007 source operand scheduling. These demand scores describe source
  evaluation order, not the target CPU's registers. In particular, lowering an
  expression to a helper call must not replace its original demand with that of
  a call. Rules match the selected Delphi backend's expression preparation. }
unit delphiorder;
{$i fpcdefs.inc}

interface
uses node,globtype,symdef;

function delphi_source_demand(p: tnode): word;
function delphi_source_extended(p: tnode): boolean;
function delphi_left_first(left,right: tnode): boolean;
function delphi_saved_inline(p: tnode): boolean;
function delphi_has_inline_prefix(p: tnode): boolean;
function delphi_prefix_capturable(p: tnode): boolean;
function delphi_call_convention(pd: tabstractprocdef): tproccalloption;
procedure delphi_set_source_order(p: tnode; demand: word; extended_value: boolean;
  calllike: boolean = false);

implementation
uses symconst,symtype,symsym,defutil,compinnr,
  nld,ncal,ncnv,ninl,nutils,ncon;

function delphi_call_convention(pd: tabstractprocdef): tproccalloption;
begin
  if assigned(pd) and (pd.source_proccalloption<>pocall_none) then
    exit(pd.source_proccalloption);
  if not assigned(pd) or not(po_hascallingconvention in pd.procoptions) then
    exit(pocall_register);
  result:=pd.proccalloption;
end;

type
  tinline_shape = record
    result_symbol: tsym;
    conditions,assignments,selections: longint;
    invalid: boolean;
  end;
  pinline_shape = ^tinline_shape;

function inline_shape_node(var p: tnode; data: pointer): foreachnoderesult;
var shape: pinline_shape; target: tnode;
begin
  shape:=pinline_shape(data);
  case p.nodetype of
    ifn: inc(shape^.conditions);
    assignn:
      begin
        inc(shape^.assignments);
        target:=tbinarynode(p).left;
        while target.nodetype=typeconvn do target:=tunarynode(target).left;
        if (target.nodetype<>loadn) or
           (tloadnode(target).symtableentry<>shape^.result_symbol) then
          shape^.invalid:=true;
      end;
    inlinen:
      if tinlinenode(p).inlinenumber in
        [in_min_single,in_min_double,in_max_single,in_max_double,
         in_min_longint,in_min_dword,in_min_int64,in_min_qword,
         in_max_longint,in_max_dword,in_max_int64,in_max_qword] then
        inc(shape^.selections);
    forn,whilerepeatn,exitn,raisen,tryexceptn,tryfinallyn:
      shape^.invalid:=true;
    else
      ;
  end;
  result:=fen_false;
end;

function delphi_saved_inline(p: tnode): boolean;
var pd: tprocdef; shape: tinline_shape; code: tnode;
begin
  result:=false;
  if p.nodetype=inlinen then
    exit(tinlinenode(p).inlinenumber in
      [in_min_single,in_min_double,in_max_single,in_max_double,
       in_min_longint,in_min_dword,in_min_int64,in_min_qword,
       in_max_longint,in_max_dword,in_max_int64,in_max_qword]);
  if (p.nodetype<>calln) or not assigned(tcallnode(p).procdefinition) or
     (tcallnode(p).procdefinition.typ<>procdef) or
     not(po_inline in tcallnode(p).procdefinition.procoptions) then exit;
  pd:=tprocdef(tcallnode(p).procdefinition);
  if not pd.has_inlininginfo or not assigned(pd.inlininginfo) or
     not(is_ordinal(pd.returndef) or is_fpu(pd.returndef)) then exit;
  { Saved conditional scalar inlines have a statement result slot. This
    covers ordinary user helpers as well as Math.Min/Max, without names. }
  fillchar(shape,sizeof(shape),0);
  shape.result_symbol:=pd.funcretsym;
  code:=pd.inlininginfo^.code;
  foreachnodestatic(code,@inline_shape_node,@shape);
  result:=not shape.invalid and
    (((shape.conditions=1) and (shape.assignments=2)) or
     { FPC may already have replaced the conditional by a Min/Max intrinsic
       before writing this routine's inline tree to a PPU. }
     ((shape.conditions=0) and (shape.assignments=1) and (shape.selections=1)));
end;

function delphi_has_inline_prefix(p: tnode): boolean;
begin
  if not assigned(p) then exit(false);
  if delphi_saved_inline(p) then exit(true);
  { Existing statement regions keep their conditional/temporary lifetimes. }
  if p.nodetype in [blockn,statementn] then exit(false);
  result:=false;
  if p is tunarynode then result:=delphi_has_inline_prefix(tunarynode(p).left);
  if not result and (p is tbinarynode) then
    result:=delphi_has_inline_prefix(tbinarynode(p).right);
  if not result and (p is ttertiarynode) then
    result:=delphi_has_inline_prefix(ttertiarynode(p).third);
end;

function delphi_prefix_capturable(p: tnode): boolean;
begin
  { Calls and builtins may require prefix capture before a saved inline.
    Lowering carries this source classification independently of helper names. }
  if p.delphi_demand_valid then exit(p.delphi_calllike);
  result:=(p.nodetype=calln) or
    ((p.nodetype=inlinen) and
     (tinlinenode(p).inlinenumber in [in_abs_real,in_abs_long,in_sqr_real,
       in_sqrt_real,in_frac_real,in_round_real,in_trunc_real,
       in_copy_x,in_length_x]));
end;

function extra_integer(v: word): word;
begin result:=v or ((v+64) and $3c0); end;

function extra_byte(v: word): word;
begin result:=v or ((v+4) and $3c); end;

function static_address(p: tnode): boolean;
begin
  case p.nodetype of
    loadn:
      result:=not assigned(tloadnode(p).left) and
        not tloadnode(p).is_addr_param_load;
    subscriptn:
      result:=static_address(tunarynode(p).left);
    vecn:
      result:=is_constnode(tbinarynode(p).right) and
        static_address(tbinarynode(p).left);
    else result:=false;
  end;
end;

function delphi_source_extended(p: tnode): boolean;
begin
  if p.delphi_demand_valid then exit(p.delphi_extended);
  if (p.nodetype=typeconvn) and is_fpu(tunarynode(p).left.resultdef) then
    { Source real conversions retain the source operand's scheduling class.
      This concerns evaluation order only; explicit casts still round values. }
    exit(delphi_source_extended(tunarynode(p).left));
  result:=is_fpu(p.resultdef) and
    ((p.nodetype in [addn,subn,muln,slashn]) or
     ((p.nodetype=realconstn) and not(nf_explicit in p.flags)) or
     (tfloatdef(p.resultdef).floattype in [s80real,sc80real]) or
     (df_source_extended in p.resultdef.defoptions));
end;

function delphi_source_demand(p: tnode): word;
var a,b: word; para: tcallparanode; count: byte; divisor: cardinal;
begin
  if not assigned(p) then exit(0);
  if p.delphi_demand_valid then exit(p.delphi_demand);
  case p.nodetype of
    ordconstn,realconstn,pointerconstn,niln,stringconstn,setconstn,typen:
      exit(0);
    loadn:
      begin
        { Direct local/global real value slots have no address demand.
          nld attaches a parent-frame child to captured outer-scope loads. }
        if is_fpu(p.resultdef) and not assigned(tloadnode(p).left) and
          not tloadnode(p).is_addr_param_load then exit(0);
        exit($40);
      end;
    typeconvn:
      begin
        result:=delphi_source_demand(tunarynode(p).left);
        { Delphi 2007 scalar conversion demand.
          A narrowing scalar conversion needs an integer register, and a
          byte destination also constrains it to a byte-addressable register.
          In particular, a call converted to Byte is not a bare call when
          competing with another register argument. }
        if is_ordinal(p.resultdef) and is_ordinal(tunarynode(p).left.resultdef) and
          (p.resultdef.size<>tunarynode(p).left.resultdef.size) and
          not is_constnode(tunarynode(p).left) then
          begin
            result:=result or $40;
            if p.resultdef.size=1 then result:=result or 4;
            if (p.resultdef.size=8) or (tunarynode(p).left.resultdef.size=8) then
              result:=result or $c00;
          end;
        exit;
      end;
    calln:
      begin
        result:=$1c03; count:=0;
        para:=tcallparanode(tcallnode(p).left);
        while assigned(para) do
          begin
            if not assigned(para.parasym) or
              not(vo_is_hidden_para in para.parasym.varoptions) or
              (vo_is_high_para in para.parasym.varoptions) then
              begin
                result:=result or $44 or delphi_source_demand(para.left);
                if is_fpu(para.left.resultdef) and
                   not(assigned(para.parasym) and
                       (para.parasym.varspez in [vs_var,vs_out,vs_constref])) then
                  result:=result or $88
                else if count<3 then inc(count);
              end;
            para:=tcallparanode(para.right);
          end;
        if assigned(tcallnode(p).methodpointer) and
          (tcallnode(p).methodpointer.nodetype<>typen) then
          begin
            result:=result or $44 or delphi_source_demand(tcallnode(p).methodpointer);
            if count<3 then inc(count);
          end;
        { Delphi 2007 annotates the indirect target separately from arguments.
          Its address consumes another pressure slot even if the three
          source argument registers have already been accounted for. }
        b:=0;
        if assigned(tcallnode(p).right) then
          begin
            b:=delphi_source_demand(tcallnode(p).right);
            result:=result or b;
          end;
        if delphi_call_convention(tcallnode(p).procdefinition)=pocall_register then
          begin
            if b<>0 then inc(count);
            result:=result or ((64 shl count)-64);
          end;
        if assigned(tcallnode(p).right) then
          begin
            { The source i386 code pointer occupies four bytes; a bound
              method pointer also needs its Self half. Use the source kind,
              not the size of pointers on the compilation target. }
            result:=extra_integer(result);
            if not tcallnode(p).procdefinition.is_addressonly then
              result:=extra_integer(result);
          end;
        exit;
      end;
    inlinen:
      begin
        a:=delphi_source_demand(tunarynode(p).left);
        case tinlinenode(p).inlinenumber of
          in_abs_real,in_sqr_real,in_sqrt_real: exit(a or 1);
          in_round_real,in_trunc_real: exit(a or $1c03);
          in_abs_long: exit(a or $cc0);
          in_ord_x,in_low_x,in_high_x: exit(a);
          in_pi_real: exit(0);
          else
            if assigned(tunarynode(p).left) and is_fpu(tunarynode(p).left.resultdef) then
              exit(a or $1ccf)
            else exit(a or $1c43);
        end;
      end;
    subscriptn,derefn:
      exit(delphi_source_demand(tunarynode(p).left) or $40);
    addrn:
      exit(delphi_source_demand(tunarynode(p).left));
    unaryminusn,notn:
      begin
        result:=delphi_source_demand(tunarynode(p).left);
        if is_integer(p.resultdef) and (p.resultdef.size=8) then
          begin
            result:=result or $c00;
            if cs_check_overflow in p.localswitches then
              result:=extra_integer(result);
          end
        else
          begin
            result:=result or $40;
            if (p.resultdef.size=1) or (p.nodetype=notn) then
              result:=result or 4;
          end;
        exit;
      end;
    addn,subn,muln,slashn,divn,modn,shln,shrn,andn,orn,xorn,
    equaln,unequaln,ltn,lten,gtn,gten,vecn:
      begin
        a:=delphi_source_demand(tbinarynode(p).left);
        b:=delphi_source_demand(tbinarynode(p).right);
        if is_fpu(p.resultdef) and (p.nodetype in [addn,subn,muln,slashn]) then
          begin
            { Delphi 2007 prepares real multiply/divide operands through
              conversions even when they already are Extended. They add
              integer and FPU demand to the completed expression, although
              real arithmetic strips them when choosing its own operand
              order. Constant conversions fold before this preparation. }
            if p.nodetype in [muln,slashn] then
              begin
                if not is_constnode(tbinarynode(p).left) then
                  a:=a or $41;
                if not is_constnode(tbinarynode(p).right) then
                  b:=b or $41;
              end;
            exit(a or b or ((b+1) and 3));
          end;
        if ((is_integer(p.resultdef) and (p.resultdef.size=8)) or
            ((p.nodetype in [equaln,unequaln,ltn,lten,gtn,gten]) and
             is_integer(tbinarynode(p).left.resultdef) and
             (tbinarynode(p).left.resultdef.size=8))) then
          case p.nodetype of
            addn,subn,andn,orn,xorn,equaln,unequaln,ltn,lten,gtn,gten:
              begin
                { Delphi 2007 Int64 binary-operation demand. }
                result:=a or b or $c00;
                if not is_constnode(tbinarynode(p).left) and
                   not is_constnode(tbinarynode(p).right) then
                  result:=result or $40;
                exit;
              end;
            muln,divn,modn,shln,shrn:
              exit(a or b or $1c03);
            else
              ;
          end;
        case p.nodetype of
          divn,modn:
            begin
              { The scalar div/mod helper is unnecessary for a nonzero
                power-of-two immediate. Use the source i386
                width here, independently of the target's native integer. }
              result:=a or extra_integer(b);
              if p.resultdef.size=1 then result:=result or extra_byte(b);
              if tbinarynode(p).right.nodetype=ordconstn then
                begin
                  divisor:=cardinal(tordconstnode(tbinarynode(p).right).value.uvalue);
                  if (divisor<>0) and ((divisor and (divisor-1))=0) then
                    exit;
                end;
              result:=result or $c00;
              exit;
            end;
          shln,shrn:
            begin
              { Constant shift counts do not reserve ECX. }
              result:=a or extra_integer(b);
              if not is_constnode(tbinarynode(p).right) then
                result:=result or $10c0;
              if tbinarynode(p).left.resultdef.size=1 then
                begin
                  result:=result or extra_byte(b);
                  if not is_constnode(tbinarynode(p).right) then
                    result:=result or $c;
                end;
              exit;
            end;
          equaln,unequaln,ltn,lten,gtn,gten: exit(a or b or (((a and b)+1) and 3) or $444);
          vecn:
            begin
              { Delphi 2007 indexed-address demand includes the value load.
                Fixed array addresses and constant indices
                do not reserve the extra index/base register. }
              if is_normal_array(tbinarynode(p).left.resultdef) and
                 static_address(tbinarynode(p).left) then exit(b or $40);
              result:=a or b or $40;
              if not is_constnode(tbinarynode(p).right) or
                 not static_address(tbinarynode(p).left) then
                begin
                  result:=result or extra_integer(a and b);
                  if not is_constnode(tbinarynode(p).right) and
                     (((a and $40)<>0) or
                      (tbinarynode(p).left.nodetype=vecn)) then
                    result:=result or $80;
                end;
              exit;
            end;
          else
            begin
              if a<b then result:=a or b or extra_integer(a)
              else result:=a or b or extra_integer(b);
              if (p.nodetype=subn) and (a<b) then result:=result or $c0;
              if p.resultdef.size=1 then
                begin
                  if a<b then result:=result or extra_byte(a)
                  else result:=result or extra_byte(b);
                  if (p.nodetype=subn) and (a<b) then result:=result or $c;
                end;
              if (p.nodetype=muln) and (cs_check_overflow in p.localswitches) and
                 not is_signed(tbinarynode(p).left.resultdef) and
                 not is_signed(tbinarynode(p).right.resultdef) then
                result:=result or $c00;
              if is_integer(p.resultdef) and (p.resultdef.size=8) then result:=result or $c40;
              exit;
            end;
        end;
      end;
    temprefn: exit(0);
    else
      begin
        result:=0;
        if p is tunarynode then result:=delphi_source_demand(tunarynode(p).left);
        if p is tbinarynode then result:=result or delphi_source_demand(tbinarynode(p).right);
        if p is ttertiarynode then result:=result or delphi_source_demand(ttertiarynode(p).third);
      end;
  end;
end;

function delphi_left_first(left,right: tnode): boolean;
var a,b: word;
begin
  a:=delphi_source_demand(left); b:=delphi_source_demand(right);
  if (a or b)<$1c03 then begin a:=a and 3; b:=b and 3; end;
  result:=(a>b) or ((a=b) and
    (delphi_source_extended(left) or not delphi_source_extended(right)));
end;

procedure delphi_set_source_order(p: tnode; demand: word; extended_value: boolean;
  calllike: boolean);
begin
  if not(cs_delphi_order in p.localswitches) then exit;
  p.delphi_demand:=demand;
  p.delphi_extended:=extended_value;
  p.delphi_demand_valid:=true;
  p.delphi_calllike:=calllike;
end;

end.
