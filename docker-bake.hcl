group "default" {
  targets = ["simple"]
}

target "_common" {
  context = "."
  target  = "export"
  output  = ["type=local,dest=dist"]
}

target "simple" {
  inherits = ["_common"]
  args = {
    WITH_WEBVIEW = "false"
  }
}

target "webview" {
  inherits = ["_common"]
  args = {
    WITH_WEBVIEW = "true"
  }
}
