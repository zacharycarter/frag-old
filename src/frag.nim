import fragpkg/[api, config]

export
  api,
  config


when isMainModule:
  import fragpkg/app

  app.main()
