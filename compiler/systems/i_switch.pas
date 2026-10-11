{ Nintendo Switch / libnx target. See COPYING for the compiler license. }
unit i_switch;
{$i fpcdefs.inc}
interface
uses systems;
const
system_aarch64_switch_info  : tsysteminfo =
           (
             system       : system_aarch64_switch;
             name         : 'Nintendo Switch for AArch64';
             shortname    : 'Switch';
             flags        : [tf_needs_symbol_size,tf_needs_symbol_type,tf_files_case_sensitive,
                             tf_requires_proper_alignment, tf_safecall_exceptions,
                             tf_pic_uses_got, tf_pic_default,
                             tf_smartlink_sections,tf_supports_hidden_symbols
                             {$ifdef llvm},tf_use_psabieh{$endif}];
             cpu          : cpu_aarch64;
             unit_env     : 'SWITCHUNITS';
             extradefines : '';
             exeext       : '.elf';
             defext       : '.def';
             scriptext    : '.sh';
             smartext     : '.sl';
             unitext      : '.ppu';
             unitlibext   : '.ppl';
             asmext       : '.s';
             objext       : '.o';
             resext       : '.res';
             resobjext    : '.or';
             sharedlibext : '.so';
             staticlibext : '.a';
             staticlibprefix : 'libp';
             sharedlibprefix : 'lib';
             sharedClibext : '.so';
             staticClibext : '.a';
             staticClibprefix : 'lib';
             sharedClibprefix : 'lib';
             importlibprefix : 'libimp';
             importlibext : '.a';
             Cprefix      : '';
             newline      : #10;
             dirsep       : '/';
             assem        : as_gas;
             assemextern  : as_gas;
             link         : ld_none;
             linkextern   : ld_switch;
             ar           : ar_gnu_ar;
             res          : res_none;
             dbg          : dbg_dwarf2;
             script       : script_unix;
             endian       : endian_little;
             { AAPCS64 natural alignment, including 16-byte SIMD/stack values.
               Procedure/loop alignment matches the AArch64 Linux target. }
             alignment    :
               (
                 procalign       : 8;
                 loopalign       : 4;
                 jumpalign       : 0;
                jumpalignskipmax    : 0;
                coalescealign   : 0;
                coalescealignskipmax: 0;
                 constalignmin   : 0;
                 constalignmax   : 16;
                 varalignmin     : 0;
                 varalignmax     : 16;
                 localalignmin   : 4;
                 localalignmax   : 16;
                 recordalignmin  : 0;
                 recordalignmax  : 16;
                 maxCrecordalign : 16
               );
             first_parm_offset : 16;
             stacksize    : 8*1024*1024;
             stackalign   : 16;
             abi : abi_default;
             llvmdatalayout : 'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-n32:64-S128'
           );
implementation
end.
