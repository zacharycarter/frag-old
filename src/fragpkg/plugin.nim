import ../../lib/cr

{.link: "../../lib/cr.o".}

type
  FragPlugin = object
    ctx: PluginContext

proc init*() =
  discard

proc load*(path: string) =
  var plug: FragPlugin
  
  echo pluginOpen(plug.ctx, path)

