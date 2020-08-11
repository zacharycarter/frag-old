import cpuinfo, atomics, locks, posix

type
  MachPort = distinct uint32

  SpinWait* = object
    count: int

  SpinLock* = object
    state: AtomicFlag

  Semaphore* = object
    cond: Cond
    lock: Lock
    count: int

const
  LockMaxTime* = 300
  MaxSpinCount = 10

let
  allowBusyWaiting = countProcessors() > 1

proc pthreadMachThreadNp(t: Pthread): MachPort {.cdecl, importc:"pthread_mach_thread_np", header:"pthread.h".}

proc threadTid*(): uint32 =
  result = uint32(cast[MachPort](pthreadMachThreadNp(pthreadSelf())))

proc isNextSpinYield*(self: SpinWait): bool {.inline.} =
  return self.count >= MaxSpinCount or not allowBusyWaiting

proc spinOnce*(self: var SpinWait) {.inline.} =
  if self.isNextSpinYield:
    cpuRelax()
  inc(self.count)

proc enter*(self: var SpinLock): bool {.inline.} =
  var wait: SpinWait
  while self.state.testAndSet(moAcquire):
    wait.spinOnce()
  return true

proc exit*(self: var SpinLock) {.inline.} =
  self.state.clear(moRelease)

template withLock*(self: var SpinLock; body: untyped): untyped =
  let isLockTaken = self.enter()
  try:
    body
  finally:
    if isLockTaken:
      self.exit()

proc semaphoreInit*(s: var Semaphore) =
  initCond(s.cond)
  initLock(s.lock)

proc `=destroy`*(s: var Semaphore) =
  deinitCond(s.cond)
  deinitLock(s.lock)
  s.count = 0

proc semaphoreWait*(s: var Semaphore) =
  withLock s.lock:
    while s.count <= 0:
      wait(s.cond, s.lock)
    dec s.count

proc semaphoreSignal*(s: var Semaphore) =
  withLock s.lock:
    inc s.count
  signal s.cond

proc semaphorePost*(s: var Semaphore; count: int) =
  for i in 0 ..< count:
    semaphoreSignal(s)
