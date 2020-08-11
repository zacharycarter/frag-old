import os

type
  PluginFailure* = distinct int32

  PluginOp* = distinct int32

  PluginContext* = object
    p*: pointer
    userData*: pointer
    version*: uint
    failure*: PluginFailure
    nextVersion*: uint
    lastWorkingVersion*: uint

const
  basePath = currentSourcePath.parentDir()
  headerPath = basePath/"cr/cr.h"

  pfNone = PluginFailure(0)
  pfSegfault = PluginFailure(1)
  pfIllegal = PluginFailure(2)
  pfAbort = PluginFailure(3)
  pfMisalign = PluginFailure(4)
  pfBounds = PluginFailure(5)
  psStackOverflow = PluginFailure(6)
  pfStateInvalidated = PluginFailure(7)
  pfBadImage = PluginFailure(8)
  pfOther = PluginFailure(9)
  pfUser = PluginFailure(0x100)

  poLoad* = PluginOp(0)
  poStep* = PluginOp(1)
  poUnload* = PluginOp(2)
  poClose* = PluginOp(3)

proc pluginOpen*(ctx: PluginContext; fullpath: cstring): bool {.importc: "cr_plugin_open", header: headerPath.}
proc pluginUpdate*(ctx: PluginContext; reloadCheck: bool = true): int32 {.importc: "cr_plugin_update", header: headerPath.}
proc pluginClose*(ctx: PluginContext) {.importc: "cr_plugin_close", header: headerPath.}
