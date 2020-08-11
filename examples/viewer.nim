import ../src/frag

proc init() =
  echo "initializing app"

proc frame() =
  discard

proc event() =
  discard

proc cleanup() =
  echo "cleaning up"

proc main() =
  var appDesc = AppDesc(
    initCb: init,
    frameCb: frame,
    eventCb: event,
    cleanupCb: cleanup,
  )

  run(appDesc)

when isMainModule:
  main()
