proc mach_absolute_time(): uint64 {.importc, header: "<mach/mach.h>".}

proc cycleClock*(): uint64 =
  result = mach_absolute_time()
