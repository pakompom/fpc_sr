{ Compiler support for per-operation rounding to 24 significant bits. }
{$if (defined(CPULLVM) or defined(CPUAARCH64) or defined(UNIX)) and defined(SUPPORT_SINGLE) and defined(SUPPORT_DOUBLE)}
{$define FPC_HAS_PC24_HELPERS}
function fpc_pc24_add(a,b: Double): Single; compilerproc; inline;
function fpc_pc24_sub(a,b: Double): Single; compilerproc; inline;
function fpc_pc24_mul(a,b: Double): Single; compilerproc; inline;
function fpc_pc24_div(a,b: Double): Single; compilerproc; inline;
function fpc_pc24_sqr_single(a: Single): Single; compilerproc; inline;
function fpc_pc24_sqr(a: Double): Single; compilerproc; inline;
function fpc_pc24_sqrt(a: Double): Single; compilerproc; inline;
function fpc_pc24_exp(a: Double): Double; compilerproc;
function fpc_pc24_exp_reduced(a: Double): Double; compilerproc;
function fpc_pc24_add_tail(a,b,tail: Double): Single; compilerproc; inline;
function fpc_pc24_sub_tail(a,b,tail: Double): Single; compilerproc; inline;
function fpc_pc24_rsub_tail(a,b,tail: Double): Single; compilerproc; inline;
function fpc_pc24_mul_tail(a,b,tail: Double): Single; compilerproc; inline;
function fpc_pc24_div_tail(a,b,tail: Double): Single; compilerproc; inline;
function fpc_pc24_rdiv_tail(a,b,tail: Double): Single; compilerproc; inline;
function fpc_pc24_unrepresentable_equal(a: Double): Boolean; compilerproc; inline;
{$if defined(CPUX86_64) and defined(SUPPORT_EXTENDED)}
function fpc_pc24_add_extended(a,b: Extended): Extended; compilerproc;
function fpc_pc24_sub_extended(a,b: Extended): Extended; compilerproc;
function fpc_pc24_mul_extended(a,b: Extended): Extended; compilerproc;
function fpc_pc24_div_extended(a,b: Extended): Extended; compilerproc;
function fpc_pc24_sqr_extended(a: Extended): Extended; compilerproc;
function fpc_pc24_sqrt_extended(a: Extended): Extended; compilerproc;
function fpc_pc24_frac_extended(a: Extended): Extended; compilerproc;
{$endif}
{$if (defined(CPUX86_64) or defined(CPUI386)) and defined(SUPPORT_EXTENDED)}
function fpc_pc24_exp_extended(a: Extended): Extended; compilerproc;
{$endif}
{$endif}
