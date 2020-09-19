import nimterop/[build, cimport],
       volk

const
  baseDir = getProjectCacheDir("glfw")

cPlugin:
  import strutils

  proc onSymbol(sym: var Symbol) {.exportc, dynlib.} =
    sym.name = sym.name.strip(chars = {'_'})


    if sym.name == "GLFWcursor":
      sym.name = "GLFWCursor"
    if sym.name == "GLFW_CURSOR":
      sym.name = "GLFW_CURSOR_MODE"

getHeader(
  "glfw3.h",
  giturl = "https://github.com/glfw/glfw.git",
  outdir = baseDir,
)

cDefine("VK_VERSION_1_0", "1")
cDefine("GLFW_INCLUDE_VULKAN")
cPassL("-framework Cocoa -framework OpenGL -framework IOKit -framework CoreVideo")

# TODO: Use env var here
cExclude("/Users/zacharycarter/dev/vk/macOS/include/")
cImport(glfw3Path, recurse = true)
