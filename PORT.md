# Free Pascal for Space Rangers HD

FPC 3.3.1 based on upstream revision
[`c5f920a67ff3eb1b3d4ea0b7ef686ac44cd7c6b5`](https://github.com/fpc/FPCSource/commit/c5f920a67ff3eb1b3d4ea0b7ef686ac44cd7c6b5),
synced on 2026-10-08. The original upstream and Space Rangers commit histories
are retained. The upstream development repository is
[Free Pascal](https://gitlab.com/freepascal.org/fpc/source), with a
[GitHub mirror](https://github.com/fpc/FPCSource).

This repository retains the full upstream source tree. The game uses the
compiler, runtime library, and the `rtl-objpas`, `fcl-base`, `fcl-process`, and
`pthreads` packages.

## Local changes

- LLVM Win32 support (`i386-win32`) using LLVM-MinGW's Clang, LLD, compiler
  builtins and `libunwind.dll`. Register calls retain Delphi/FPC's EAX/EDX/ECX
  arguments and callee stack cleanup; cdecl, stdcall, Pascal calls, small
  record returns and binary80 Extended values use the native i386 ABI.
  SSE2 is the LLVM default and is recorded in bitcode so ordinary and LTO
  builds use the same floating-point instruction set. Older CPUs without SSE2
  are outside the validated configuration.
  Pascal exceptions use DWARF unwind tables and FPC's personality routine.
  Windows hardware faults enter that unwinder through a thread-local bridge;
  this does not make native SEH Pascal frames interchangeable with LLVM
  exception frames. Rebuild Pascal libraries with the same exception model
  when exceptions must cross their boundaries.
  EXE and DLL linking supports `-Aclang-llvm -XLL`, including `-Clflto` for
  both applications and the RTL. The personality routine is explicitly
  retained against PE section garbage collection after LTO.
  Keep the SDK's matching i686 `libunwind.dll` beside the executable and add
  both the SDK's target library directory and Clang builtins directory to
  the library search path. The compiler cycle accepts
  `LLVM=1 CPU_TARGET=i386 OS_TARGET=win32 CROSSINSTALL=1`.

- Native Windows hosts can build Win32 and Win64 LLVM programs with LLVM-MinGW.
  Executable lookup preserves dotted tool names such as `ld.lld.exe`, and the
  MinGW LLD response files use forward slashes for Windows paths. PE
  postprocessing skips sections without file padding, preserving exception
  tables when LLD merges BSS into `.data`, and reports successful writes
  correctly. The Win64 LLVM RTL links the C runtime and Clang builtins for
  compiler-generated memory and arithmetic helpers. LLD suppresses COFF and
  debug-directory timestamps so self-hosted compiler stages compare unchanged.

- The Win64 vectored exception handler passes unrecognized native exception
  codes, including MSVC C++ throws, to Windows and the originating library's
  handlers. Known hardware faults and Windows control-C status retain their
  Pascal translations; in-page I/O errors now map to `EAccessViolation`.
  See [Win64 LLVM exception compatibility](#win64-llvm-exception-compatibility)
  for why this fix is needed and how escaping foreign exceptions differ from
  standard FPC. The LLVM bridge copies the native exception
  record into `EExternal`, preserving the fault address and parameters. Custom
  `ErrorProc` hooks still run; delegating to the saved SysUtils handler retains
  the original fault details, including across nested faults and threads.

- Experimental Nintendo Switch LLVM target (`aarch64-switch`) using devkitA64
  and libnx/newlib. The RTL supports UTF-8 device paths such as `sdmc:/` and
  threading through `NxThreads`; put it first in a threaded program's `uses`
  clause. Dynamic loading, subprocesses, arbitrary thread suspension and
  thread priorities are unsupported. Timestamp updates are unsupported for
  handles and on the `sdmc:` filesystem. Applications must join their workers;
  unsafe or unverifiable loader returns terminate the process. Generic RTL make
  integration is pending.

- LLVM WebAssembly support for `wasm32-wasip1` and `wasm32-wasip1threads`:
  C-compatible calls, native Wasm exceptions, memory intrinsics, atomic
  operations and native thread-local storage. Use Clang and `wasm-ld` with
  native Wasm exception support; the standard compiler cycle accepts
  `LLVM=1 CPU_TARGET=wasm32`.
  LLVM WASI Preview 2 is not supported.

- The WASI RTL supports standalone programs and embedding in a host runtime.
  `FPC_WASM_EMBEDDED_RUNTIME` exposes `fpc_wasm_start` without a standalone
  entry point; `FPC_WASM_HOST_ALLOCATOR` uses the host's allocation primitives,
  and `FPC_WASM_SEPARATE_WASI_IMPORTS` separates Pascal's WASI imports from the
  host's own imports. With `FPC_WASM_EMSCRIPTEN`, the host initializes pthread
  TLS and a thread-manager unit supplies FPC's thread operations. Standalone
  builds include the Wasm unwind helper through the RTL make rules.

- LLVM Wasm fixes retain initialization/finalization functions and exact
  virtual-method signatures, lower bitpacked indexing correctly, and support
  the game's floating-point compatibility directives. WASI `DynLibs` reports
  unsupported dynamic loading through the standard API.

- Incremental compilation refreshes cached symbol references when a dependency
  is recompiled. LLVM also refreshes type references in pending interface
  initializers, including nested constants and procedure pointers. Regression
  coverage is part of the standard `tests/tppu` suite.

- `fpwidestring` UTF-8 case conversion excludes the terminating zero from
  the result length, preserving filenames and other strings passed to
  null-terminated APIs. Coverage is in `tests/test/units/fpwidestring`.

- `{$LEGACYPC24 ON/OFF}` selects 24-bit arithmetic and Delphi binary80 constant
  semantics while preserving declared storage types. It supports LLVM and the
  native ARM64, x86-64, i386 and Wasm32 backends. Native ARM requires
  double-precision VFP (VFPv2 or later). Single/Double expressions use hardware
  operations with corrections at rounding boundaries; native i386 arithmetic
  and x86 Extended operands use x87 helpers. Both Wasm backends use a software FMA
  for the residual corrections. The mode requires nearest-even rounding and
  `-OoNOFASTMATH`. It does not provide general x87 exception or transcendental
  emulation, or preserve x87's exponent range in the Single/Double paths.
  Constants and inline routines retain their defining unit's arithmetic mode.

- LLVM converts host floating-point values to binary80 before emitting x86
  Extended constants, including array and record initializers. This keeps
  ARM-hosted cross-compilers from writing Double bytes as Extended values
  (`compiler/llvm/llvmbase.pas`, `agllvm.pas`, `nllvmtcon.pas`).
  Under `LEGACYPC24`, expression literals retain their exact binary80 bits
  even when the build host's Extended type is Double, including exponents
  outside the binary64 range.

- `{$DELPHIORDER ON/OFF}` independently reproduces Delphi 2007 source scheduling
  rules for the game's original `{$O-}` build, while allowing FPC to optimize
  the resulting code. It covers real and integer operands, call arguments,
  ordinary scalar assignments and array indexing. Source scheduling information
  survives lowering, inlining and unit files; the target calling ABI is unchanged.
  Array scheduling uses the retained Delphi32 record layout, including packed
  and variant records, independently of the target's pointer size and alignment.
  Dynamic-array bounds retain Delphi's runtime-call demand, including hidden
  open-array bounds. Real conversions retain their saved-inline capture barriers
  when Extended and Double share a target representation. Scalar Math.Min/Max
  retain inline preparation information on Wasm as well as native targets.
  It is not a complete Delphi 2007 scheduler: argument ties and some shifts still
  depend on temporary x86 register availability, and general saved-inline,
  managed-assignment and exception-only ordering need separate treatment.

- `{$DELPHIINTEGER32 ON/OFF}` independently selects Delphi's 32-bit minimum
  integer arithmetic width. Explicit wider operands retain their width;
  overflow checks, range checks and mixed signedness remain supported. All
  three compatibility directives default to off and can be used separately.

- Native class VMTs contain immutable ancestry tables for constant-time class
  tests. Runtime-created VMTs without a table retain parent-chain lookup.
  This changes the class ABI: rebuild the compiler, RTL, packages and Pascal
  shared libraries together. The unit-file version rejects older PPUs.

- RTL build switches `FPC_USE_SIMPLE_RANDOM` and `FPC_USE_PC24_RANDOM` select
  Delphi's generator and PC24 random-result behavior. `FPC_USE_PC24_MATH` selects
  the corresponding rounding and algorithms in `Math`. These switches are
  opt-in and do not change ordinary RTL builds. Rebuild the compiler and RTL
  together when updating this fork's unit-file format.

- [LLVM assembly references](compiler/rautils.pas): record references to assembler
  routines and external aliases in `llvm.compiler.used`. Assembler routines are
  now LLVM functions containing inline assembly; excluding them let LTO delete
  startup and memory-fill helpers. External aliases need the same treatment for
  functions and variables. `tests/test/tllvmasmrefs.pp` reproduces all three cases.

- [LLVM Sqr](compiler/llvm/nllvminl.pas): initialize the complete result location,
  including its size, so narrowing an extended square to a Double argument
  does not try to allocate an 80-bit SSE register (internal error 200301231).

- [x86 Include/Exclude](compiler/x86/nx86inl.pas): adjust nonzero set bases
  using the converted bit-index register type. Using the original ordinal type
  after widening the register caused internal error 200306031 in Delphi-mode
  small sets (for example `set of 8..39`).

- [LLVM assembler targets](compiler/llvm/agllvm.pas): enable Android ARM64.
- [Android target](compiler/systems/i_android.pas): select LLVM's exception
  unwinding convention.
- [Exception runtime](rtl/inc/psabieh.inc): link Android's NDK libunwind.
- [Unwind tables](compiler/cfidwarf.pas): let LLVM generate frame information
  for its final machine code.
- [Android linker](compiler/systems/t_android.pas): use a section present in
  LLD's default linker script.

- iOS simulator LLVM triples include the version before `-simulator` on both
  ARM64 and Intel (`compiler/triplet.pas`). The Darwin linker reads the SDK version
  from `SDKSettings.json`, with a directory-name fallback for older SDKs, and uses
  `-platform_version` for modern iOS toolchains. Intel simulator libc imports use
  the unversioned 64-bit inode ABI; Intel macOS retains `$INODE64` aliases
  (`rtl/unix/oscdeclh.inc`).
- The Darwin linker also uses `-platform_version` for macOS SDKs 10.15 and newer
  and for LLD, recording the SDK version independently of the deployment target
  (`compiler/systems/t_darwin.pas`). Older Apple toolchains retain legacy flags.

## Win64 LLVM exception compatibility

Standard FPC's native Win64 backend uses Windows structured exception handling
(SEH) at Pascal stack frames. A called C++ library can throw and catch an
exception internally before the search reaches its Pascal caller. If an
otherwise unhandled Windows exception with an unrecognized code reaches a
matching Pascal handler, SysUtils translates it to `EExternalException` and `finally`
blocks run during unwinding. This behavior is correct for these cases; see
the [native SEH handler](rtl/win64/seh64.inc).

The Win64 LLVM port selected a different implementation in commit
`d7a1add5dd` (Win64 LLVM support): FPC's Itanium-style exception machinery,
adapted to Windows through LLVM-MinGW's `libunwind`. This matches the port's
LLVM-generated exception code. The recent logging and fault-record changes
did not switch exception models. See the [target flags](compiler/systems/i_win.pas)
and [libunwind adapter](rtl/inc/psabieh.inc).

That path reused FPC's older vectored fallback handler. Its catch-all converted
unrecognized error-severity Windows codes into runtime error 217 (`EControlC`).
Vectored handlers run before stack-based handlers, so this could intercept even
an MSVC C++ exception that a native library would catch itself. This premature
translation was incorrect and caused the game's native-library startup failure.
The pass-through fix removes that interception.

There is still a compatibility gap: libunwind's
[`_GCC_specific_handler`](https://github.com/llvm/llvm-project/blob/main/libunwind/src/Unwind-seh.cpp)
passes foreign Windows exceptions through without invoking Pascal handlers or
cleanup. For example, `Windows.RaiseException($E0000042, 0, 0, nil)` inside Pascal
`try/finally/except` is caught as `EExternalException` by native Win64 FPC with
SysUtils. In this LLVM port it bypasses those blocks and terminates the process
unless another native handler handles it. Ordinary Pascal exceptions and the
bridge's explicitly recognized hardware faults still run Pascal cleanup and
can be caught.

Passing unknown codes through fixes a real bug, but does not make the LLVM
port fully equivalent to native FPC. Matching native FPC requires support at
Pascal stack frames that preserves inner native handlers; restoring the global
vectored catch-all would reintroduce the startup bug. Recognized hardware faults
are still intercepted by the bridge even in native libraries, so native handlers
for those faults can still be preempted; that existing limitation is separate
from the unknown-code fix.

## Repository integration

[SpaceRangersHD_FPC](https://github.com/pakompom/SpaceRangersHD_FPC) pins this
repository at `vendor/fpc`. Its `tools/compiler.py` bootstraps the compiler and
stores the generated compiler and target runtimes in the game’s `.local/fpc/`.

The October 2026 sync advances this fork's PPU long version from 40 to 41 for
upstream's new symbol serialization. Rebuild the compiler, RTL, packages and
dependent Pascal code together; pre-sync and upstream PPUs are not compatible.
Upstream's new statement expressions and reordered operators are enabled by
Delphi mode. Record composition and type inquiry remain explicit mode switches.
The compatibility directives above remain independent. Ordinary `Math.Power`
uses upstream's new C99 boundary handling; `FPC_USE_PC24_MATH` retains the
Delphi 2007 behavior required by the game.

The fork also fixes upstream's LLVM handling of references typechecked before
a later anonymous function moves their variable into a nested frame. Such
references now use the final storage location. Coverage includes
[statement expressions](tests/test/tstatementexpr39.pp) and
[escaping closures with managed captures](tests/test/tllvmlatecapturer.pp).

The compiler uses the [GNU GPL v2](LICENSE). Runtime and package licenses are
included in their source directories, including the [runtime license](rtl/COPYING.txt)
and its [linking exception](rtl/COPYING.FPC), retained for the modified runtime.
