import cstrutils,
       ../../lib/[glfw, volk]

type
  VulkanState = object
    instance: VkInstance
    debugMessenger: VkDebugUtilsMessengerEXT
    
  GfxState = object
    vk: VulkanState

var
  gGfx: GfxState

  validationLayers = [
    cstring("VK_LAYER_KHRONOS_validation")
  ]

when defined(danger) or defined(release):
  const enableValidationLayers = false
else:
  const enableValidationLayers = true

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

  result.add(toOpenArray(glfwExtensions, 0, int(glfwExtensionCount) - 1))

  when enableValidationLayers:
    result.add(VK_EXT_DEBUG_UTILS_EXTENSION_NAME)

proc createInstance(): VkResult =
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
  echo repr extensions
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

  result = vkCreateInstance(addr(createInfo), nil, addr(gGfx.vk.instance))

proc setupDebugMessenger(): VkResult =
  var createInfo: VkDebugUtilsMessengerCreateInfoEXT
  populateDebugMessengerCreateInfo(createInfo)

  result = vkCreateDebugUtilsMessengerEXT(gGfx.vk.instance, addr(createInfo), nil, addr(gGfx.vk.debugMessenger))

proc initVulkan() =
  var res = volkInitialize()
  assert(res == VK_SUCCESS, "failed initializing volk")

  res = createInstance()
  assert(res == VK_SUCCESS, "failed creating vulkan instance")

  volkLoadInstance(gGfx.vk.instance)

  when enableValidationLayers:
    res = setupDebugMessenger()
    assert(res == VK_SUCCESS, "failed setting up debug messenger")

proc shutdownVulkan() =
  vkDestroyDebugUtilsMessengerEXT(gGfx.vk.instance, gGfx.vk.debugMessenger, nil)
  vkDestroyInstance(gGfx.vk.instance, nil)

proc init*() =
  initVulkan()

proc shutdown*() =
  shutdownVulkan()
