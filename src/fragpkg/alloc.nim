proc isPowerOfTwo*(n: int): bool {.inline.} =
  (n and (n - 1)) == 0

func roundNextMultipleOf*(x: Natural, n: Natural): int {.inline.} =
  assert isPowerOfTwo(n)
  result = (x + n - 1) and not(n - 1)

proc posix_memalign(mem: var pointer, alignment, size: csize_t){.sideeffect,importc, header:"<stdlib.h>".}
proc alignedAlloc(alignment, size: csize_t): pointer {.inline.} =
  posix_memalign(result, alignment, size)

proc allocAligned*(size: int; alignment: static Natural): pointer {.inline.} =
  static:
    assert isPowerOfTwo(alignment)

  let requiredMem = roundNextMultipleOf(size, alignment)
  result = alignedAlloc(csize_t(alignment), csize_t(requiredMem))
