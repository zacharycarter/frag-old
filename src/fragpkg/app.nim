import strformat, dynlib,
       ../../lib/[glfw, volk],
       api, config, gfx, plugin, render_graph

type
  FragApplication = object
    window: ptr GLFWwindow

var gApp: FragApplication

proc glfwErrorCb(error: int32; description: cstring) {.cdecl.} =
  echo &"glfw error: {error} - {description}"

proc init(): bool =
  block:
    if not bool(glfwInit()):
      echo "failed initializing glfw"
      break
    result = true

proc main*() =
  block:
    let entryLib = dynlib.loadLib("minimal.dylib")
    if entryLib.isNil:
      echo "failed loading entry point plugin"
      break

    let appConfigProc = cast[AppConfigCb](entryLib.symAddr("fragAppConfig"))
    if appConfigProc.isNil:
      echo "symbol `fragAppConfig` not found in entry point plugin"
      break

    var conf: AppConfig
    appConfigProc(conf)
    dynlib.unloadLib(entryLib)

    if not init():
      echo "failed initializing application"
      break

    discard glfwSetErrorCallback(glfwErrorCb)

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API)
    gApp.window = glfwCreateWindow(conf.width, conf.height, conf.windowTitle, nil, nil)

    if gApp.window.isNil:
      echo "failed creating window"
      break

    gfx.init(gApp.window)

    var back = newAttachmentInfo()

    let
      graph = newRenderGraph()
      depth = addPass(graph, "depth", qfGraphics)

    discard addColorOutput(depth, "depth", back)
    depth.getClearColorCb = proc(a: uint; value: ptr VkClearColorValue): bool =
      if value != nil:
        value.`float32`[0] = 0.0'f32
        value.`float32`[1] = 1.0'f32
        value.`float32`[2] = 0.0'f32
        value.`float32`[3] = 1.0'f32
      result = true

    plugin.load("minimal.dylib")

    glfwShowWindow(gApp.window)

    let limitFPS {.global.} = 1.0'f64 / 60.0'f64

    var
      t = 0.0'f64
      dt = 0.01'f64

      currentTime = glfwGetTime()
      accumulator = 0.0'f64

    while not gApp.window.glfwWindowShouldClose().bool:
      let newTime = glfwGetTime()
      var frameTime = newTime - currentTime

      if frameTime > 0.25'f64:
        frameTime = 0.25'f64

      currentTime = newTime
      accumulator += frameTime

      glfwPollEvents()

      while accumulator >= dt:
        t += dt
        accumulator -= dt

      gfx.drawFrame()

      let alpha = accumulator / dt

    gfx.shutdown()
    glfwDestroyWindow(gApp.window)
    glfwTerminate()
