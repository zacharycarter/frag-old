import os,
       nimterop/cimport, strutils,
       volk

static:
  if not fileExists(currentSourcePath.parentDir()/"VulkanMemoryAllocator/src/vk_mem_alloc_sanitized.h"):
    var headerSrc = slurp(currentSourcePath.parentDir()/"VulkanMemoryAllocator/src/vk_mem_alloc.h")
    headerSrc = headerSrc.replace("""VMA_LEN_IF_NOT_NULL("VkPhysicalDeviceMemoryProperties::memoryHeapCount")""", "")
    headerSrc = headerSrc.replace("VMA_LEN_IF_NOT_NULL(allocationCount)", "")
    headerSrc = headerSrc.replace("VMA_LEN_IF_NOT_NULL(poolCount)", "")
    headerSrc = headerSrc.replace("VMA_LEN_IF_NOT_NULL(moveCount)", "")
    writeFile(currentSourcePath.parentDir()/"VulkanMemoryAllocator/src/vk_mem_alloc_sanitized.h", headerSrc)



type
  VmaAllocator_T = ptr int32
  VmaPool_T = ptr int32
  VmaAllocation_T = ptr int32
  VmaDefragmentationContext_T = ptr int32

{.link: currentSourcePath.parentDir()/"vma.o".}

cPlugin:
  import strutils

  proc onSymbol(sym: var Symbol) {.exportc, dynlib.} =
    sym.name = sym.name.strip(chars = {'_'})
        
    if sym.name == "VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES2_EXT":
      sym.name = "VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_2_EXT"
    elif sym.name == "VK_COLORSPACE_SRGB_NONLINEAR_KHR":
      sym.name = "VK_COLOR_SPACE_SRGB_NONLINEAR_KHR"

cDefine("VMA_NOT_NULL=")
cDefine("VMA_NULLABLE=")
cDefine("VMA_NOT_NULL_NON_DISPATCHABLE=")
cDefine("VMA_NULLABLE_NON_DISPATCHABLE=")
# cDefine("VMA_LEN_IF_NOT_NULL\\(len\\)=")

# cImport(currentSourcePath.parentDir()/"VulkanMemoryAllocator/src/vk_mem_alloc.h", recurse=true)
cImport(currentSourcePath.parentDir()/"VulkanMemoryAllocator/src/vk_mem_alloc_sanitized.h", recurse=true)

