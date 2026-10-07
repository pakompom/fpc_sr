# Free Pascal for Space Rangers HD

FPC 3.3.1 based on upstream revision
[`00152d58c951b22a2a1165d18367c60d57c5abdd`](https://github.com/fpc/FPCSource/commit/00152d58c951b22a2a1165d18367c60d57c5abdd).
The original upstream commit history is retained; the Space Rangers fixes follow
that commit. The upstream development repository is
[Free Pascal](https://gitlab.com/freepascal.org/fpc/source), with a
[GitHub mirror](https://github.com/fpc/FPCSource).

This repository retains the full upstream source tree. The game uses the
compiler, runtime library, and the `rtl-objpas`, `fcl-base`, `fcl-process`, and
`pthreads` packages.

## Local changes

- `{$LEGACYPC24 ON/OFF}` selects 24-bit LLVM arithmetic and Delphi binary80
  constant semantics while preserving declared storage types. Single/Double
  expressions use hardware operations with corrections at rounding boundaries;
  native x86 Extended operands use x87 helpers. The mode requires nearest-even
  rounding and `-OoNOFASTMATH`. It does not provide general x87 exception or
  transcendental emulation, or wider exponents on targets without Extended.
  Constants and inline routines retain their defining unit's arithmetic mode.

- `{$DELPHIORDER ON/OFF}` independently selects Delphi 2007 operand and argument
  evaluation order. Source scheduling information survives lowering, inlining
  and unit files; the target calling ABI is unchanged.

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

[SpaceRangersHD_FPC](https://github.com/pakompom/SpaceRangersHD_FPC) pins this
repository at `vendor/fpc`. Its `tools/compiler.py` bootstraps the compiler and
stores the generated compiler and target runtimes in the game’s `.local/fpc/`.

The compiler uses the [GNU GPL v2](LICENSE). Runtime and package licenses are
included in their source directories, including the [runtime license](rtl/COPYING.txt)
and its [linking exception](rtl/COPYING.FPC), retained for the modified runtime.
