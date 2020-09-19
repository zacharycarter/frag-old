import strformat,
       ../../lib/cr,
       api

{.link: "../../lib/cr.o".}

type
  FragPluginItem = object
    ctx: PluginContext
    filepath: string

  FragPluginManager = object
    plugins: seq[FragPluginItem]

var
  gPluginManager: FragPluginManager
  gPluginApi: FragApiPlugin



proc fragPluginLoadAbs*(filepath: string): bool =
  var pluginItem: FragPluginItem
  pluginItem.ctx.userData = addr(gPluginApi)
  pluginItem.filepath = filepath
  add(gPluginManager.plugins, pluginItem)
  result = true

proc fragPluginLoad(name: string): bool {.cdecl.} =
  discard

proc fragPluginInitPlugins*(): bool =
  block:
    for pluginItem in gPluginManager.plugins:
      if not pluginOpen(pluginItem.ctx, pluginItem.filepath):
        echo &"plugin intialization failed: {pluginItem.filepath}"
        break
  result = true

proc fragPluginAddApi(name: string; version: uint32; api: pointer) {.cdecl.} =
  discard

proc fragPluginRemoveApi(name: string; version: uint32) {.cdecl.} =
  discard

proc fragPluginGetApi(kind: FragApiKind; version: uint32): pointer {.cdecl.} =
  discard

proc fragPluginGetApiByName(name: string; version: uint32): pointer {.cdecl.} =
  discard

proc fragPluginGetCrashReasonMsg(crashReason: FragPluginCrashReason): string {.cdecl.} =
  discard

gPluginApi = FragApiPlugin(
  load: fragPluginLoad,
  addApi: fragPluginAddApi,
  removeApi: fragPluginRemoveApi,
  getApi: fragPluginGetApi,
  getApiByName: fragPluginGetApiByName,
  getCrashReasonMsg: fragPluginGetCrashReasonMsg,
)
