import fragpkg/[api, config]

export
  api,
  config


when isMainModule:
  import cligen,
         fragpkg/app

  dispatch(fragAppMain, help = {"run": "game or application to run with frag"})
