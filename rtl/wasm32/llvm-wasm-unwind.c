/*
 * This file is part of the Free Pascal run time library.
 * Copyright (c) 2026 by the Free Pascal development team.
 * See COPYING.FPC for copyright and licensing details.
 *
 * Minimal freestanding unwind ABI for LLVM-generated Pascal/WASI programs.
 *
 * WebAssembly performs the stack unwinding. FPC owns the exception object,
 * class matching, nesting and lifetime; this bridge only throws its ABI
 * header and invokes the header's cleanup callback. Do not link this object
 * alongside libunwind, which supplies the same canonical exception tag.
 * The bridge has no shared mutable state; per-thread exception state is
 * maintained by the Pascal RTL's threadvars.
 */
#include <stdint.h>

#if !defined(__wasm32__) || !defined(__WASM_EXCEPTIONS__)
#error "This bridge requires wasm32 with native WebAssembly exceptions"
#endif

struct unwind_exception;
typedef void (*exception_cleanup)(int, struct unwind_exception *);

struct unwind_exception {
  uint64_t exception_class;
  exception_cleanup cleanup;
};

_Static_assert(__builtin_offsetof(struct unwind_exception, cleanup) == 8,
               "FPC unwind exception cleanup ABI mismatch");

__asm__(".globl __cpp_exception\n"
        ".tagtype __cpp_exception i32\n"
        "__cpp_exception:\n");

int _Unwind_RaiseException(struct unwind_exception *exception) {
  __builtin_wasm_throw(0, exception);
}

void _Unwind_DeleteException(struct unwind_exception *exception) {
  if (exception->cleanup)
    exception->cleanup(1 /* _URC_FOREIGN_EXCEPTION_CAUGHT */, exception);
}
