/* libnx owns startup and loader return. See COPYING.FPC. */
#include <setjmp.h>
#include <stdlib.h>
#include <switch.h>

extern int fpc_nx_argc;
extern char **fpc_nx_argv;
extern void PASCALMAIN(void);
extern const size_t __stklen;

typedef struct {
  jmp_buf return_to_main;
  volatile int exit_code;
} MainContext;
static _Thread_local MainContext *active_main;
static LoaderReturnFn loader_return;
extern bool fpc_nx_thread_shutdown(void) __attribute__((weak));

static void finish_threads(void) {
  if (fpc_nx_thread_shutdown && !fpc_nx_thread_shutdown())
    svcExitProcess();
}

/* Run after native atexit handlers and libnx service cleanup, immediately
 * before hbloader could unmap this NRO. Kernel resource accounting covers
 * native/SDL threads as well as NxThreads, including native TLS teardown.
 * It may conservatively include shared resources or unclosed dead handles;
 * a failed/ambiguous query must terminate the process instead of unloading. */
static void __attribute__((noreturn)) return_to_loader(int code) {
  u64 resource;
  s64 count = 0;
  if (!envIsSyscallHinted(0x31) ||
      R_FAILED(svcGetInfo(&resource, InfoType_ResourceLimit, INVALID_HANDLE, 0)))
    svcExitProcess();
  Result rc = svcGetResourceLimitCurrentValue(&count, (Handle)resource,
                                              LimitableResource_Threads);
  Result close_rc = svcCloseHandle((Handle)resource);
  if (R_FAILED(rc) || R_FAILED(close_rc) || count != 1)
    svcExitProcess();
  loader_return(code);
}

/* System calls this after Pascal finalization. Return to the original C stack
 * before freeing the alternate mapping; libc exit then runs exactly once from
 * main, with libnx's original loader stack and thread metadata intact. */
void fpc_nx_exit(int code) {
  /* libnx's loader return is only valid on the original native main thread.
   * Halt is process-wide, including on a Pascal/foreign worker. Finalization
   * has already run; terminate without native atexit/loader return there. */
  if (threadGetSelf()->handle != envGetMainThreadHandle())
    svcExitProcess();
  if (active_main) {
    active_main->exit_code = code;
    longjmp(active_main->return_to_main, 1);
  }
  finish_threads();
  exit(code);
}

/* Keep Pascal on the native main thread: libnx's exit path restores the
 * loader's original stack pointer (__stack_top) and expects that thread/TLS.
 * The saved SP and LR live on the original stack; x19 survives Pascal calls. */
extern void fpc_nx_call_on_stack(void *top, void (*entry)(void));
__asm__(".text\n"
        ".p2align 2\n"
        ".global fpc_nx_call_on_stack\n"
#ifdef __ELF__
        ".type fpc_nx_call_on_stack, %function\n"
#endif
        "fpc_nx_call_on_stack:\n"
        ".cfi_startproc\n"
        "stp x19, x30, [sp, #-16]!\n"
        ".cfi_def_cfa_offset 16\n"
        ".cfi_offset 19, -16\n"
        ".cfi_offset 30, -8\n"
        "mov x19, sp\n"
        ".cfi_def_cfa 19, 16\n"
        "mov sp, x0\n"
        "blr x1\n"
        "mov sp, x19\n"
        ".cfi_def_cfa sp, 16\n"
        "ldp x19, x30, [sp], #16\n"
        ".cfi_def_cfa_offset 0\n"
        ".cfi_restore 19\n"
        ".cfi_restore 30\n"
        "ret\n"
        ".cfi_endproc\n"
#ifdef __ELF__
        ".size fpc_nx_call_on_stack, .-fpc_nx_call_on_stack\n"
#endif
);

uintptr_t fpc_nx_stack_low(void) {
  return (uintptr_t)threadGetSelf()->stack_mirror;
}
uintptr_t fpc_nx_stack_high(void) {
  return fpc_nx_stack_low() + threadGetSelf()->stack_sz;
}

/* Honour FPC's -Cs even when the homebrew loader supplies a smaller stack.
 * A custom C main must enter Pascal through this function as well. */
int fpc_nx_run(int argc, char **argv) {
  if (!envIsNso() && envGetExitFuncPtr() != return_to_loader) {
    loader_return = envGetExitFuncPtr();
    envSetExitFuncPtr(return_to_loader);
  }
  fpc_nx_argc = argc;
  fpc_nx_argv = argv;
  Thread *self = threadGetSelf();
  if (__stklen <= self->stack_sz) {
    PASCALMAIN();
    finish_threads();
    return 0;
  }

  if (__stklen > SIZE_MAX - 0xfff)
    diagAbortWithResult(MAKERESULT(Module_Libnx, LibnxError_BadInput));
  size_t size = (__stklen + 0xfff) & ~(size_t)0xfff;
  void *backing = aligned_alloc(0x1000, size);
  if (!backing)
    diagAbortWithResult(MAKERESULT(Module_Libnx, LibnxError_OutOfMemory));
  virtmemLock();
  void *stack = virtmemFindStack(size, 0x4000);
  Result rc = svcMapMemory(stack, backing, size);
  virtmemUnlock();
  if (R_FAILED(rc)) {
    free(backing);
    diagAbortWithResult(rc);
  }

  void *saved_stack = self->stack_mirror;
  size_t saved_size = self->stack_sz;
  self->stack_mirror = stack;
  self->stack_sz = size;
  MainContext context = {.exit_code = 0};
  active_main = &context;
  if (!setjmp(context.return_to_main))
    fpc_nx_call_on_stack((char *)stack + size, PASCALMAIN);
  active_main = NULL;
  finish_threads();
  self->stack_mirror = saved_stack;
  self->stack_sz = saved_size;
  rc = svcUnmapMemory(stack, backing, size);
  if (R_FAILED(rc))
    diagAbortWithResult(rc);
  free(backing);
  return context.exit_code;
}

__attribute__((weak)) int main(int argc, char **argv) {
  return fpc_nx_run(argc, argv);
}
