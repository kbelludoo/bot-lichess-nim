import std/[asynchttpserver, asyncdispatch, json, strutils]
import telemetry

proc runTelemetryServer*(state: TelemetryState, port: int) {.async.} =
  var server = newAsyncHttpServer()

  proc cb(req: Request) {.async, gcsafe.} =
    let path = req.url.path
    var headers = newHttpHeaders([
      ("Access-Control-Allow-Origin", "*"),
      ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
      ("Access-Control-Allow-Headers", "Content-Type, Authorization")
    ])

    if req.reqMethod == HttpOptions:
      await req.respond(Http200, "", headers)
      return

    if path == "/api/status" or path == "/status.json":
      headers.add("Content-Type", "application/json; charset=utf-8")
      let body = $state.toJson()
      await req.respond(Http200, body, headers)
    elif path == "/" or path == "":
      headers.add("Content-Type", "text/html; charset=utf-8")
      let html = "<h1>♟️ Lichess Bot 100% Nim Engine</h1><p>Online em port " & $port & ".</p>"
      await req.respond(Http200, html, headers)
    else:
      await req.respond(Http404, "Not Found", headers)

  echo "🌐 [Web Server] Telemetria Lichess Bot Nim ativa em http://0.0.0.0:", port
  await server.serve(Port(port), cb, "0.0.0.0")
