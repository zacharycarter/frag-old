import config

template fragAppDeclConfig*(confParamName, body: untyped) =
  proc fragAppConfig(confParamName: var AppConfig) {.cdecl, exportc, dynlib.} =
    body
