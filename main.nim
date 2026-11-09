import std/[os, asyncdispatch, strutils]
import config, telemetry, engine, server, bot

proc main() =
  echo "=================================================================="
  echo "  ♟️  LICHESS BOT 100% NIM — MODO BERSERK + MBVM-DB AUTO-LEARN ♟️   "
  echo "=================================================================="

  var configPath = "bot-config.json"
  var i = 1
  while i <= paramCount():
    let arg = paramStr(i)
    if (arg == "-config" or arg == "--config") and i + 1 <= paramCount():
      configPath = paramStr(i + 1)
      i += 2
    else:
      i += 1

  let cfg = loadConfig(configPath)
  let token = getEnv("LICHESS_TOKEN", cfg.token)
  let portStr = getEnv("PORT", $cfg.port)
  let port = try: parseInt(portStr) except CatchableError: cfg.port

  let state = newTelemetryState(port, cfg.mode)
  let eng = newChessEngine(cfg.engine_path)

  # 1. Fetch Account
  asyncCheck fetchAccount(state, token)

  # 2. Telemetry HTTP Server (Port 3016)
  asyncCheck runTelemetryServer(state, port)

  # 3. Lichess Event Stream
  asyncCheck runEventStream(state, eng, cfg.move_time_ms, token)

  # 4. Auto Matchmaker
  if cfg.auto_match:
    asyncCheck runAutoMatchmaker(state, token)

  # 5. Idle Learner
  if cfg.idle_learn:
    asyncCheck runIdleLearner(state)

  runForever()

when isMainModule:
  main()
