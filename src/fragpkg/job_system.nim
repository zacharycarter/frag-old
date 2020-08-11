import weave,
       atomics

var
  shutdownSignal: Atomic[bool]
  weaveThread: Thread[ptr Atomic[bool]]

proc initialize*() =
  shutdownSignal.store(false, moRelaxed)
  weaveThread.runInBackground(Weave, addr shutdownSignal)
  setupSubmitterThread(Weave)
  waitUntilReady(Weave)

proc shutdown*() =
  shutdownSignal.store(true)
  weaveThread.joinThread()
  # teardownSubmitterThread(Weave)

proc foo() =
  echo "FOO"

proc execute*() =
  discard
  # let f = submit foo()
  # waitFor(p)
