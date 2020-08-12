import cstrutils, sets, options, os, streams,
       ../../lib/[glfw, volk]

type
  SwapChainSupportDetails = object
    capabilities: VkSurfaceCapabilitiesKHR
    formats: seq[VkSurfaceFormatKHR]
    presentModes: seq[VkPresentModeKHR]

  QueueFamilyIndices = object
    graphicsFamily: Option[uint32]
    presentFamily: Option[uint32]

  VulkanState = object
    instance: VkInstance
    debugMessenger: VkDebugUtilsMessengerEXT
    surface: VkSurfaceKHR

    physicalDevice: VkPhysicalDevice
    device: VkDevice

    graphicsQueue: VkQueue
    presentQueue: VkQueue

    swapChain: VkSwapchainKHR
    swapChainImages: seq[VkImage]
    swapChainImageFormat: VkFormat
    swapChainExtent: VkExtent2D
    swapChainImageViews: seq[VkImageView]
    swapChainFramebuffers: seq[VkFramebuffer]

    renderPass: VkRenderPass
    pipelineLayout: VkPipelineLayout
    graphicsPipeline: VkPipeline

    commandPool: VkCommandPool
    commandBuffers: seq[VkCommandBuffer]

    imageAvailableSemaphores: seq[VkSemaphore]
    renderFinishedSemaphores: seq[VkSemaphore]
    inFlightFences: seq[VkFence]
    imagesInFlight: seq[VkFence]

    currentFrame: int
    
  GfxState = object
    vk: VulkanState

when defined(danger) or defined(release):
  const enableValidationLayers = false
else:
  const enableValidationLayers = true

const maxFramesInFlight = 2

var
  gGfx: GfxState

  validationLayers = [
    cstring("VK_LAYER_KHRONOS_validation")
  ]

  deviceExtensions = [
    cstring(VK_KHR_SWAPCHAIN_EXTENSION_NAME)
  ]

proc isComplete(qfi: QueueFamilyIndices): bool =
  result = isSome(qfi.graphicsFamily) and isSome(qfi.presentFamily)

when enableValidationLayers:
  proc debugCallback(messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT; messageType: VkDebugUtilsMessageTypeFlagsEXT;
                     pCallbackData: ptr VkDebugUtilsMessengerCallbackDataEXT;  pUserData: pointer): VkBool32 {.cdecl.} =
    echo "validation layer: ", pCallbackData.pMessage

  proc populateDebugMessengerCreateInfo(createInfo: var VkDebugUtilsMessengerCreateInfoEXT) =
    createInfo.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
    createInfo.messageSeverity = uint32(VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT) or uint32(VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) or uint32(VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT)
    createInfo.messageType = uint32(VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT) or uint32(VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT) or uint32(VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT)
    createInfo.pfnUserCallback = debugCallback
  
  proc checkValidationLayerSupport(): bool =
    block check:
      var layerCount: uint32
      discard vkEnumerateInstanceLayerProperties(addr(layerCount), nil)

      var availableLayers = newSeq[VkLayerProperties](layerCount)
      discard vkEnumerateInstanceLayerProperties(addr(layerCount), addr(availableLayers[0]))

      for layerName in validationLayers:
        var layerFound = false

        for layerProperties in availableLayers.mItems:
          if cmpIgnoreStyle(layerName, cast[cstring](addr(layerProperties.layerName[0]))) == 0:
            layerFound = true
            break

        if not layerFound:
          break check

      result = true

proc getRequiredExtensions(): seq[cstring] =
  var
    glfwExtensionCount: uint32
    glfwExtensions: ptr UncheckedArray[cstring]

  glfwExtensions = cast[ptr UncheckedArray[cstring]](glfwGetRequiredInstanceExtensions(addr(glfwExtensionCount)))
  assert(glfwExtensionCount > 0, "failed retrieving required glfw instance extensions")

  add(result, toOpenArray(glfwExtensions, 0, int(glfwExtensionCount) - 1))

  when enableValidationLayers:
    add(result, VK_EXT_DEBUG_UTILS_EXTENSION_NAME)

proc createInstance() =
  when enableValidationLayers:
    assert(checkValidationLayerSupport(), "validation layers requested but not available")

  var appInfo = VkApplicationInfo(
    sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
    pApplicationName: "Hello Triangle",
    applicationVersion: vkMakeVersion(1, 0, 0),
    pEngineName: "Frag",
    engineVersion: vkMakeVersion(1, 0, 0),
    apiVersion: vkApiVersion1_2
  )

  var createInfo = VkInstanceCreateInfo(
    sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    pApplicationInfo: addr(appInfo)
  )

  var extensions = getRequiredExtensions()
  createInfo.enabledExtensionCount = uint32(len(extensions))
  createInfo.ppEnabledExtensionNames = addr(extensions[0])

  var debugCreateInfo: VkDebugUtilsMessengerCreateInfoEXT
  when enableValidationLayers:
    createInfo.enabledLayerCount = uint32(len(validationLayers))
    createInfo.ppEnabledLayerNames = addr(validationLayers[0])

    populateDebugMessengerCreateInfo(debugCreateInfo)
    createInfo.pNext = addr(debugCreateInfo)

  else:
    createInfo.enabledLayerCount = 0

    createInfo.pNext = nil

  assert(vkCreateInstance(addr(createInfo), nil, addr(gGfx.vk.instance)) == VK_SUCCESS,
         "failed creating vulkan instance")

proc setupDebugMessenger() =
  var createInfo: VkDebugUtilsMessengerCreateInfoEXT
  populateDebugMessengerCreateInfo(createInfo)

  assert(vkCreateDebugUtilsMessengerEXT(gGfx.vk.instance, addr(createInfo), nil, addr(gGfx.vk.debugMessenger)) == VK_SUCCESS,
         "failed setting up debug messenger")

proc createSurface(window: ptr GLFWwindow) =
  assert(glfwCreateWindowSurface(gGfx.vk.instance, window, nil, addr(gGfx.vk.surface)) == VK_SUCCESS,
         "failed creating window surface")

proc findQueueFamilies(device: VkPhysicalDevice): QueueFamilyIndices =
  var queueFamilyCount: uint32
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr(queueFamilyCount), nil)

  var queueFamilies = newSeq[VkQueueFamilyProperties](queueFamilyCount)
  vkGetPhysicalDeviceQueueFamilyProperties(device, addr(queueFamilyCount), addr(queueFamilies[0]))

  var i = 0'u32
  for queueFamily in queueFamilies:
    if bool(uint32(queueFamily.queueFlags) and uint32(VK_QUEUE_GRAPHICS_BIT)):
      result.graphicsFamily = some(i)

    var presentSupport: VkBool32
    discard vkGetPhysicalDeviceSurfaceSupportKHR(device, i, gGfx.vk.surface, addr(presentSupport))

    if bool(presentSupport):
      result.presentFamily = some(i)

    if result.isComplete():
      break

    inc(i)

proc checkDeviceExtensionSupport(device: VkPhysicalDevice): bool =
  var extensionCount: uint32
  discard vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), nil)

  var availableExtensions = newSeq[VkExtensionProperties](extensionCount)
  discard vkEnumerateDeviceExtensionProperties(device, nil, addr(extensionCount), addr(availableExtensions[0]))

  var requiredExtensions = toHashSet(deviceExtensions)

  for extension in availableExtensions:
    excl(requiredExtensions, cast[cstring](unsafeAddr(extension.extensionName[0])))

  result = len(requiredExtensions) == 0

proc querySwapChainSupport(device: VkPhysicalDevice): SwapChainSupportDetails =
  discard vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, gGfx.vk.surface, addr(result.capabilities))

  var formatCount: uint32
  discard vkGetPhysicalDeviceSurfaceFormatsKHR(device, gGfx.vk.surface, addr(formatCount), nil)

  if formatCount != 0:
    setLen(result.formats, formatCount)
    discard vkGetPhysicalDeviceSurfaceFormatsKHR(device, gGfx.vk.surface, addr(formatCount), addr(result.formats[0]))

  var presentModeCount: uint32
  discard vkGetPhysicalDeviceSurfacePresentModesKHR(device, gGfx.vk.surface, addr(presentModeCount), nil)

  if presentModeCount != 0:
    setLen(result.presentModes, presentModeCount)
    discard vkGetPhysicalDeviceSurfacePresentModesKHR(device, gGfx.vk.surface, addr(presentModeCount), addr(result.presentModes[0]))

proc deviceIsSuitable(device: VkPhysicalDevice): bool =
  let
    indices = findQueueFamilies(device)
    extensionsSupported = checkDeviceExtensionSupport(device)

  var swapChainAdequate = false
  if extensionsSupported:
    let swapChainSupport = querySwapChainSupport(device)
    swapChainAdequate = len(swapChainSupport.formats) != 0 and len(swapChainSupport.presentModes) != 0

  result = indices.isComplete() and extensionsSupported and swapChainAdequate

proc pickPhysicalDevice() =
  var deviceCount: uint32
  discard vkEnumeratePhysicalDevices(gGfx.vk.instance, addr(deviceCount), nil)

  assert(deviceCount > 0, "failed to find GPUs with vulkan support")

  var devices = newSeq[VkPhysicalDevice](deviceCount)
  discard vkEnumeratePhysicalDevices(gGfx.vk.instance, addr(deviceCount), addr(devices[0]))

  for device in devices:
    if deviceIsSuitable(device):
      gGfx.vk.physicalDevice = device
      break

  assert(gGfx.vk.physicalDevice != nil, "failed to find suitable GPU")

proc createLogicalDevice() =
  let indices = findQueueFamilies(gGfx.vk.physicalDevice)

  var
    queueCreateInfos: seq[VkDeviceQueueCreateInfo]
    uniqueQueueFamilies = toHashSet([get(indices.graphicsFamily), get(indices.presentFamily)])

  var queuePriority = 1.0'f32
  for queueFamily in uniqueQueueFamilies:
    var queueCreateInfo = VkDeviceQueueCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex: queueFamily,
      queueCount: 1,
      pQueuePriorities: addr(queuePriority),
    )
    add(queueCreateInfos, queueCreateInfo)

  var deviceFeatures: VkPhysicalDeviceFeatures

  var createInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    pQueueCreateInfos: addr(queueCreateInfos[0]),
    queueCreateInfoCount: uint32(len(queueCreateInfos)),
    pEnabledFeatures: addr(deviceFeatures),
    enabledExtensionCount: uint32(len(deviceExtensions)),
    ppEnabledExtensionNames: addr(deviceExtensions[0])
  )

  when enableValidationLayers:
    createInfo.enabledLayerCount = uint32(len(validationLayers))
    createInfo.ppEnabledLayerNames = addr(validationLayers[0])
  else:
    createInfo.enabledLayerCount = 0

  assert(vkCreateDevice(gGfx.vk.physicalDevice, addr(createInfo), nil, addr(gGfx.vk.device)) == VK_SUCCESS,
         "failed creating logical device")

  vkGetDeviceQueue(gGfx.vk.device, get(indices.graphicsFamily), 0, addr(gGfx.vk.graphicsQueue))
  vkGetDeviceQueue(gGfx.vk.device, get(indices.graphicsFamily), 0, addr(gGfx.vk.presentQueue))

proc chooseSwapSurfaceFormat(availableFormats: openArray[VkSurfaceFormatKHR]): VkSurfaceFormatKHR =
  block choice:
    for availableFormat in availableFormats:
      if availableFormat.format == VK_FORMAT_B8G8R8A8_SRGB and availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR:
        result = availableFormat
        break choice

    result = availableFormats[0]

proc chooseSwapPresentMode(availablePresentModes: openArray[VkPresentModeKHR]): VkPresentModeKHR =
  block choice:
    for availablePresentMode in availablePresentModes:
      if availablePresentMode == VK_PRESENT_MODE_MAILBOX_KHR:
        result = availablePresentMode
        break choice

    result = VK_PRESENT_MODE_FIFO_KHR

proc chooseSwapExtent(capabilities: VkSurfaceCapabilitiesKHR; window: ptr GLFWwindow): VkExtent2D =
  if capabilities.currentExtent.width != high(uint32):
    result = capabilities.currentExtent
  else:
    var width, height: int32
    glfwGetWindowSize(window, addr(width), addr(height))

    result.width = uint32(width)
    result.height = uint32(height)

    result.width = max(capabilities.minImageExtent.width, min(capabilities.maxImageExtent.width, result.width))
    result.height = max(capabilities.minImageExtent.height, min(capabilities.maxImageExtent.height, result.height))

proc createSwapChain(window: ptr GLFWwindow) =
  let
    swapChainSupport = querySwapChainSupport(gGfx.vk.physicalDevice)
    surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats)
    presentMode = chooseSwapPresentMode(swapChainSupport.presentModes)
    extent = chooseSwapExtent(swapChainSupport.capabilities, window)

  var imageCount = swapChainSupport.capabilities.minImageCount + 1
  if swapChainSupport.capabilities.maxImageCount > 0 and imageCount > swapChainSupport.capabilities.maxImageCount:
    imageCount = swapChainSupport.capabilities.maxImageCount

  var createInfo = VkSwapchainCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    surface: gGfx.vk.surface,
    minImageCount: imageCount,
    imageFormat: surfaceFormat.format,
    imageColorSpace: surfaceFormat.colorSpace,
    imageExtent: extent,
    imageArrayLayers: 1,
    imageUsage: uint32(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
    preTransform: swapChainSupport.capabilities.currentTransform,
    compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    presentMode: presentMode,
    clipped: VK_TRUE,
  )

  let indices = findQueueFamilies(gGfx.vk.physicalDevice)

  var queueFamilyIndices = [get(indices.graphicsFamily), get(indices.presentFamily)]
  if indices.graphicsFamily != indices.presentFamily:
    createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT
    createInfo.queueFamilyIndexCount = 2
    createInfo.pQueueFamilyIndices = addr(queueFamilyIndices[0])
  else:
    createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE

  assert(vkCreateSwapchainKHR(gGfx.vk.device, addr(createInfo), nil, addr(gGfx.vk.swapChain)) == VK_SUCCESS,
         "failed to create swap chain")

  discard vkGetSwapchainImagesKHR(gGfx.vk.device, gGfx.vk.swapChain, addr(imageCount), nil)
  setLen(gGfx.vk.swapChainImages, imageCount)
  discard vkGetSwapchainImagesKHR(gGfx.vk.device, gGfx.vk.swapChain, addr(imageCount), addr(gGfx.vk.swapChainImages[0]))

  gGfx.vk.swapChainImageFormat = surfaceFormat.format
  gGfx.vk.swapChainExtent = extent

proc createImageViews() =
  setLen(gGfx.vk.swapChainImageViews, len(gGfx.vk.swapChainImages))

  for i in 0 ..< len(gGfx.vk.swapChainImages):
    var createInfo = VkImageViewCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
      image: gGfx.vk.swapChainImages[i],
      viewType: VK_IMAGE_VIEW_TYPE_2D,
      format: gGfx.vk.swapChainImageFormat
    )

    createInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY
    createInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY
    createInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY
    createInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY

    createInfo.subresourceRange.aspectMask = uint32(VK_IMAGE_ASPECT_COLOR_BIT)
    createInfo.subresourceRange.baseMipLevel = 0
    createInfo.subresourceRange.levelCount = 1
    createInfo.subresourceRange.baseArrayLayer = 0
    createInfo.subresourceRange.layerCount = 1

    assert(vkCreateImageView(gGfx.vk.device, addr(createInfo), nil, addr(gGfx.vk.swapChainImageViews[i])) == VK_SUCCESS,
           "failed to create image view")

proc readFile(filename: string): seq[char] =
  var file = newFileStream(filename, fmRead)

  assert(not isNil(file), "failed to create file stream")

  let size = getFileSize(filename)
  setLen(result, size)

  discard readData(file, addr(result[0]), int(size))

  close(file)

proc createShaderModule(code: var seq[char]): VkShaderModule =
  var createInfo = VkShaderModuleCreateInfo(
    sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    codeSize: uint(len(code)),
    pCode: cast[ptr uint32](addr(code[0]))
  )

  assert(vkCreateShaderModule(gGfx.vk.device, addr(createInfo), nil, addr(result)) == VK_SUCCESS,
         "failed creating shader module")

proc createRenderPass() =
  var
    colorAttachment = VkAttachmentDescription(
      format: gGfx.vk.swapChainImageFormat,
      samples: VK_SAMPLE_COUNT_1_BIT,
      loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    )

    colorAttachmentRef = VkAttachmentReference(
      attachment: 0,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
    )

    subpass = VkSubpassDescription(
      pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
      colorAttachmentCount: 1,
      pColorAttachments: addr(colorAttachmentRef)
    )

    renderPassInfo = VkRenderPassCreateInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      attachmentCount: 1,
      pAttachments: addr(colorAttachment),
      subpassCount: 1,
      pSubpasses: addr(subpass)
    )

  assert(vkCreateRenderPass(gGfx.vk.device, addr(renderPassInfo), nil, addr(gGfx.vk.renderPass)) == VK_SUCCESS,
         "failed creating render pass")

proc createGraphicsPipeline() =
  var
    vertShaderCode = readFile("assets/shaders/vert.spv")
    fragShaderCode = readFile("assets/shaders/frag.spv")

  let
    vertShaderModule = createShaderModule(vertShaderCode)
    fragShaderModule = createShaderModule(fragShaderCode)

  var
    vertShaderStageInfo = VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_VERTEX_BIT,
      module: vertShaderModule,
      pName: "main"
    )

    fragShaderStageInfo = VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage: VK_SHADER_STAGE_FRAGMENT_BIT,
      module: fragShaderModule,
      pName: "main"
    )

  var
    shaderStages = [vertShaderStageInfo, fragShaderStageInfo]

    vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
      vertexBindingDescriptionCount: 0,
      vertexAttributeDescriptionCount: 0
    )

    inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
      topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
      primitiveRestartEnable: VK_FALSE
    )

    viewport = VkViewport(
      x: 0.0'f32,
      y: 0.0'f32,
      width: float32(gGfx.vk.swapChainExtent.width),
      height: float32(gGfx.vk.swapChainExtent.height),
      minDepth: 0.0'f32,
      maxDepth: 1.0'f32
    )

    scissor = VkRect2D(
      offset: VkOffset2D(x: 0, y: 0),
      extent: gGfx.vk.swapChainExtent
    )

    viewportState = VkPipelineViewportStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
      viewportCount: 1,
      pViewports: addr(viewport),
      scissorCount: 1,
      pScissors: addr(scissor)
    )

    rasterizer = VkPipelineRasterizationStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
      depthClampEnable: VK_FALSE,
      rasterizerDiscardEnable: VK_FALSE,
      polygonMode: VK_POLYGON_MODE_FILL,
      lineWidth: 1.0'f32,
      cullMode: uint32(VK_CULL_MODE_BACK_BIT),
      frontFace: VK_FRONT_FACE_CLOCKWISE,
      depthBiasEnable: VK_FALSE
    )

    multisampling = VkPipelineMultisampleStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
      sampleShadingEnable: VK_FALSE,
      rasterizationSamples: VK_SAMPLE_COUNT_1_BIT
    )

    colorBlendAttachment = VkPipelineColorBlendAttachmentState(
      colorWriteMask: uint32(VK_COLOR_COMPONENT_R_BIT) or uint32(VK_COLOR_COMPONENT_G_BIT) or uint32(VK_COLOR_COMPONENT_B_BIT) or uint32(VK_COLOR_COMPONENT_A_BIT),
      blendEnable: VK_FALSE
    )

    colorBlending = VkPipelineColorBlendStateCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
      logicOpEnable: VK_FALSE,
      logicOp: VK_LOGIC_OP_COPY,
      attachmentCount: 1,
      pAttachments: addr(colorBlendAttachment)
    )

  colorBlending.blendConstants[0] = 0.0'f32
  colorBlending.blendConstants[1] = 0.0'f32
  colorBlending.blendConstants[2] = 0.0'f32
  colorBlending.blendConstants[3] = 0.0'f32

  var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount: 0,
    pushConstantRangeCount: 0
  )

  assert(vkCreatePipelineLayout(gGfx.vk.device, addr(pipelineLayoutInfo), nil, addr(gGfx.vk.pipelineLayout)) == VK_SUCCESS,
         "failed creating pipeline layout")

  var pipelineInfo = VkGraphicsPipelineCreateInfo(
    sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount: 2,
    pStages: addr(shaderStages[0]),
    pVertexInputState: addr(vertexInputInfo),
    pInputAssemblyState: addr(inputAssembly),
    pViewportState: addr(viewportState),
    pRasterizationState: addr(rasterizer),
    pMultisampleState: addr(multisampling),
    pColorBlendState: addr(colorBlending),
    layout: gGfx.vk.pipelineLayout,
    renderPass: gGfx.vk.renderPass,
    subpass: 0,
    basePipelineHandle: nil
  )

  assert(vkCreateGraphicsPipelines(gGfx.vk.device, nil, 1, addr(pipelineInfo), nil, addr(gGfx.vk.graphicsPipeline)) == VK_SUCCESS,
         "failed to create graphics pipeline")

  vkDestroyShaderModule(gGfx.vk.device, fragShaderModule, nil)
  vkDestroyShaderModule(gGfx.vk.device, vertShaderModule, nil)

proc createFramebuffers() =
  setLen(gGfx.vk.swapChainFramebuffers, len(gGfx.vk.swapChainImageViews))

  for i in 0 ..< len(gGfx.vk.swapChainImageViews):
    var
      attachments = [gGfx.vk.swapChainImageViews[i]]

      framebufferInfo = VkFramebufferCreateInfo(
        sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        renderPass: gGfx.vk.renderPass,
        attachmentCount: 1,
        pAttachments: addr(attachments[0]),
        width: gGfx.vk.swapChainExtent.width,
        height: gGfx.vk.swapChainExtent.height,
        layers: 1
      )

    assert(vkCreateFramebuffer(gGfx.vk.device, addr(framebufferInfo), nil, addr(gGfx.vk.swapChainFramebuffers[i])) == VK_SUCCESS,
           "failed creating framebuffer")

proc createCommandPool() =
  let queueFamilyIndices = findQueueFamilies(gGfx.vk.physicalDevice)

  var poolInfo = VkCommandPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    queueFamilyIndex: get(queueFamilyIndices.graphicsFamily)
  )

  assert(vkCreateCommandPool(gGfx.vk.device, addr(poolInfo), nil, addr(gGfx.vk.commandPool)) == VK_SUCCESS,
         "failed to create command pool")

proc createCommandBuffers() =
  setLen(gGfx.vk.commandBuffers, len(gGfx.vk.swapChainFramebuffers))

  var allocInfo = VkCommandBufferAllocateInfo(
    sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    commandPool: gGfx.vk.commandPool,
    level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount: uint32(len(gGfx.vk.commandBuffers))
  )

  assert(vkAllocateCommandBuffers(gGfx.vk.device, addr(allocInfo), addr(gGfx.vk.commandBuffers[0])) == VK_SUCCESS,
         "failed to allocate command buffers")

  for i in 0 ..< len(gGfx.vk.commandBuffers):
    var beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
    )

    assert(vkBeginCommandBuffer(gGfx.vk.commandBuffers[i], addr(beginInfo)) == VK_SUCCESS,
           "failed to begin recording command buffer")

    var renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: gGfx.vk.renderPass,
      framebuffer: gGfx.vk.swapChainFramebuffers[i]
    )

    renderPassInfo.renderArea.offset = VkOffset2D(x: 0, y: 0)
    renderPassInfo.renderArea.extent = gGfx.vk.swapChainExtent

    var clearColor = VkClearValue(color: VkClearColorValue(`float32`: [0.0'f32, 0.0'f32, 0.0'f32, 1.0'f32]))
    renderPassInfo.clearValueCount = 1
    renderPassInfo.pClearValues = addr(clearColor)

    vkCmdBeginRenderPass(gGfx.vk.commandBuffers[i], addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)

    vkCmdBindPipeline(gGfx.vk.commandBuffers[i], VK_PIPELINE_BIND_POINT_GRAPHICS, gGfx.vk.graphicsPipeline)

    vkCmdDraw(gGfx.vk.commandBuffers[i], 3, 1, 0, 0)

    vkCmdEndRenderPass(gGfx.vk.commandBuffers[i])

    assert(vkEndCommandBuffer(gGfx.vk.commandBuffers[i]) == VK_SUCCESS,
           "failed to record command buffer")

proc createSyncObjects() =
  setLen(gGfx.vk.imageAvailableSemaphores, maxFramesInFlight)
  setLen(gGfx.vk.renderFinishedSemaphores, maxFramesInFlight)
  setLen(gGfx.vk.inFlightFences, maxFramesInFlight)
  setLen(gGfx.vk.imagesInFlight, len(gGfx.vk.swapChainImages))

  var semaphoreInfo = VkSemaphoreCreateInfo(
    sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
  )

  var fenceInfo = VkFenceCreateInfo(
    sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    flags: uint32(VK_FENCE_CREATE_SIGNALED_BIT)
  )

  for i in 0 ..< maxFramesInFlight:
    assert(vkCreateSemaphore(gGfx.vk.device, addr(semaphoreInfo), nil, addr(gGfx.vk.imageAvailableSemaphores[i])) == VK_SUCCESS and
           vkCreateSemaphore(gGfx.vk.device, addr(semaphoreInfo), nil, addr(gGfx.vk.renderFinishedSemaphores[i])) == VK_SUCCESS and
           vkCreateFence(gGfx.vk.device, addr(fenceInfo), nil, addr(gGfx.vk.inFlightFences[i])) == VK_SUCCESS,
           "failed creating synchronization objects for frame")

proc initVulkan(window: ptr GLFWwindow) =
  var res = volkInitialize()
  assert(res == VK_SUCCESS, "failed initializing volk")

  createInstance()

  volkLoadInstance(gGfx.vk.instance)

  when enableValidationLayers:
    setupDebugMessenger()

  createSurface(window)

  pickPhysicalDevice()

  createLogicalDevice()

  volkLoadDevice(gGfx.vk.device)

  createSwapChain(window)

  createImageViews()

  createRenderPass()

  createGraphicsPipeline()

  createFramebuffers()

  createCommandPool()

  createCommandBuffers()

  createSyncObjects()

proc drawFrame*() =
  discard vkWaitForFences(gGfx.vk.device, 1, addr(gGfx.vk.inFlightFences[gGfx.vk.currentFrame]), VK_TRUE, high(uint64))

  var imageIndex: uint32
  discard vkAcquireNextImageKHR(gGfx.vk.device, gGfx.vk.swapChain, high(uint64), gGfx.vk.imageAvailableSemaphores[gGfx.vk.currentFrame], nil, addr(imageIndex))

  if gGfx.vk.imagesInFlight[imageIndex] != nil:
    discard vkWaitForFences(gGfx.vk.device, 1, addr(gGfx.vk.imagesInFlight[imageIndex]), VK_TRUE, high(uint64))
  gGfx.vk.imagesInFlight[imageIndex] = gGfx.vk.inFlightFences[gGfx.vk.currentFrame]

  var
    waitSemaphores  = [gGfx.vk.imageAvailableSemaphores[gGfx.vk.currentFrame]]
    waitStages = [uint32(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)]
    signalSemaphores = [gGfx.vk.renderFinishedSemaphores[gGfx.vk.currentFrame]]
                
    submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      waitSemaphoreCount: 1,
      pWaitSemaphores: addr(waitSemaphores[0]),
      pWaitDstStageMask: addr(waitStages[0]),
      commandBufferCount: 1,
      pCommandBuffers: addr(gGfx.vk.commandBuffers[imageIndex]),
      signalSemaphoreCount: 1,
      pSignalSemaphores: addr(signalSemaphores[0])
    )

  discard vkResetFences(gGfx.vk.device, 1, addr(gGfx.vk.inFlightFences[gGfx.vk.currentFrame]))

  assert(vkQueueSubmit(gGfx.vk.graphicsQueue, 1, addr(submitInfo), gGfx.vk.inFlightFences[gGfx.vk.currentFrame]) == VK_SUCCESS,
         "failed submitting draw command buffer")

  var
    swapChains = [gGfx.vk.swapChain]
    
    presentInfo = VkPresentInfoKHR(
      sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
      waitSemaphoreCount: 1,
      pWaitSemaphores: addr(signalSemaphores[0]),
      swapchainCount: 1,
      pSwapchains: addr(swapChains[0]),
      pImageIndices: addr(imageIndex)
    )

  discard vkQueuePresentKHR(gGfx.vk.presentQueue, addr(presentInfo))

  gGfx.vk.currentFrame = (gGfx.vk.currentFrame + 1) mod maxFramesInFlight

proc shutdownVulkan() =
  discard vkDeviceWaitIdle(gGfx.vk.device)

  for i in 0 ..< maxFramesInFlight:
    vkDestroySemaphore(gGfx.vk.device, gGfx.vk.renderFinishedSemaphores[i], nil)
    vkDestroySemaphore(gGfx.vk.device, gGfx.vk.imageAvailableSemaphores[i], nil)
    vkDestroyFence(gGfx.vk.device, gGfx.vk.inFlightFences[i], nil)
  
  vkDestroyCommandPool(gGfx.vk.device, gGfx.vk.commandPool, nil)

  for framebuffer in gGfx.vk.swapChainFramebuffers:
    vkDestroyFramebuffer(gGfx.vk.device, framebuffer, nil)
  
  vkDestroyPipeline(gGfx.vk.device, gGfx.vk.graphicsPipeline, nil)
  vkDestroyPipelineLayout(gGfx.vk.device, gGfx.vk.pipelineLayout, nil)
  vkDestroyRenderPass(gGfx.vk.device, gGfx.vk.renderPass, nil)

  for imageView in gGfx.vk.swapChainImageViews:
    vkDestroyImageView(gGfx.vk.device, imageView, nil)

  vkDestroySwapchainKHR(gGfx.vk.device, gGfx.vk.swapChain, nil)
  vkDestroyDevice(gGfx.vk.device, nil)

  when enableValidationLayers:
    vkDestroyDebugUtilsMessengerEXT(gGfx.vk.instance, gGfx.vk.debugMessenger, nil)

  vkDestroySurfaceKHR(gGfx.vk.instance, gGfx.vk.surface, nil)
  
  vkDestroyInstance(gGfx.vk.instance, nil)

proc init*(window: ptr GLFWwindow) =
  initVulkan(window)

proc shutdown*() =
  shutdownVulkan()
