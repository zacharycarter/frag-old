import ../../lib/volk

proc init*(): bool =
  block:
    if volkInitialize() != VK_SUCCESS:
      echo "failed initializing volk"
      break

    result = true
