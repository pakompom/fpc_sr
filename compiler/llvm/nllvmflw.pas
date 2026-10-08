{
    Copyright (c) 2016 by Jonas Maebe

    Generate assembler for nodes that influence the flow for llvm

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
unit nllvmflw;

{$i fpcdefs.inc}

interface

    uses
      globtype,
      symtype,symdef,
      aasmbase,aasmdata,
      cgbase,
      node, nflw, ncgflw, ncgnstfl;

    type
      tllvmlabelnode = class(tcglabelnode)
        function getasmlabel: tasmlabel; override;
      end;

    tllvmtryexceptnode = class(tcgtryexceptnode)
    end;

    tllvmtryfinallynode = class(tcgtryfinallynode)
      function pass_1: tnode; override;
    end;

    tllvmraisenode = class(tcgraisenode)
      function pass_1: tnode; override;
      procedure pass_generate_code; override;
    end;


implementation

    uses
      systems,globals,verbose,
      symconst,symtable,symsym,llvmdef,defutil,ncon,
      pass_2,cgutils,hlcgobj,parabase,paramgr,tgobj,
      llvmbase,aasmtai,aasmllvm,
      procinfo,llvmpi;


{*****************************************************************************
                             SecondLabel
*****************************************************************************}

    function tllvmlabelnode.getasmlabel: tasmlabel;
      begin
        { don't allocate global labels even if the label is accessed from
          another routine: we always have to refer to such labels using the
          blockaddress() construct, which works with local labels too.
          Additionally, LLVM does not support defining global labels in the
          middle of a routine -> jumping to such a label from assembler code
          from another function will not work anyway (have to handle that by
          passing a blockaddress as argument to an assembler block, although
          "some targets may provide defined semantics when using the value as
          the operand to an inline assembly") }
        if not(assigned(asmlabel)) then
          current_asmdata.getjumplabel(asmlabel);
        result:=asmlabel
      end;


{*****************************************************************************
                          tllvmtryfinallynode
*****************************************************************************}

    function tllvmtryfinallynode.pass_1: tnode;
      begin
        { make a copy of the "finally" code for the "no exception happened"
          case }
        if not assigned(third) then
          third:=right.getcopy;
        result:=inherited;
      end;


{*****************************************************************************
                             tllvmraisenode
*****************************************************************************}

    function tllvmraisenode.pass_1: tnode;
      begin
        if assigned(left) then
          begin
{$ifdef wasm32}
            { Wasm has neither addressable instruction labels nor a native
              frame chain. Match the native Wasm raisenode, while preserving
              an explicitly supplied "raise ... at" address. }
            if not assigned(right) then
              begin
                right:=cpointerconstnode.create(0,voidcodepointertype);
                third:=cpointerconstnode.create(0,voidpointertype);
              end;
{$endif wasm32}
            result:=inherited;
          end
        else
          begin
            expectloc:=LOC_VOID;
            result:=nil;
          end;
      end;


    procedure tllvmraisenode.pass_generate_code;
      var
        currexceptlabel: tasmlabel;
      begin
        location_reset(location,LOC_VOID,OS_NO);
        currexceptlabel:=nil;
        { a reraise must raise the exception to the parent exception frame }
        if fc_catching_exceptions in flowcontrol then
          begin
            currexceptlabel:=tllvmprocinfo(current_procinfo).CurrExceptLabel;
            if tllvmprocinfo(current_procinfo).popexceptlabel(currexceptlabel) then
              exclude(flowcontrol,fc_catching_exceptions);
          end;
        hlcg.g_call_system_proc(current_asmdata.CurrAsmList,'fpc_reraise',[],nil).resetiftemp;
        if assigned(currexceptlabel) then
          begin
            tllvmprocinfo(current_procinfo).pushexceptlabel(currexceptlabel);
            include(flowcontrol,fc_catching_exceptions);
          end;
      end;


begin
  clabelnode:=tllvmlabelnode;
  ctryexceptnode:=tllvmtryexceptnode;
  ctryfinallynode:=tllvmtryfinallynode;
  craisenode:=tllvmraisenode;
end.

