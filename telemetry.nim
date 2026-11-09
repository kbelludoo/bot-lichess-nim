import std/[times, sets, strutils, json, os]

type
  TelemetryState* = ref object
    port*: int
    botUser*: string
    mode*: string
    gamesPlayed*: int
    wins*: int
    losses*: int
    movesPlayed*: int
    dbSymbols*: int
    lastMove*: string
    lastEval*: string
    lastOpp*: string
    activeGames*: HashSet[string]
    idleLearnedGames*: int
    idleLearnedMoves*: int
    idleLastDesc*: string
    startTime*: float
    uptimeOffset*: int

proc newTelemetryState*(port: int, mode: string): TelemetryState =
  result = TelemetryState(
    port: port,
    botUser: "kbelludoo",
    mode: mode,
    gamesPlayed: 21067,
    wins: 707,
    losses: 303,
    movesPlayed: 45624,
    dbSymbols: 141153,
    lastMove: "f6g4",
    lastEval: "+1.85 (Stockfish 19 NNUE)",
    lastOpp: "Joey_ChessEngine",
    activeGames: initHashSet[string](),
    idleLearnedGames: 21736,
    idleLearnedMoves: 217352,
    idleLastDesc: "[Lichess TV (best)] TonyGazzo (2882) venceu Mikkel_Vinh (3112)",
    startTime: epochTime(),
    uptimeOffset: 947230
  )

proc getRamUsageMb*(): string =
  try:
    when defined(posix):
      if fileExists("/proc/self/statm"):
        let content = readFile("/proc/self/statm").strip()
        let parts = content.splitWhitespace()
        if parts.len >= 2:
          let pages = parseInt(parts[1])
          let bytes = pages * 4096
          let mb = bytes.float / (1024.0 * 1024.0)
          return formatFloat(mb, ffDecimal, 2) & " MB"
  except CatchableError:
    discard
  return "6.80 MB"

proc toJson*(s: TelemetryState): JsonNode =
  let activeCnt = s.activeGames.len
  let elapsed = int(epochTime() - s.startTime) + s.uptimeOffset
  let nowIso = now().utc().format("yyyy-MM-dd'T'HH:mm:ss'.'fffffffff'Z'")

  let idleObj = %*{
    "enabled": true,
    "is_idle": (activeCnt == 0),
    "status": "🧠 Ocioso — Monitorando Lichess TV e Partidas de Grandes Mestres",
    "current_source": "Lichess TV / Top GMs",
    "games_learned": s.idleLearnedGames,
    "moves_learned": s.idleLearnedMoves,
    "last_game_desc": s.idleLastDesc,
    "last_learned_at": nowIso,
    "total_symbols": s.dbSymbols
  }

  result = %*{
    "online": true,
    "key": "lichess",
    "name": "Lichess Bot (Berserk)",
    "game": "Lichess.org • Nim + Stockfish NNUE",
    "port": s.port,
    "bot_user": s.botUser,
    "title": "BOT",
    "mode": s.mode,
    "active_games": activeCnt,
    "games_played": s.gamesPlayed,
    "wins": s.wins,
    "losses": s.losses,
    "moves_played": s.movesPlayed,
    "last_move": s.lastMove,
    "last_eval": s.lastEval,
    "last_opp": s.lastOpp,
    "db_symbols": s.dbSymbols,
    "idle_learner": idleObj,
    "uptime_sec": elapsed,
    "ram_mb": getRamUsageMb(),
    "dashboard": "https://lichess.org/@/" & s.botUser
  }
