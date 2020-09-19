import frag

fragPluginDecl()

var core {.fragState.}: ptr FragApiCore

fragPluginDeclMain(plugin, e):
  case e
  of fpeLoad:
    discard
  of fpeUpdate:
    discard
  of fpeUnload:
    discard
  of fpeShutdown:
    discard

fragPluginDeclEventHandler(e):
  case e.kind
  of faekSuspended:
    discard
  of faekRestored:
    discard
  of faekMouseDown:
    discard
  of faekMouseUp:
    discard
  of faekMouseMove:
    discard

fragAppDeclConfig(conf):
  conf.appName = "minimal"
  conf.windowTitle = "frag - minimal"
  conf.width = 960
  conf.height = 540
