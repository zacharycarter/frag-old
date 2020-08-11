import ../lib/glfw

type
  WindowState = object
    window: ptr GLFWWindow

var state: WindowState

proc createWindow*(width, height: int; title: string) =
  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API)
  glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE)

  state.window = glfwCreateWindow(width.int32, height.int32, title, nil, nil)

proc getWindow*(): ptr GLFWWindow =
  result = state.window

proc windowShouldClose*(): bool =
  result = state.window.glfwWindowShouldClose().bool

proc destroyWindow*() =
  state.window.glfwDestroyWindow()
