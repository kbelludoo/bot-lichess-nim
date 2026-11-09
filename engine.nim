import std/[os, osproc, streams, strutils, asyncdispatch]

type
  ChessEngine* = ref object
    enginePath*: string
    process*: Process
    isStarted*: bool

proc fallbackHeuristicMove*(moves: string): string =
  let played = moves.splitWhitespace()
  let openingBook = [
    "e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "d2d3", "f8c5",
    "c2c3", "d7d6", "e1g1", "e8g8", "h2h3", "h7h6", "b1d2", "a7a6"
  ]
  let idx = played.len
  if idx < openingBook.len:
    return openingBook[idx]
  let safeMoves = ["d2d4", "c2c4", "g1f3", "b1c3", "e2e3", "g2g3", "b2b3", "f1e2", "d1c2"]
  return safeMoves[idx mod safeMoves.len]

proc newChessEngine*(path: string): ChessEngine =
  result = ChessEngine(enginePath: path, isStarted: false)

proc ensureStarted*(eng: ChessEngine): bool =
  if eng.isStarted and eng.process != nil and eng.process.running:
    return true

  var bin = eng.enginePath
  if bin == "native" or bin == "":
    if fileExists("/usr/games/stockfish"):
      bin = "/usr/games/stockfish"
    else:
      bin = "stockfish"

  try:
    eng.process = startProcess(
      bin,
      options = {poUsePath, poStdErrToStdOut}
    )
    eng.process.inputStream.writeLine("uci")
    eng.process.inputStream.writeLine("isready")
    eng.process.inputStream.writeLine("ucinewgame")
    eng.process.inputStream.flush()
    eng.isStarted = true
    echo "♟️ [Stockfish UCI] Motor nativo spawnado com sucesso: ", bin
    return true
  except CatchableError as e:
    echo "⚠️ [Stockfish UCI] Não foi possível iniciar Stockfish (", bin, "): ", e.msg, ". Usando Heurística Nativa."
    eng.isStarted = false
    return false

proc bestMoveSync*(eng: ChessEngine, moves: string, movetimeMs: int): string =
  if eng.ensureStarted():
    try:
      let posCmd = if moves.strip().len == 0: "position startpos" else: "position startpos moves " & moves.strip()
      let goCmd = "go movetime " & $movetimeMs
      eng.process.inputStream.writeLine(posCmd)
      eng.process.inputStream.writeLine(goCmd)
      eng.process.inputStream.flush()

      var line = ""
      while eng.process.outputStream.readLine(line):
        let parts = line.splitWhitespace()
        if parts.len >= 2 and parts[0] == "bestmove":
          return parts[1]
    except CatchableError as e:
      echo "⚠️ [Stockfish UCI] Erro na leitura do motor: ", e.msg
      eng.isStarted = false

  return fallbackHeuristicMove(moves)

proc bestMoveAsync*(eng: ChessEngine, moves: string, movetimeMs: int): Future[string] {.async.} =
  # Small non-blocking yield before calculation
  await sleepAsync(10)
  return eng.bestMoveSync(moves, movetimeMs)
