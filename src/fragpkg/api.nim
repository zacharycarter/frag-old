import config

type
  FragAppEventKind* = enum
    faekMouseDown
    faekMouseUp
    faekMouseMove
    faekRestored
    faekSuspended

  FragAppEvent* = object
    kind*: FragAppEventKind

  FragApiKind* = enum
    fakCore
    fakPlugin
    fakApp
    fakGfx
    fakCamera

  FragPluginEvent* = enum
    fpeLoad
    fpeUpdate
    fpeUnload
    fpeShutdown

  FragPluginCrashReason* = enum
    fpcrNone
    fpcrSegfault
    fpcrIllegal
    fpcrAbort
    fpcrMisalign
    fpcrBounds
    fpcrStackOverflow
    fpcrStateInvalidated
    fpcrBadImage
    fpcrOther
    fpcrUser = 0x100

  FragApiPlugin* = object
    load*: proc(name: string): bool {.cdecl.}
    addApi*: proc(name: string; version: uint32) {.cdecl.}
    removeApi*: proc(name: string; version: uint32) {.cdecl.}
    getApi*: proc(kind: FragApiKind; version: uint32): pointer {.cdecl.}
    getApiByName*: proc(name: string; version: uint32): pointer {.cdecl.}
    getCrashReasonMsg*: proc(crashReason: FragPluginCrashReason): string {.cdecl.}

  FragApiCore* = object


  FragPlugin* = object
    p: pointer
    api*: ptr FragApiPlugin
    version*: uint32
    crashReason: FragPluginCrashReason

template fragPluginDecl*() =
  when defined(MacOSX):
    {.pragma: fragState, codegenDecl: """$# __attribute__((used, section("__DATA,__state"))) $#""".}

template fragAppDeclConfig*(confParamName, body: untyped) =
  proc fragAppConfig(confParamName: var AppConfig) {.cdecl, exportc, dynlib.} =
    body

template fragPluginDeclMain*(pluginParamName, eventParamName, body: untyped) =
  proc fragPluginMain(pluginParamName: var FragPlugin;
      eventParamName: FragPluginEvent) {.cdecl, exportc, dynlib.} =
    body

template fragPluginDeclEventHandler*(eventParamName, body: untyped) =
  proc fragPluginEventHandler(eventParamname: FragAppEvent) {.cdecl, exportc, dynlib.} =
    body
