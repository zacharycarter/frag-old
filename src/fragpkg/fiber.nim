import posix, math

{.link: "asm/make_combined_all_macho_gas.S.o".}
{.link: "asm/jump_combined_all_macho_gas.S.o".}
{.link: "asm/ontop_combined_all_macho_gas.S.o".}

type
  Fiber* = pointer

  FiberTransfer* = object
    prev*: Fiber
    userData*: pointer

  FiberStack* = object
    stack*: pointer
    stackSize: int

  FiberCb* = proc(transfer: FiberTransfer)

const
  defaultStackSize = 131072 # 120kb
  minStackSize* = 32768 # 32kb

proc jumpFContext(a: Fiber, b: pointer = nil): FiberTransfer {.importc: "jump_fcontext".}
proc makeFContext(a: pointer; b: csize_t; cb: FiberCb): Fiber {.importc: "make_fcontext".}

proc maxSize*(): int =
  var limit: RLimit
  discard getrlimit(3, limit)
  result = limit.rlim_max

proc pageSize*(): int =
  result = sysconf(SC_PAGESIZE)

proc fiberStackInit*(fStack: ptr FiberStack; size: int): bool =
  var
    ssize: int
    vp, sptr: pointer    
    desiredSize = size

  if desiredSize == 0:
    desiredSize = defaultStackSize
  desiredSize = max(desiredSize, minStackSize)

  let maxSize = maxSize()
  if maxSize > 0:
    desiredSize = min(desiredSize, maxSize)

  let pages = floor(float(desiredSize) / float(pageSize()))
  if pages < 2:
    return result

  let size2 = int(pages * float(pageSize()))
  assert(size2 != 0 and desiredSize != 0)
  assert(size2 <= desiredSize)

  vp = mmap(nil, size2, PROT_READ or PROT_WRITE, MAP_PRIVATE or MAP_ANONYMOUS, -1, 0)
  if vp == MAP_FAILED:
    return
  discard mprotect(vp, int(pageSize()), PROT_NONE)
    
  fStack.stack = cast[pointer](cast[uint](vp) + cast[uint](size2))
  fStack.stackSize = size2

proc fiberStackDestroy*(fStack: ptr FiberStack) =
  var vp = cast[pointer](cast[uint](fStack.stack) - cast[uint](fStack.stackSize))
  discard munmap(vp, fStack.stackSize)

proc fiberCreate*(fStack: FiberStack; cb: FiberCb): Fiber =
  result = makeFContext(fstack.stack, c_sizet(fstack.stackSize), cb)

proc fiberSwitch*(to: Fiber; userData: pointer): FiberTransfer =
  let frameState = getFrameState()
  result = jumpFContext(to, userData)
  setFrameState(frameState)
