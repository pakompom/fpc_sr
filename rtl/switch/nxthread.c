/* Free Pascal libnx threads and synchronization. See COPYING.FPC. */
#include <stdlib.h>
#include <switch.h>

/* FPC TLS is allocated with the C allocator before entering the Pascal heap. */
static int tls_slot = -1;
extern void fpc_nx_cleanup_thread(void);
static void tls_cleanup(void *data) {
  threadTlsSet(tls_slot, data);
  fpc_nx_cleanup_thread();
}
int fpc_nx_tls_init(void) { return tls_slot = threadTlsAlloc(tls_cleanup); }
void *fpc_nx_tls_get(void) { return threadTlsGet(tls_slot); }
void fpc_nx_tls_set(void *p) { threadTlsSet(tls_slot, p); }

typedef struct NxThread {
  Thread
      thread; /* Must be first: GetCurrentThreadID and returned handle agree. */
  void *(*entry)(void *);
  void *arg;
  uint32_t result;
  struct NxThread *next_closed;
} NxThread;
static _Thread_local NxThread *current_thread;

/* libnx has no detach operation and cannot free a thread's own stack. A
 * single C worker reaps handles closed while still running (FreeOnTerminate).
 * It never enters Pascal or allocates Pascal threadvars. */
static Mutex closed_mutex;
static CondVar closed_cond;
static NxThread *closed_threads;
static Thread reaper;
static bool reaper_started;
static bool reaper_stopping;

/* Horizon time-slices priority 0x3b on application cores. Use the process's
 * permitted cores rather than pinning every Pascal worker to its default core.
 * Native SDL/audio threads retain their own scheduling policy. */
static Result create_worker(Thread *thread, ThreadFunc entry, void *arg,
                            size_t stack_size) {
  u64 cores;
  Result rc = svcGetInfo(&cores, InfoType_CoreMask, CUR_PROCESS_HANDLE, 0);
  if (R_FAILED(rc))
    return rc;
  cores &=
      7; /* Application cores 0..2; core 3 has a different timeslice policy. */
  if (!cores)
    return MAKERESULT(Module_Libnx, LibnxError_BadInput);
  int preferred = __builtin_ctzll(cores);
  rc = threadCreate(thread, entry, arg, NULL, stack_size, 0x3b, preferred);
  if (R_SUCCEEDED(rc)) {
    rc = svcSetThreadCoreMask(thread->handle, preferred, (u32)cores);
    if (R_FAILED(rc))
      threadClose(thread);
  }
  return rc;
}

static void reap_threads(void *arg) {
  (void)arg;
  for (;;) {
    mutexLock(&closed_mutex);
    while (!closed_threads && !reaper_stopping)
      condvarWait(&closed_cond, &closed_mutex);
    NxThread **pending = &closed_threads;
    while (*pending) {
      NxThread *t = *pending;
      Result rc = waitSingle(waiterForThread(&t->thread), 0);
      if (R_VALUE(rc) == KERNELRESULT(TimedOut)) {
        pending = &t->next_closed;
        continue;
      }
      if (R_SUCCEEDED(rc))
        rc = threadClose(&t->thread);
      if (R_FAILED(rc))
        diagAbortWithResult(rc);
      *pending = t->next_closed;
      free(t);
    }
    if (reaper_stopping) {
      mutexUnlock(&closed_mutex);
      return;
    }
    /* An early close may precede exit indefinitely. Never join that worker
     * before examining the others. Native termination (including TLS cleanup)
     * is authoritative; poll only while detached live handles remain. */
    if (closed_threads)
      condvarWaitTimeout(&closed_cond, &closed_mutex, 10000000);
    mutexUnlock(&closed_mutex);
  }
}

static void run_thread(void *arg) {
  NxThread *t = arg;
  current_thread = t;
  t->result = (uintptr_t)t->entry(t->arg);
}
void *fpc_nx_thread_begin(void *(*entry)(void *), void *arg,
                          size_t stack_size) {
  /* libnx maps stacks in 4 KiB pages; reject overflow before rounding. */
  if (stack_size > SIZE_MAX - 4095)
    return NULL;
  NxThread *t = calloc(1, sizeof(*t));
  if (!t)
    return NULL;
  t->entry = entry;
  t->arg = arg;
  if (!stack_size)
    stack_size = 4 * 1024 * 1024;
  stack_size = (stack_size + 4095) & ~(size_t)4095;
  Result rc = create_worker(&t->thread, run_thread, t, stack_size);
  if (R_FAILED(rc)) {
    free(t);
    return NULL;
  }
  rc = threadStart(&t->thread);
  if (R_FAILED(rc)) {
    threadClose(&t->thread);
    free(t);
    return NULL;
  }
  return t;
}
void *fpc_nx_thread_self(void) { return threadGetSelf(); }
void fpc_nx_thread_exit(uint32_t code) {
  /* Foreign threads and the main thread only have libnx's Thread structure. */
  if (current_thread)
    current_thread->result = code;
  threadExit();
}
uint32_t fpc_nx_thread_wait(NxThread *t, int32_t ms) {
  Result rc = waitSingle(waiterForThread(&t->thread),
                         ms <= 0 ? UINT64_MAX : (uint64_t)ms * 1000000);
  return R_SUCCEEDED(rc) ? t->result : UINT32_MAX;
}
uint32_t fpc_nx_thread_close(NxThread *t) {
  Result rc = waitSingle(waiterForThread(&t->thread), 0);
  if (R_SUCCEEDED(rc)) {
    rc = threadClose(&t->thread);
    if (R_FAILED(rc))
      return UINT32_MAX;
    free(t);
    return 0;
  }
  if (R_VALUE(rc) != KERNELRESULT(TimedOut))
    return UINT32_MAX;

  mutexLock(&closed_mutex);
  if (reaper_stopping) {
    mutexUnlock(&closed_mutex);
    return UINT32_MAX;
  }
  if (!reaper_started) {
    rc = create_worker(&reaper, reap_threads, NULL, 64 * 1024);
    if (R_SUCCEEDED(rc)) {
      rc = threadStart(&reaper);
      if (R_FAILED(rc))
        threadClose(&reaper);
    }
    if (R_FAILED(rc)) {
      mutexUnlock(&closed_mutex);
      return UINT32_MAX;
    }
    reaper_started = true;
  }
  t->next_closed = closed_threads;
  closed_threads = t;
  condvarWakeOne(&closed_cond);
  mutexUnlock(&closed_mutex);
  return 0;
}

/* Called by main after Pascal finalization. Only the reaper can be asked to
 * stop; arbitrary user workers require application cooperation. Do not block
 * shutdown on them, or treat returning from their Pascal entry as native exit. */
bool fpc_nx_thread_shutdown(void) {
  mutexLock(&closed_mutex);
  reaper_stopping = true;
  bool started = reaper_started;
  condvarWakeOne(&closed_cond);
  mutexUnlock(&closed_mutex);
  if (started) {
    Result rc = waitSingle(waiterForThread(&reaper), 1000000000);
    if (R_FAILED(rc) || R_FAILED(threadClose(&reaper)))
      return false;
  }
  mutexLock(&closed_mutex);
  reaper_started = false;
  bool drained = closed_threads == NULL;
  mutexUnlock(&closed_mutex);
  return drained;
}

void fpc_nx_thread_yield(void) { svcSleepThread(0); }
_Static_assert(sizeof(RMutex) <= 32,
               "TRTLCriticalSection storage is too small");
void fpc_nx_mutex_init(void *cs) { rmutexInit(cs); }
void fpc_nx_mutex_lock(void *cs) { rmutexLock(cs); }
void fpc_nx_mutex_unlock(void *cs) { rmutexUnlock(cs); }
int fpc_nx_mutex_trylock(void *cs) { return rmutexTryLock(cs); }
void *fpc_nx_event_create(int manual, int signaled) {
  UEvent *event = malloc(sizeof(*event));
  if (!event)
    return NULL;
  ueventCreate(event, !manual);
  if (signaled)
    ueventSignal(event);
  return event;
}
void fpc_nx_event_destroy(UEvent *event) { free(event); }
void fpc_nx_event_set(UEvent *event) { ueventSignal(event); }
void fpc_nx_event_reset(UEvent *event) { ueventClear(event); }
int fpc_nx_event_wait(UEvent *event, uint32_t ms) {
  Result rc =
      waitSingle(waiterForUEvent(event),
                 ms == UINT32_MAX ? UINT64_MAX : (uint64_t)ms * 1000000);
  return R_SUCCEEDED(rc) ? 0 : (rc == KERNELRESULT(TimedOut) ? 1 : 3);
}
