import ../lib/glfw,
       window, graphics_device

type
  InitCallback = proc()
  FrameCallback = proc()
  CleanupCallback = proc()
  EventCallback = proc()

  AppDesc* = object
    initCb: proc()
    frameCb: proc()
    cleanupCb: proc()
    eventCb: proc()
    
    width: int
    height: int
    title: string

  FragState = object
    quit: bool

    initCb: InitCallback
    frameCb: FrameCallback
    cleanupCb: CleanupCallback
    eventCb: EventCallback

var state: FragState

proc defaults(desc: var AppDesc) =
  desc.width = if desc.width == 0: 960 else: desc.width
  desc.height = if desc.height == 0: 540 else: desc.height
  desc.title = if desc.title.len == 0: "Frag" else: desc.title

proc init(state: var FragState; desc: var AppDesc) =
  if desc.initCb.isNil:
    echo "must assign init callback"
    quit(QuitFailure)

  state.initCb = desc.initCb

  if desc.frameCb.isNil:
    echo "must assign frame callback"
    quit(QuitFailure)

  state.frameCb = desc.frameCb

  if desc.cleanupCb.isNil:
    echo "must assign cleanup callback"
    quit(QuitFailure)

  state.cleanupCb = desc.cleanupCb

  if desc.eventCb.isNil:
    echo "must assign event callback"
    quit(QuitFailure)

  state.eventCb = desc.eventCb

  desc.defaults()

proc run*(desc: var AppDesc) =
  if not glfwInit().bool:
    echo "failed initializing glfw"
    quit(QuitFailure)
  
  state.init(desc)

  createWindow(desc.width, desc.height, desc.title)

  getWindow().createVulkanGraphicsDevice()

  state.initCb()

  var
    time = 0.0'f64
    deltaTime = 0.01'f64
    currentTime = glfwGetTime()
    accumulator = 0.0'f64

  while not windowShouldClose():
    let newTime = glfwGetTime()

    var frameTime = newTime - currentTime
    if frameTime > 0.25:
      frameTime = 0.25
    currentTime = newTime

    accumulator += frameTime

    glfwPollEvents()

    while accumulator >= deltaTime:
      state.frameCb()
      time += deltaTime
      accumulator -= deltaTime

  state.cleanupCb()

  destroyWindow()

  glfwTerminate()

  quit(QuitSuccess)

when isMainModule:
  proc init() =
    echo "initializing app"

  proc frame() =
    discard

  proc event() =
    discard

  proc cleanup() =
    echo "cleaning up"

  var appDesc = AppDesc(
    initCb: init,
    frameCb: frame,
    eventCb: event,
    cleanupCb: cleanup,
  )

  run(appDesc)
