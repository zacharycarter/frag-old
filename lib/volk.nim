import os,
       nimterop/cimport

cPlugin:
  import strutils

  proc onSymbol(sym: var Symbol) {.exportc, dynlib.} =
    sym.name = sym.name.strip(chars = {'_'})


    if sym.name == "VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES2_EXT":
      sym.name = "VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_2_EXT"
    elif sym.name == "VK_COLORSPACE_SRGB_NONLINEAR_KHR":
      sym.name = "VK_COLOR_SPACE_SRGB_NONLINEAR_KHR"

type
  VkInstance_T* = pointer
  VkPhysicalDevice_T* = pointer
  VkDevice_T* = pointer
  VkQueue_T* = pointer
  VkSemaphore_T* = pointer
  VkCommandBuffer_T* = pointer
  VkFence_T* = pointer
  VkDeviceMemory_T* = pointer
  VkBuffer_T* = pointer
  VkImage_T* = pointer
  VkEvent_T* = pointer
  VkQueryPool_T* = pointer
  VkBufferView_T* = pointer
  VkImageView_T* = pointer
  VkShaderModule_T* = pointer
  VkPipelineCache_T* = pointer
  VkPipelineLayout_T* = pointer
  VkRenderPass_T* = pointer
  VkPipeline_T* = pointer
  VkDescriptorSetLayout_T* = pointer
  VkSampler_T* = pointer
  VkDescriptorPool_T* = pointer
  VkDescriptorSet_T* = pointer
  VkFramebuffer_T* = pointer
  VkCommandPool_T* = pointer
  VkSamplerYcbcrConversion_T* = pointer
  VkDescriptorUpdateTemplate_T* = pointer
  VkSurfaceKHR_T* = pointer
  VkSwapchainKHR_T* = pointer
  VkDisplayKHR_T* = pointer
  VkDisplayModeKHR_T* = pointer
  VkDebugReportCallbackEXT_T* = pointer
  VkDebugUtilsMessengerEXT_T* = pointer
  VkValidationCacheEXT_T* = pointer
  VkAccelerationStructureKHR_T* = pointer
  VkPerformanceConfigurationINTEL_T* = pointer
  VkIndirectCommandsLayoutNV_T* = pointer
  VkPrivateDataSlotEXT_T* = pointer

template vkMakeVersion*(major, minor, patch: untyped): untyped =
  (((major) shl 22) or ((minor) shl 12) or (patch))

template vkVersionMajor*(version: untyped): untyped =
  ((uint32)(version) shr 22)

template vkVersionMinor*(version: untyped): untyped =
  (((uint32)(version) shr 12) and 0x000003FF)

template vkVersionPatch*(version: untyped): untyped =
  ((uint32)(version) and 0x00000FFF)

const vkApiVersion1_0* = vkMakeVersion(1, 0, 0)
const vkApiVersion1_1* = vkMakeVersion(1, 1, 0)
const vkApiVersion1_2* = vkMakeVersion(1, 2, 0)

cOverride:
  const
    VK_REMAINING_MIP_LEVELS* = (not 0'u32)
    VK_REMAINING_ARRAY_LAYERS* = (not 0'u32)
    VK_WHOLE_SIZE* = (not 0'u64)
    VK_ATTACHMENT_UNUSED* = (not 0'u32)
    VK_QUEUE_FAMILY_IGNORED* = (not 0'u32)
    VK_SUBPASS_EXTERNAL* = (not 0'u32)

{.passC: "-DVK_USE_PLATFORM_MACOS_MVK".}
{.passC: "-DVK_NO_PROTOTYPES".}

cIncludeDir("/Users/zacharycarter/Downloads/vk/macOS/include/")

cCompile(currentSourcePath.parentDir()/"volk/volk.c")
cImport(currentSourcePath.parentDir()/"volk/volk.h", recurse = true)
