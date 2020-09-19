import dynlib, os, strformat,
       ../../lib/glfw,
       api, config, gfx, plugin

type
  FragApplication = object
    appFilepath: string
    conf: FragAppConfig
    window: ptr GLFWwindow

var gApp: FragApplication

proc glfwErrorCb(error: int32; description: cstring) {.cdecl.} =
  echo &"glfw error: {error} - {description}"

proc fragAppInit(): bool =
  block:
    if not bool(glfwInit()):
      echo "failed initializing glfw"
      break

    discard glfwSetErrorCallback(glfwErrorCb)

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API)
    gApp.window = glfwCreateWindow(gApp.conf.width, gApp.conf.height,
        gApp.conf.windowTitle, nil, nil)

    if gApp.window.isNil:
      echo "failed creating window"
      break

    fragGfxInit(gApp.window)

    if not fragPluginLoadAbs(gApp.appFilepath):
      echo &"failed loading game or application plugin: {gApp.appFilepath}"
      break

    if not fragPluginInitPlugins():
      echo "failed initializing plugins"
      break

    glfwShowWindow(gApp.window)

    result = true

proc fragAppMain*(run: string) =
  block:
    if not fileExists(run):
      echo &"game or application {run} does not exist"
      break

    let entryLib = dynlib.loadLib(run)
    if entryLib.isNil:
      echo &"game or application {run} is not a valid shared library"
      break

    let appConfigProc = cast[FragAppConfigCb](entryLib.symAddr("fragAppConfig"))
    if appConfigProc.isNil:
      echo &"symbol 'fragAppConfig' not found in game or application: {run}"
      break

    gApp.appFilepath = run

    var conf: FragAppConfig
    appConfigProc(conf)
    dynlib.unloadLib(entryLib)

    gApp.conf = conf

    if not fragAppInit():
      echo "failed initializing application"
      break

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

    gfx.shutdown()
    glfwDestroyWindow(gApp.window)
    glfwTerminate()
    quit(QuitSuccess)
  quit(QuitFailure)
