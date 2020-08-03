import intsets, sequtils, deques, locks, options,
       ../lib/glfw, ../lib/volk, ../lib/vma,
       containers, threading_primitives, utils

type
  CommandList = uint8

const
  BackBufferCount = 2'u32

  CommandListCount = 16'u8

  TimestampQueryCount = 1024.csize_t

  OcclusionQueryCount = 1024.csize_t

  requiredDebugExtensions = [VK_EXT_DEBUG_REPORT_EXTENSION_NAME, VK_EXT_DEBUG_UTILS_EXTENSION_NAME]

  requiredInstanceExtensions = [VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME]

  requiredDeviceExtensions = @[VK_KHR_SWAPCHAIN_EXTENSION_NAME]

type
  Format* = enum
    FORMAT_UNKNOWN, FORMAT_R32G32B32A32_FLOAT, FORMAT_R32G32B32A32_UINT,
    FORMAT_R32G32B32A32_SINT, FORMAT_R32G32B32_FLOAT, FORMAT_R32G32B32_UINT,
    FORMAT_R32G32B32_SINT, FORMAT_R16G16B16A16_FLOAT, FORMAT_R16G16B16A16_UNORM,
    FORMAT_R16G16B16A16_UINT, FORMAT_R16G16B16A16_SNORM, FORMAT_R16G16B16A16_SINT,
    FORMAT_R32G32_FLOAT, FORMAT_R32G32_UINT, FORMAT_R32G32_SINT, FORMAT_R32G8X24_TYPELESS, ##  depth + stencil (alias)
    FORMAT_D32_FLOAT_S8X24_UINT, ##  depth + stencil
    FORMAT_R10G10B10A2_UNORM, FORMAT_R10G10B10A2_UINT, FORMAT_R11G11B10_FLOAT,
    FORMAT_R8G8B8A8_UNORM, FORMAT_R8G8B8A8_UNORM_SRGB, FORMAT_R8G8B8A8_UINT,
    FORMAT_R8G8B8A8_SNORM, FORMAT_R8G8B8A8_SINT, FORMAT_B8G8R8A8_UNORM,
    FORMAT_B8G8R8A8_UNORM_SRGB, FORMAT_R16G16_FLOAT, FORMAT_R16G16_UNORM,
    FORMAT_R16G16_UINT, FORMAT_R16G16_SNORM, FORMAT_R16G16_SINT, FORMAT_R32_TYPELESS, ##  depth (alias)
    FORMAT_D32_FLOAT,         ##  depth
    FORMAT_R32_FLOAT, FORMAT_R32_UINT, FORMAT_R32_SINT, FORMAT_R24G8_TYPELESS, ##  depth + stencil (alias)
    FORMAT_D24_UNORM_S8_UINT, ##  depth + stencil
    FORMAT_R8G8_UNORM, FORMAT_R8G8_UINT, FORMAT_R8G8_SNORM, FORMAT_R8G8_SINT, FORMAT_R16_TYPELESS, ##  depth (alias)
    FORMAT_R16_FLOAT, FORMAT_D16_UNORM, ##  depth
    FORMAT_R16_UNORM, FORMAT_R16_UINT, FORMAT_R16_SNORM, FORMAT_R16_SINT,
    FORMAT_R8_UNORM, FORMAT_R8_UINT, FORMAT_R8_SNORM, FORMAT_R8_SINT,
    FORMAT_BC1_UNORM, FORMAT_BC1_UNORM_SRGB, FORMAT_BC2_UNORM,
    FORMAT_BC2_UNORM_SRGB, FORMAT_BC3_UNORM, FORMAT_BC3_UNORM_SRGB,
    FORMAT_BC4_UNORM, FORMAT_BC4_SNORM, FORMAT_BC5_UNORM, FORMAT_BC5_SNORM,
    FORMAT_BC6H_UF16, FORMAT_BC6H_SF16, FORMAT_BC7_UNORM, FORMAT_BC7_UNORM_SRGB

  QueueFamilyIndices = object
    graphicsFamily: int32
    presentFamily: int32
    copyFamily: int32

  SwapChainSupportDetails = object
    capabilities: VkSurfaceCapabilitiesKHR
    formats: seq[VkSurfaceFormatKHR]
    presentModes: seq[VkPresentModeKHR]

  AllocationHandler = ref object
    allocator: VmaAllocator
    device: VkDevice
    instance: VkInstance
    frameCount: uint64
    destroyerImageViews: Deque[tuple[imageView: VkImageView; frameCount: uint64]]
    destroyerRenderpasses: Deque[tuple[renderPass: VkRenderPass; frameCount: uint64]]
    destroyerFramebuffers: Deque[tuple[framebuffer: VkFramebuffer; frameCount: uint64]]

    freeTimestampQueries: ThreadSafeRingBuffer[TimestampQueryCount, uint32]
    freeOcclusionQueries: ThreadSafeRingBuffer[OcclusionQueryCount, uint32]

  FrameResources = object
    frameFence: VkFence
    commandPools: array[COMMANDLIST_COUNT, VkCommandPool]
    commandBuffers: array[COMMANDLIST_COUNT, VkCommandBuffer]

    copyQueue: VkQueue
    copyCommandPool: VkCommandPool
    copyCommandBuffer: VkCommandBuffer

    transitionCommandPool: VkCommandPool
    transitionCommandBuffer: VkCommandBuffer
    loadedImageTransitions: seq[VkImageMemoryBarrier]

  GraphicsDeviceState = object
    frameCount: uint64
    vSync: bool
    resolutionWidth: int32
    resolutionHeight: int32
    debugDevice: bool
    fullscreen: bool
    backBufferFormat: Format
    tessellationSupport: bool
    uavLoadFormatCommonSupport: bool
    renderTargetAndViewportArrayIndexWithoutGSSupport: bool
    uavLoadFormatR11G11B10Float: bool

    instance: VkInstance
    callback: VkDebugReportCallbackEXT
    surface: VkSurfaceKHR
    physicalDevice: VkPhysicalDevice
    device: VkDevice
    queueIndices: QueueFamilyIndices
    graphicsQueue: VkQueue
    presentQueue: VkQueue

    deviceProperties: VkPhysicalDeviceProperties
    deviceProperties2: VkPhysicalDeviceProperties2
    deviceProperties11: VkPhysicalDeviceVulkan11Properties
    deviceProperties12: VkPhysicalDeviceVulkan12Properties

    deviceFeatures2: VkPhysicalDeviceFeatures2
    deviceFeatures11: VkPhysicalDeviceVulkan11Features
    deviceFeatures12: VkPhysicalDeviceVulkan12Features

    imageAvailableSemaphore: VkSemaphore
    renderFinishedSemaphore: VkSemaphore

    swapChain: VkSwapchainKHR
    swapChainImageFormat: VkFormat
    swapChainExtent: VkExtent2D
    swapChainImageIndex: uint32
    swapChainImages: seq[VkImage]
    swapChainImageViews: seq[VkImageView]
    swapChainFramebuffers: seq[VkFramebuffer]

    defaultRenderPass: VkRenderPass

    nullBuffer: VkBuffer
    nullBufferAllocation: VmaAllocation
    nullBufferView: VkBufferView
    nullSampler: VkSampler
    nullImageAllocation1D: VmaAllocation
    nullImageAllocation2D: VmaAllocation
    nullImageAllocation3D: VmaAllocation
    nullImage1D: VkImage
    nullImage2D: VkImage
    nullImage3D: VkImage
    nullImageView1D: VkImageView
    nullImageView1DArray: VkImageView
    nullImageView2D: VkImageView
    nullImageView2DArray: VkImageView
    nullImageViewCube: VkImageView
    nullImageViewCubeArray: VkImageView
    nullImageView3D: VkImageView

    timestampFrequency: uint64
    queryPoolTimestamp: VkQueryPool
    queryPoolOcclusion: VkQueryPool
    initialQueryPoolReset: bool
    timestampsToReset: seq[uint32]
    occlusionsToReset: seq[uint32]    

    copyQueueLock: Lock
    copyQueueUse: bool
    copySema: VkSemaphore

    frames: array[BackBufferCount, FrameResources]

    allocationHandler: AllocationHandler

var
  state: GraphicsDeviceState
  validationLayers = ["VK_LAYER_KHRONOS_validation"]

proc convertFormat(value: Format): VkFormat =
  case value
  of FORMAT_UNKNOWN:
    return VK_FORMAT_UNDEFINED
  of FORMAT_R32G32B32A32_FLOAT:
    return VK_FORMAT_R32G32B32A32_SFLOAT
  of FORMAT_R32G32B32A32_UINT:
    return VK_FORMAT_R32G32B32A32_UINT
  of FORMAT_R32G32B32A32_SINT:
    return VK_FORMAT_R32G32B32A32_SINT
  of FORMAT_R32G32B32_FLOAT:
    return VK_FORMAT_R32G32B32_SFLOAT
  of FORMAT_R32G32B32_UINT:
    return VK_FORMAT_R32G32B32_UINT
  of FORMAT_R32G32B32_SINT:
    return VK_FORMAT_R32G32B32_SINT
  of FORMAT_R16G16B16A16_FLOAT:
    return VK_FORMAT_R16G16B16A16_SFLOAT
  of FORMAT_R16G16B16A16_UNORM:
    return VK_FORMAT_R16G16B16A16_UNORM
  of FORMAT_R16G16B16A16_UINT:
    return VK_FORMAT_R16G16B16A16_UINT
  of FORMAT_R16G16B16A16_SNORM:
    return VK_FORMAT_R16G16B16A16_SNORM
  of FORMAT_R16G16B16A16_SINT:
    return VK_FORMAT_R16G16B16A16_SINT
  of FORMAT_R32G32_FLOAT:
    return VK_FORMAT_R32G32_SFLOAT
  of FORMAT_R32G32_UINT:
    return VK_FORMAT_R32G32_UINT
  of FORMAT_R32G32_SINT:
    return VK_FORMAT_R32G32_SINT
  of FORMAT_R32G8X24_TYPELESS:
    return VK_FORMAT_D32_SFLOAT_S8_UINT
  of FORMAT_D32_FLOAT_S8X24_UINT:
    return VK_FORMAT_D32_SFLOAT_S8_UINT
  of FORMAT_R10G10B10A2_UNORM:
    return VK_FORMAT_A2B10G10R10_UNORM_PACK32
  of FORMAT_R10G10B10A2_UINT:
    return VK_FORMAT_A2B10G10R10_UINT_PACK32
  of FORMAT_R11G11B10_FLOAT:
    return VK_FORMAT_B10G11R11_UFLOAT_PACK32
  of FORMAT_R8G8B8A8_UNORM:
    return VK_FORMAT_R8G8B8A8_UNORM
  of FORMAT_R8G8B8A8_UNORM_SRGB:
    return VK_FORMAT_R8G8B8A8_SRGB
  of FORMAT_R8G8B8A8_UINT:
    return VK_FORMAT_R8G8B8A8_UINT
  of FORMAT_R8G8B8A8_SNORM:
    return VK_FORMAT_R8G8B8A8_SNORM
  of FORMAT_R8G8B8A8_SINT:
    return VK_FORMAT_R8G8B8A8_SINT
  of FORMAT_R16G16_FLOAT:
    return VK_FORMAT_R16G16_SFLOAT
  of FORMAT_R16G16_UNORM:
    return VK_FORMAT_R16G16_UNORM
  of FORMAT_R16G16_UINT:
    return VK_FORMAT_R16G16_UINT
  of FORMAT_R16G16_SNORM:
    return VK_FORMAT_R16G16_SNORM
  of FORMAT_R16G16_SINT:
    return VK_FORMAT_R16G16_SINT
  of FORMAT_R32_TYPELESS:
    return VK_FORMAT_D32_SFLOAT
  of FORMAT_D32_FLOAT:
    return VK_FORMAT_D32_SFLOAT
  of FORMAT_R32_FLOAT:
    return VK_FORMAT_R32_SFLOAT
  of FORMAT_R32_UINT:
    return VK_FORMAT_R32_UINT
  of FORMAT_R32_SINT:
    return VK_FORMAT_R32_SINT
  of FORMAT_R24G8_TYPELESS:
    return VK_FORMAT_D24_UNORM_S8_UINT
  of FORMAT_D24_UNORM_S8_UINT:
    return VK_FORMAT_D24_UNORM_S8_UINT
  of FORMAT_R8G8_UNORM:
    return VK_FORMAT_R8G8_UNORM
  of FORMAT_R8G8_UINT:
    return VK_FORMAT_R8G8_UINT
  of FORMAT_R8G8_SNORM:
    return VK_FORMAT_R8G8_SNORM
  of FORMAT_R8G8_SINT:
    return VK_FORMAT_R8G8_SINT
  of FORMAT_R16_TYPELESS:
    return VK_FORMAT_D16_UNORM
  of FORMAT_R16_FLOAT:
    return VK_FORMAT_R16_SFLOAT
  of FORMAT_D16_UNORM:
    return VK_FORMAT_D16_UNORM
  of FORMAT_R16_UNORM:
    return VK_FORMAT_R16_UNORM
  of FORMAT_R16_UINT:
    return VK_FORMAT_R16_UINT
  of FORMAT_R16_SNORM:
    return VK_FORMAT_R16_SNORM
  of FORMAT_R16_SINT:
    return VK_FORMAT_R16_SINT
  of FORMAT_R8_UNORM:
    return VK_FORMAT_R8_UNORM
  of FORMAT_R8_UINT:
    return VK_FORMAT_R8_UINT
  of FORMAT_R8_SNORM:
    return VK_FORMAT_R8_SNORM
  of FORMAT_R8_SINT:
    return VK_FORMAT_R8_SINT
  of FORMAT_BC1_UNORM:
    return VK_FORMAT_BC1_RGBA_UNORM_BLOCK
  of FORMAT_BC1_UNORM_SRGB:
    return VK_FORMAT_BC1_RGBA_SRGB_BLOCK
  of FORMAT_BC2_UNORM:
    return VK_FORMAT_BC2_UNORM_BLOCK
  of FORMAT_BC2_UNORM_SRGB:
    return VK_FORMAT_BC2_SRGB_BLOCK
  of FORMAT_BC3_UNORM:
    return VK_FORMAT_BC3_UNORM_BLOCK
  of FORMAT_BC3_UNORM_SRGB:
    return VK_FORMAT_BC3_SRGB_BLOCK
  of FORMAT_BC4_UNORM:
    return VK_FORMAT_BC4_UNORM_BLOCK
  of FORMAT_BC4_SNORM:
    return VK_FORMAT_BC4_SNORM_BLOCK
  of FORMAT_BC5_UNORM:
    return VK_FORMAT_BC5_UNORM_BLOCK
  of FORMAT_BC5_SNORM:
    return VK_FORMAT_BC5_SNORM_BLOCK
  of FORMAT_B8G8R8A8_UNORM:
    return VK_FORMAT_B8G8R8A8_UNORM
  of FORMAT_B8G8R8A8_UNORM_SRGB:
    return VK_FORMAT_B8G8R8A8_SRGB
  of FORMAT_BC6H_UF16:
    return VK_FORMAT_BC6H_UFLOAT_BLOCK
  of FORMAT_BC6H_SF16:
    return VK_FORMAT_BC6H_SFLOAT_BLOCK
  of FORMAT_BC7_UNORM:
    return VK_FORMAT_BC7_UNORM_BLOCK
  of FORMAT_BC7_UNORM_SRGB:
    return VK_FORMAT_BC7_SRGB_BLOCK
  return VK_FORMAT_UNDEFINED

proc debugCallback(flags: VkDebugReportFlagsEXT; objType: VkDebugReportObjectTypeEXT; obj: uint64;
                   location: csize_t; code: int32; layerPrefix: cstring; msg: cstring; userData: pointer): VkBool32 {.cdecl.} =
  echo "INSIDE DEBUG CALLBACK!"

proc init(qfi: var QueueFamilyIndices) =
  qfi.graphicsFamily = -1
  qfi.presentFamily = -1
  qfi.copyFamily = -1

proc isComplete(qfi: QueueFamilyIndices): bool =
  result = qfi.graphicsFamily >= 0 and qfi.presentFamily >= 0 and qfi.copyFamily >= 0

proc querySwapChainSupport(device: VkPhysicalDevice; surface: VkSurfaceKHR): SwapChainSupportDetails =
  var
    formatCount: uint32
    presentModeCount: uint32

  discard device.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(surface, result.capabilities.addr)

  discard device.vkGetPhysicalDeviceSurfaceFormatsKHR(surface, formatCount.addr, nil)
  if formatCount != 0'u32:
    result.formats.setLen(formatCount)
    discard device.vkGetPhysicalDeviceSurfaceFormatsKHR(surface, formatCount.addr, result.formats[0].addr)

  discard device.vkGetPhysicalDeviceSurfacePresentModesKHR(surface, presentModeCOunt.addr, nil)
  if presentModeCount != 0'u32:
    result.presentModes.setLen(presentModeCount)
    discard device.vkGetPhysicalDeviceSurfacePresentModesKHR(surface, presentModeCount.addr, result.presentModes[0].addr)

proc checkDeviceExtensionSupport(checkExtension: cstring; availableDeviceExtensions: seq[VkExtensionProperties]): bool =
  for x in availableDeviceExtensions:
    if cast[cstring](x.extensionName[0].unsafeAddr) == checkExtension:
      return true

proc findQueueFamilies(device: VkPhysicalDevice; surface: VkSurfaceKHR): QueueFamilyIndices =
  result.init()

  var queueFamilyCount = 0'u32
  device.vkGetPhysicalDeviceQueueFamilyProperties(queueFamilyCount.addr, nil)

  var queueFamilies = newSeq[VkQueueFamilyProperties](queueFamilyCount)
  device.vkGetPhysicalDeviceQueueFamilyProperties(queueFamilyCount.addr, queueFamilies[0].addr)

  var i = 0'u32
  for queueFamily in queueFamilies:
    var presentSupport = false.VkBool32
    discard device.vkGetPhysicalDeviceSurfaceSupportKHR(i, surface, presentSupport.addr)
    if result.presentFamily < 0 and queueFamily.queueCount > 0 and presentSupport.bool:
      result.presentFamily = i.int32

    if result.graphicsFamily < 0 and queueFamily.queueCount > 0 and (queueFamily.queueFlags.uint32 and VK_QUEUE_GRAPHICS_BIT.uint32) != 0'u32:
      result.graphicsFamily = i.int32

    if queueFamily.queueCount > 0 and (queueFamily.queueFlags.uint32 and VK_QUEUE_TRANSFER_BIT.uint32) != 0'u32:
      result.copyFamily = i.int32

    inc i

proc isSuitable(device: VkPhysicalDevice; surface: VkSurfaceKHR): bool =
  var
    extensionCount: uint32
    available: seq[VkExtensionProperties]
    swapChainSupport: SwapChainSupportDetails
    
  let indices = device.findQueueFamilies(surface)
  if not indices.isComplete():
    echo "indices not complete!"
    return false

  discard device.vkEnumerateDeviceExtensionProperties(nil, extensionCount.addr, nil)
  available.setLen(extensionCount)
  discard device.vkEnumerateDeviceExtensionProperties(nil, extensionCount.addr, available[0].addr)

  for x in requiredDeviceExtensions:
    if not x.checkDeviceExtensionSupport(available):
      echo "device extension unsupported"
      return false

  swapChainSupport = device.querySwapChainSupport(surface)

  result = swapChainSupport.formats.len != 0 and swapChainSupport.presentModes.len != 0

proc checkValidationLayerSupport(): bool =
  var
    layerCount: uint32 = 0
    layers: seq[VkLayerProperties]

  discard vkEnumerateInstanceLayerProperties(layerCount.addr, nil)
  layers.setLen(layerCount)
  discard vkEnumerateInstanceLayerProperties(layerCount.addr, layers[0].addr)

  for validate in validationLayers:
    var found = false
    for layer in layers:
      if layer.layerName.toString() == validate:
        found = true
        break
    if not found:
      return false

  result = true

proc getFrameResources(): FrameResources =
  result = state.frames[(state.frameCount mod BackBufferCount).uint32]

proc createBackBufferResources() =
  var
    valid: bool
    imageCount: uint32
    res: VkResult
    queueFamilyIndices: array[2, uint32]    
    swapChainSupport: SwapChainSupportDetails
    surfaceFormat: VkSurfaceFormatKHR
    createInfo: VkSwapchainCreateInfoKHR
    info: VkDebugUtilsObjectNameInfoEXT

    colorAttachment: VkAttachmentDescription
    colorAttachmentRef: VkAttachmentReference
    subpass: VkSubpassDescription
    renderPassInfo: VkRenderPassCreateInfo
    dependency: VkSubpassDependency

    attachments: array[1, VkImageView]

  swapChainSupport = state.physicalDevice.querySwapChainSupport(state.surface)

  surfaceFormat.format = convertFormat(state.backBufferFormat)

  for format in swapChainSupport.formats:
    if format.format == surfaceFormat.format:
      surfaceFormat = format
      valid = true
      break

  if not valid:
    surfaceFormat.format = VK_FORMAT_B8G8R8A8_UNORM
    surfaceFormat.colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
    state.backBufferFormat = FORMAT_B8G8R8A8_UNORM

  state.swapChainExtent.width = state.resolutionWidth.uint32
  state.swapChainExtent.height = state.resolutionHeight.uint32
  state.swapChainExtent.width = max(swapChainSupport.capabilities.minImageExtent.width,
                                    min(swapChainSupport.capabilities.maxImageExtent.width, state.swapChainExtent.width))
  state.swapChainExtent.height = max(swapChainSupport.capabilities.minImageExtent.height,
                                     min(swapChainSupport.capabilities.maxImageExtent.height, state.swapChainExtent.height))

  imageCount = BackBufferCount
  
  createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
  createInfo.surface = state.surface
  createInfo.minImageCount = imageCount
  createInfo.imageFormat = surfaceFormat.format
  createInfo.imageColorSpace = surfaceFormat.colorSpace
  createInfo.imageExtent = state.swapChainExtent
  createInfo.imageArrayLayers = 1
  createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.uint32 or VK_IMAGE_USAGE_TRANSFER_SRC_BIT.uint32

  queueFamilyIndices = [state.queueIndices.graphicsFamily.uint32, state.queueIndices.presentFamily.uint32]

  if state.queueIndices.graphicsFamily != state.queueIndices.presentFamily:
    createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT
    createInfo.queueFamilyIndexCount = 2
    createInfo.pQueueFamilyIndices = queueFamilyIndices[0].addr
  else:
    createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
    createInfo.queueFamilyIndexCount = 0
    createInfo.pQueueFamilyIndices = nil

  createInfo.preTransform = swapChainSupport.capabilities.currentTransform
  createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
  createInfo.presentMode = VK_PRESENT_MODE_FIFO_KHR
  if not state.vSync:
    for presentMode in swapChainSupport.presentModes:
      if presentMode == VK_PRESENT_MODE_IMMEDIATE_KHR:
        createInfo.presentMode = VK_PRESENT_MODE_IMMEDIATE_KHR
        break

  createInfo.clipped = VK_TRUE
  createInfo.oldSwapchain = state.swapChain

  res = state.device.vkCreateSwapchainKHR(createInfo.addr, nil, state.swapChain.addr)
  assert(res == VK_SUCCESS)

  if createInfo.oldSwapchain != nil:
    state.device.vkDestroySwapchainKHR(createInfo.oldSwapchain, nil)

  discard state.device.vkGetSwapchainImagesKHR(state.swapChain, imageCount.addr, nil)
  assert(BackbufferCount <= imageCount)
  state.swapChainImages.setLen(imageCount)
  discard state.device.vkGetSwapchainImagesKHR(state.swapChain, imageCount.addr, state.swapChainImages[0].addr)
  state.swapChainImageFormat = surfaceFormat.format

  info.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT
  info.pObjectName = "SWAPCHAIN"
  info.objectType = VK_OBJECT_TYPE_IMAGE
  for x in state.swapChainImages:
    info.objectHandle = cast[uint64](x)

    res = state.device.vkSetDebugUtilsObjectNameEXT(info.addr)
    assert(res == VK_SUCCESS)

  block:
    colorAttachment.format = state.swapChainImageFormat
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR

    colorAttachmentRef.attachment = 0
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
    subpass.colorAttachmentCount = 1
    subpass.pColorAttachments = colorAttachmentRef.addr

    renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
    renderPassInfo.attachmentCount = 1
    renderPassInfo.pAttachments = colorAttachment.addr
    renderPassInfo.subpassCount = 1
    renderPassInfo.pSubpasses = subpass.addr

    dependency.srcSubpass = VK_SUBPASS_EXTERNAL
    dependency.dstSubpass = 0
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.uint32
    dependency.srcAccessMask = 0
    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.uint32
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT.uint32 or VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT.uint32
    
    renderPassInfo.dependencyCount = 1
    renderPassInfo.pDependencies = dependency.addr

    if state.defaultRenderPass != nil:
      state.allocationHandler.destroyerRenderpasses.addLast((renderPass: state.defaultRenderPass, frameCount: state.allocationHandler.frameCount))
    res = state.device.vkCreateRenderPass(renderPassInfo.addr, nil, state.defaultRenderPass.addr)
    assert(res == VK_SUCCESS)

  state.swapChainImageViews.setLen(state.swapChainImages.len)
  state.swapChainFramebuffers.setLen(state.swapChainImages.len)
  for i in 0 ..< state.swapChainImages.len:
    var createInfo: VkImageViewCreateInfo
    createInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
    createInfo.image = state.swapChainImages[i]
    createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
    createInfo.format = state.swapChainImageFormat
    createInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY
    createInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY
    createInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY
    createInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY
    createInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.uint32
    createInfo.subresourceRange.baseMipLevel = 0
    createInfo.subresourceRange.levelCount = 1
    createInfo.subresourceRange.baseArrayLayer = 0
    createInfo.subresourceRange.layerCount = 1

    if state.swapChainImageViews[i] != nil:
      state.allocationHandler.destroyerImageViews.addLast((imageView: state.swapChainImageViews[i], frameCount: state.allocationHandler.frameCount))
    res = state.device.vkCreateImageView(createInfo.addr, nil, state.swapChainImageViews[i].addr)

    var
      attachments = [state.swapChainImageViews[i]]
      framebufferInfo: VkFramebufferCreateInfo

    framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
    framebufferInfo.renderPass = state.defaultRenderPass
    framebufferInfo.attachmentCount = 1
    framebufferInfo.pAttachments = attachments[0].addr
    framebufferInfo.width = state.swapChainExtent.width
    framebufferInfo.height = state.swapChainExtent.height
    framebufferInfo.layers = 1

    if state.swapChainFramebuffers[i] != nil:
      state.allocationHandler.destroyerFramebuffers.addLast((framebuffer: state.swapChainFramebuffers[i], frameCount: state.allocationHandler.frameCount))
    res = state.device.vkCreateFramebuffer(framebufferInfo.addr, nil, state.swapChainFramebuffers[i].addr)
    assert(res == VK_SUCCESS)

proc createVulkanGraphicsDevice*(window: ptr GLFWWindow) =
  assert(volkInitialize() == VK_SUCCESS)

  var
    res: VkResult
    extensionCount: uint32
    glfwExtensionCount: uint32
    deviceCount: uint32
    requiredExtensions: seq[string]
    extensionNames: cstringArray
    glfwRequiredExtensions: cstringArray
    enabledLayerNames: cstringArray
    extensionProperties: seq[VkExtensionProperties]
    devices: seq[VkPhysicalDevice]
    discrete: bool
    queueCreateInfos: seq[VkDeviceQueueCreateInfo]
    enabledDeviceExtensions: seq[cstring]
    availableDeviceExtensions: seq[VkExtensionProperties]
    formatProperties: VkFormatProperties
    allocatorInfo: VmaAllocatorCreateInfo
    queueFamilyIndices: QueueFamilyIndices

    uniqueQueueFamilies = initIntSet()
    queuePriority = 1.0'f32

    # Fil out application info
    appInfo = VkApplicationInfo(
      sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
      pApplicationName: "Frag Application",
      applicationVersion: vkMakeVersion(1, 0, 0),
      pEngineName: "Frag",
      engineVersion: vkMakeVersion(1, 0, 0),
      apiVersion: vkApiVersion1_2,
    )

  state.vSync = true
  state.backBufferFormat = FORMAT_R10G10B10A2_UNORM
  state.copyQueueLock.initLock()

  discard vkEnumerateInstanceExtensionProperties(nil, extensionCount.addr, nil)
  extensionProperties.setLen(extensionCount)
  discard vkEnumerateInstanceExtensionProperties(nil, extensionCount.addr, extensionProperties[0].addr)

  glfwRequiredExtensions = cast[cstringArray](glfwGetRequiredInstanceExtensions(glfwExtensionCount.addr))
  requiredExtensions = cstringArrayToSeq(glfwRequiredExtensions, glfwExtensionCount)
  requiredExtensions.add(requiredInstanceExtensions)

  if not checkValidationLayerSupport():
    echo "vulkan validation layer not available"
  else:
    requiredExtensions.add(requiredDebugExtensions)
  
  extensionNames = requiredExtensions.allocCStringArray()
  enabledLayerNames = validationLayers.allocCStringArray()

  defer:
    extensionNames.deallocCStringArray()
    enabledLayerNames.deallocCStringArray()

  block: # Create instance
    var createInfo = VkInstanceCreateInfo(
      sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      pApplicationInfo: appInfo.addr,
      enabledExtensionCount: requiredExtensions.len.uint32,
      ppEnabledExtensionNames: cast[ptr cstring](extensionNames),
      enabledLayerCount: 0,
    )

    createInfo.enabledLayerCount = validationLayers.len.uint32
    createInfo.ppEnabledLayerNames = cast[ptr cstring](enabledLayerNames)
    
    res = createInfo.addr.vkCreateInstance(nil, state.instance.addr)
    assert(res == VK_SUCCESS)
    state.instance.volkLoadInstance()

  block: # Register validation layer callback
    var createInfo = VkDebugReportCallbackCreateInfoEXT(
      sType: VK_STRUCTURE_TYPE_DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT,
      flags: VK_DEBUG_REPORT_ERROR_BIT_EXT.uint32 or VK_DEBUG_REPORT_WARNING_BIT_EXT.uint32,
      pfnCallback: debugCallback,
    )

    res = state.instance.vkCreateDebugReportCallbackEXT(createInfo.addr, nil, state.callback.addr)
    assert(res == VK_SUCCESS)

  block: # Surface creation
    res = state.instance.glfwCreateWindowSurface(window, nil, state.surface.addr)
    assert(res == VK_SUCCESS)

  block: # Enumerating and creating devices
    discard state.instance.vkEnumeratePhysicalDevices(deviceCount.addr, nil)

    if deviceCount == 0:
      assert(false)

    devices.setLen(deviceCount)
    discard state.instance.vkEnumeratePhysicalDevices(deviceCount.addr, devices[0].addr)

    state.deviceProperties2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2
    state.deviceProperties11.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES
    state.deviceProperties12.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES

    state.deviceProperties2.pNext = state.deviceProperties11.addr
    state.deviceProperties11.pNext = state.deviceProperties12.addr

    var props: VkPhysicalDeviceProperties
    for device in devices:
      if device.isSuitable(state.surface):
        device.vkGetPhysicalDeviceProperties(state.deviceProperties.addr)

        if state.deviceProperties.apiVersion >= vkApiVersion1_1 and volkGetInstanceVersion() >= vkApiVersion1_1:
          device.vkGetPhysicalDeviceProperties2(state.deviceProperties2.addr)
        else:
          device.vkGetPhysicalDeviceProperties2KHR(state.deviceProperties2.addr)

        discrete = state.deviceProperties2.properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
        if discrete or state.physicalDevice == nil:
          state.physicalDevice = device
          if discrete:
            break # if this is discrete GPU, look no further (prioritize discrete GPU)

    if state.physicalDevice == nil:
      assert(false)

    state.queueIndices.init()
    state.queueIndices = state.physicalDevice.findQueueFamilies(state.surface)
    
    uniqueQueueFamilies.incl(state.queueIndices.graphicsFamily)
    uniqueQueueFamilies.incl(state.queueIndices.presentFamily)
    uniqueQueueFamilies.incl(state.queueIndices.copyFamily)

    for queueFamily in uniqueQueueFamilies:
      var queueCreateInfo: VkDeviceQueueCreateInfo
      queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
      queueCreateInfo.queueFamilyIndex = queueFamily.uint32
      queueCreateInfo.queueCount = 1
      queueCreateInfo.pQueuePriorities = queuePriority.addr
      queueCreateInfos.add(queueCreateInfo)

    assert(state.deviceProperties2.properties.limits.timestampComputeAndGraphics == VK_TRUE)

    enabledDeviceExtensions = requiredDeviceExtensions.mapIt(it.cstring)
    discard state.physicalDevice.vkEnumerateDeviceExtensionProperties(nil, extensionCount.addr, nil)
    availableDeviceExtensions.setLen(extensionCount)
    discard state.physicalDevice.vkEnumerateDeviceExtensionProperties(nil, extensionCount.addr, availableDeviceExtensions[0].addr)

    if checkDeviceExtensionSupport(VK_KHR_SPIRV_1_4_EXTENSION_NAME, availableDeviceExtensions):
      enabledDeviceExtensions.add(VK_KHR_SPIRV_1_4_EXTENSION_NAME.cstring)

    state.deviceFeatures2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2
    state.deviceFeatures11.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES
    state.deviceFeatures12.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES

    state.deviceFeatures2.pNext = state.deviceFeatures11.addr
    state.deviceFeatures11.pNext = state.deviceFeatures12.addr

    state.physicalDevice.vkGetPhysicalDeviceFeatures2(state.deviceFeatures2.addr)

    assert(state.deviceFeatures2.features.imageCubeArray == VK_TRUE)
    assert(state.deviceFeatures2.features.independentBlend == VK_TRUE)
    assert(state.deviceFeatures2.features.samplerAnisotropy == VK_TRUE)
    assert(state.deviceFeatures2.features.shaderClipDistance == VK_TRUE)
    assert(state.deviceFeatures2.features.textureCompressionBC == VK_TRUE)
    assert(state.deviceFeatures2.features.occlusionQueryPrecise == VK_TRUE)
    state.tessellationSupport = state.deviceFeatures2.features.tessellationShader == VK_TRUE
    state.uavLoadFormatCommonSupport = state.deviceFeatures2.features.shaderStorageImageExtendedFormats == VK_TRUE
    state.renderTargetAndViewportArrayIndexWithoutGSSupport = true # let's hope for the best...

    state.physicalDevice.vkGetPhysicalDeviceFormatProperties(convertFormat(FORMAT_R11G11B10_FLOAT), formatProperties.addr)
    state.uavLoadFormatR11G11B10Float = (formatProperties.optimalTilingFeatures.uint32 and VK_FORMAT_FEATURE_STORAGE_IMAGE_BIT.uint32) != 0

    var createInfo: VkDeviceCreateInfo
    createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO

    createInfo.queueCreateInfoCount = queueCreateInfos.len.uint32
    createInfo.pQueueCreateInfos = queueCreateInfos[0].addr

    createInfo.pEnabledFeatures = nil
    createInfo.pNext = state.deviceFeatures2.addr

    createInfo.enabledExtensionCount = enabledDeviceExtensions.len.uint32
    createInfo.ppEnabledExtensionNames = enabledDeviceExtensions[0].addr

    createInfo.enabledLayerCount = validationLayers.len.uint32
    createInfo.ppEnabledLayerNames = cast[ptr cstring](enabledLayerNames)

    res = state.physicalDevice.vkCreateDevice(createInfo.addr, nil, state.device.addr)
    assert(res == VK_SUCCESS)
    state.device.volkLoadDevice()

    state.device.vkGetDeviceQueue(state.queueIndices.graphicsFamily.uint32, 0'u32, state.graphicsQueue.addr)
    state.device.vkGetDeviceQueue(state.queueIndices.presentFamily.uint32, 0'u32, state.presentQueue.addr)

  state.allocationHandler = new AllocationHandler
  state.allocationHandler.device = state.device
  state.allocationHandler.instance = state.instance

  # Initialize Vulkan Memory Allocator helper
  allocatorInfo.physicalDevice = state.physicalDevice
  allocatorInfo.device = state.device
  allocatorInfo.instance = state.instance
  if state.deviceFeatures12.bufferDeviceAddress.bool:
    allocatorInfo.flags = VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT.uint32
  res = allocatorInfo.addr.vmaCreateAllocator(state.allocationHandler.allocator.addr)
  assert(res == VK_SUCCESS)

  createBackBufferResources()

  queueFamilyIndices.init()
  queueFamilyIndices = state.physicalDevice.findQueueFamilies(state.surface)

  block: # Create frame resources
    for fr in 0 ..< BackBufferCount:
      block: # Fence
        var fenceInfo: VkFenceCreateInfo
        fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
        discard state.device.vkCreateFence(fenceInfo.addr, nil, state.frames[fr].frameFence.addr)

      block: # Create resources for transition command buffer
        var poolInfo: VkCommandPoolCreateInfo
        poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
        poolInfo.queueFamilyIndex = queueFamilyIndices.graphicsFamily.uint32
        poolInfo.flags = 0

        res = state.device.vkCreateCommandPool(poolInfo.addr, nil, state.frames[fr].transitionCommandPool.addr)
        assert(res == VK_SUCCESS)

        var commandBufferInfo: VkCommandBufferAllocateInfo
        commandBufferInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
        commandBufferInfo.commandBufferCount = 1
        commandBufferInfo.commandPool = state.frames[fr].transitionCommandPool
        commandBufferInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY

        res = state.device.vkAllocateCommandBuffers(commandBufferInfo.addr, state.frames[fr].transitionCommandBuffer.addr)
        assert(res == VK_SUCCESS)

        var beginInfo: VkCommandBufferBeginInfo
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.uint32
        beginInfo.pInheritanceInfo = nil

        res = state.frames[fr].transitionCommandBuffer.vkBeginCommandBuffer(beginInfo.addr)
        assert(res == VK_SUCCESS)

      block: # Create resources for copy (transfer) queue
        state.device.vkGetDeviceQueue(state.queueIndices.copyFamily.uint32, 0, state.frames[fr].copyQueue.addr)

        var poolInfo: VkCommandPoolCreateInfo
        poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
        poolInfo.queueFamilyIndex = queueFamilyIndices.copyFamily.uint32
        poolInfo.flags = 0

        res = state.device.vkCreateCommandPool(poolInfo.addr, nil, state.frames[fr].copyCommandPool.addr)
        assert(res == VK_SUCCESS)

        var commandBufferInfo: VkCommandBufferAllocateInfo
        commandBufferInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
        commandBufferInfo.commandBufferCount = 1
        commandBufferInfo.commandPool = state.frames[fr].copyCommandPool
        commandBufferInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY

        res = state.device.vkAllocateCommandBuffers(commandBufferInfo.addr, state.frames[fr].copyCommandBuffer.addr)
        assert(res == VK_SUCCESS)

        var beginInfo: VkCommandBufferBeginInfo
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.uint32
        beginInfo.pInheritanceInfo = nil

        res = state.frames[fr].copyCommandBuffer.vkBeginCommandBuffer(beginInfo.addr)
        assert(res == VK_SUCCESS)

  block: # Create semaphores
    var semaphoreInfo: VkSemaphoreCreateInfo
    semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO

    res = state.device.vkCreateSemaphore(semaphoreInfo.addr, nil, state.imageAvailableSemaphore.addr)
    assert(res == VK_SUCCESS)
    res = state.device.vkCreateSemaphore(semaphoreInfo.addr, nil, state.renderFinishedSemaphore.addr)
    assert(res == VK_SUCCESS)
    res = state.device.vkCreateSemaphore(semaphoreInfo.addr, nil, state.copySema.addr)
    assert(res == VK_SUCCESS)

  block: # Create default null descriptors
    var bufferInfo: VkBufferCreateInfo
    bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
    bufferInfo.size = 4
    bufferInfo.usage = VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT.uint32 or
                       VK_BUFFER_USAGE_UNIFORM_TEXEL_BUFFER_BIT.uint32 or
                       VK_BUFFER_USAGE_STORAGE_TEXEL_BUFFER_BIT.uint32 or
                       VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.uint32 or
                       VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.uint32
    bufferInfo.flags = 0

    var allocInfo: VmaAllocationCreateInfo
    allocInfo.usage = VMA_MEMORY_USAGE_GPU_ONLY

    res = state.allocationHandler.allocator.vmaCreateBuffer(bufferInfo.addr, allocInfo.addr,
                                                            state.nullBuffer.addr, state.nullBufferAllocation.addr, nil)
    assert(res == VK_SUCCESS)

    var viewInfo: VkBufferViewCreateInfo
    viewInfo.sType = VK_STRUCTURE_TYPE_BUFFER_VIEW_CREATE_INFO
    viewInfo.format = VK_FORMAT_R32G32B32A32_SFLOAT
    viewInfo.range = VK_WHOLE_SIZE
    viewInfo.buffer = state.nullBuffer
    res = state.device.vkCreateBufferView(viewInfo.addr, nil, state.nullBufferView.addr)
    assert(res == VK_SUCCESS)

  block:
    var imageInfo: VkImageCreateInfo
    imageInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
    imageInfo.extent.width = 1
    imageInfo.extent.height = 1
    imageInfo.extent.depth = 1
    imageInfo.format = VK_FORMAT_R8G8B8A8_UNORM
    imageInfo.arrayLayers = 1
    imageInfo.mipLevels = 1
    imageInfo.samples = VK_SAMPLE_COUNT_1_BIT
    imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    imageInfo.tiling = VK_IMAGE_TILING_OPTIMAL
    imageInfo.usage = VK_IMAGE_USAGE_SAMPLED_BIT.uint32 or VK_IMAGE_USAGE_STORAGE_BIT.uint32
    imageInfo.flags = 0

    var allocInfo: VmaAllocationCreateInfo
    allocInfo.usage = VMA_MEMORY_USAGE_GPU_ONLY

    imageInfo.imageType = VK_IMAGE_TYPE_1D
    res = state.allocationHandler.allocator.vmaCreateImage(imageInfo.addr, allocInfo.addr, state.nullImage1D.addr, state.nullImageAllocation1D.addr, nil)
    assert(res == VK_SUCCESS)

    imageInfo.imageType = VK_IMAGE_TYPE_2D
    imageInfo.flags = VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT.uint32
    imageInfo.arrayLayers = 6
    res = state.allocationHandler.allocator.vmaCreateImage(imageInfo.addr, allocInfo.addr, state.nullImage2D.addr, state.nullImageAllocation2D.addr, nil)
    assert(res == VK_SUCCESS)

    imageInfo.imageType = VK_IMAGE_TYPE_3D
    imageInfo.flags = 0
    imageInfo.arrayLayers = 1
    res = state.allocationHandler.allocator.vmaCreateImage(imageInfo.addr, allocInfo.addr, state.nullImage3D.addr, state.nullImageAllocation3D.addr, nil)
    assert(res == VK_SUCCESS)

    state.copyQueueLock.withLock:
      var frame = getFrameResources()
      if not state.copyQueueUse:
        state.copyQueueUse = true

        res = state.device.vkResetCommandPool(frame.copyCommandPool, 0)
        assert(res == VK_SUCCESS)

        var beginInfo: VkCommandBufferBeginInfo
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT.uint32
        beginInfo.pInheritanceInfo = nil

        res = frame.copyCommandBuffer.vkBeginCommandBuffer(beginInfo.addr)
        assert(res == VK_SUCCESS)

      var barrier: VkImageMemoryBarrier
      barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
      barrier.oldLayout = imageInfo.initialLayout
      barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL
      barrier.srcAccessMask = 0
      barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT.uint32 or VK_ACCESS_SHADER_WRITE_BIT.uint32
      barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.uint32
      barrier.subresourceRange.baseArrayLayer = 0
      barrier.subresourceRange.baseMipLevel = 0
      barrier.subresourceRange.levelCount = 1
      barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
      barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
      barrier.image = state.nullImage1D
      barrier.subresourceRange.layerCount = 1
      frame.loadedImageTransitions.add(barrier)
      barrier.image = state.nullImage2D
      barrier.subresourceRange.layerCount = 6
      frame.loadedImageTransitions.add(barrier)
      barrier.image = state.nullImage3D
      barrier.subresourceRange.layerCount = 1
      frame.loadedImageTransitions.add(barrier)

      var viewInfo: VkImageViewCreateInfo
      viewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
      viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.uint32
      viewInfo.subresourceRange.baseArrayLayer = 0
      viewInfo.subresourceRange.layerCount = 1
      viewInfo.subresourceRange.baseMipLevel = 0
      viewInfo.subresourceRange.levelCount = 1
      viewInfo.format = VK_FORMAT_R8G8B8A8_UNORM

      viewInfo.image = state.nullImage1D
      viewInfo.viewType = VK_IMAGE_VIEW_TYPE_1D
      res = state.device.vkCreateImageView(viewInfo.addr, nil, state.nullImageView1D.addr)
      assert(res == VK_SUCCESS)

      viewInfo.image = state.nullImage1D
      viewInfo.viewType = VK_IMAGE_VIEW_TYPE_1D_ARRAY
      res = state.device.vkCreateImageView(viewInfo.addr, nil, state.nullImageView1DArray.addr)
      assert(res == VK_SUCCESS)

      viewInfo.image = state.nullImage2D
      viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
      res = state.device.vkCreateImageView(viewInfo.addr, nil, state.nullImageView2D.addr)
      assert(res == VK_SUCCESS)

      viewInfo.image = state.nullImage2D
      viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D_ARRAY
      res = state.device.vkCreateImageView(viewInfo.addr, nil, state.nullImageView2DArray.addr)
      assert(res == VK_SUCCESS)

      viewInfo.image = state.nullImage2D
      viewInfo.viewType = VK_IMAGE_VIEW_TYPE_CUBE
      viewInfo.subresourceRange.layerCount = 6
      res = state.device.vkCreateImageView(viewInfo.addr, nil, state.nullImageViewCube.addr)
      assert(res == VK_SUCCESS)

      viewInfo.image = state.nullImage2D
      viewInfo.viewType = VK_IMAGE_VIEW_TYPE_CUBE_ARRAY
      viewInfo.subresourceRange.layerCount = 6
      res = state.device.vkCreateImageView(viewInfo.addr, nil, state.nullImageViewCubeArray.addr)
      assert(res == VK_SUCCESS)

      viewInfo.image = state.nullImage3D
      viewInfo.subresourceRange.layerCount = 1
      viewInfo.viewType = VK_IMAGE_VIEW_TYPE_3D
      res = state.device.vkCreateImageView(viewInfo.addr, nil, state.nullImageView3D.addr)
      assert(res == VK_SUCCESS)
    
    block:
      var createInfo: VkSamplerCreateInfo
      createInfo.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO

      res = state.device.vkCreateSampler(createInfo.addr, nil, state.nullSampler.addr)
      assert(res == VK_SUCCESS)

    block: # GPU Queries
      state.timestampFrequency = (1.0'f64 / state.deviceProperties2.properties.limits.timestampPeriod.float64 * 1000 * 1000 * 1000).uint64

      var poolInfo: VkQueryPoolCreateInfo
      poolInfo.sType = VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO

      for i in 0'u32 ..< TimestampQueryCount.uint32:
        discard state.allocationHandler.freeTimestampQueries.addLast(i)

      poolInfo.queryCount = TimestampQueryCount.uint32
      poolInfo.queryType = VK_QUERY_TYPE_TIMESTAMP
      res = state.device.vkCreateQueryPool(poolInfo.addr, nil, state.queryPoolTimestamp.addr)
      assert(res == VK_SUCCESS)
      state.timestampsToReset.setLen(TimestampQueryCount)

      for i in 0'u32 ..< OcclusionQueryCount.uint32:
        discard state.allocationHandler.freeOcclusionQueries.addLast(i)

      poolInfo.queryCount = OcclusionQueryCount.uint32
      poolInfo.queryType = VK_QUERY_TYPE_OCCLUSION
      res = state.device.vkCreateQueryPool(poolInfo.addr, nil, state.queryPoolOcclusion.addr)
      assert(res == VK_SUCCESS)
      state.occlusionsToReset.setLen(OcclusionQueryCount)

      
