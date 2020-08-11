const
  ConfigMaxPlugins* = 64

type
  AppConfig* = object
    width*: int32
    height*: int32
    appName*: string
    windowTitle*: string

  AppConfigCb* = proc(conf: var AppConfig) {.cdecl.}
