const
  ConfigMaxPlugins* = 64

type
  FragAppConfig* = object
    width*: int32
    height*: int32
    appName*: string
    windowTitle*: string

  FragAppConfigCb* = proc(conf: var FragAppConfig) {.cdecl.}
