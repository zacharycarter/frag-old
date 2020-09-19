import fragpkg/[api, config]

export
  api,
  config


when isMainModule:
  import cligen,
         fragpkg/app

  dispatch(app.main, help = {"run": "game or application to run with frag"})
