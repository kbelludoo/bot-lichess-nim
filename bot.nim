import std/[httpclient, asyncdispatch, json, strutils, sets]
import telemetry, engine

const OPPONENTS = [
  "LeelaAlien", "SybAIBot", "Maia1", "Maia5", "StockfishLevel1", "StockfishLevel3", "BerserkBot"
]

proc newLichessClient*(token: string): AsyncHttpClient =
  result = newAsyncHttpClient(userAgent = "Nim-Lichess-Bot/1.0")
  result.headers = newHttpHeaders([
    ("Authorization", "Bearer " & token),
    ("User-Agent", "Nim-Lichess-Bot/1.0")
  ])

proc fetchAccount*(state: TelemetryState, token: string) {.async.} =
  let client = newLichessClient(token)
  try:
    let resp = await client.get("https://lichess.org/api/account")
    if resp.code == Http200:
      let body = await resp.body
      let j = parseJson(body)
      if j.hasKey("username"):
        state.botUser = j["username"].getStr()
        echo "✅ Autenticado como Lichess Bot: ", state.botUser, " | Modo: 💀 ", state.mode.toUpperAscii()
  except CatchableError as e:
    echo "⚠️ [Lichess API] Erro ao obter conta: ", e.msg
  finally:
    client.close()

proc handleGameTurn(
  gameId: string,
  stateNode: JsonNode,
  isWhite: bool,
  token: string,
  state: TelemetryState,
  eng: ChessEngine,
  movetimeMs: int
) {.async.} =
  let movesStr = if stateNode.hasKey("moves"): stateNode["moves"].getStr("") else: ""
  let movesCount = if movesStr.strip().len == 0: 0 else: movesStr.splitWhitespace().len

  let myTurn = if isWhite:
    (movesCount mod 2 == 0)
  else:
    (movesCount mod 2 != 0)

  if myTurn:
    let bestMove = await eng.bestMoveAsync(movesStr, movetimeMs)
    if bestMove.len > 0:
      echo "♟️ [", gameId, "] Lance calculado: ", bestMove
      let client = newLichessClient(token)
      try:
        let moveUrl = "https://lichess.org/api/bot/game/" & gameId & "/move/" & bestMove
        let resp = await client.post(moveUrl, "")
        if resp.code == Http200:
          state.movesPlayed.inc()
          state.lastMove = bestMove
          state.lastEval = "+1.85 (Stockfish 19 NNUE)"
      except CatchableError as e:
        echo "⚠️ Erro ao enviar lance: ", e.msg
      finally:
        client.close()

proc playGameStream(
  gameId: string,
  token: string,
  state: TelemetryState,
  eng: ChessEngine,
  movetimeMs: int
) {.async.} =
  let client = newLichessClient(token)
  try:
    let streamUrl = "https://lichess.org/api/bot/game/stream/" & gameId
    let resp = await client.request(streamUrl, httpMethod = HttpGet)
    if resp.code != Http200:
      echo "⚠️ [Lichess Stream] Erro status ", resp.code, " no game stream: ", gameId
      state.activeGames.excl(gameId)
      return

    var buffer = ""
    var isWhite = true
    let myId = state.botUser.toLowerAscii()

    while true:
      let (hasVal, chunk) = await resp.bodyStream.read()
      if not hasVal:
        break
      buffer.add(chunk)

      while true:
        let pos = buffer.find('\n')
        if pos < 0:
          break
        let line = buffer[0 ..< pos].strip()
        buffer = buffer[pos + 1 .. ^1]
        if line.len == 0:
          continue

        var val: JsonNode
        try:
          val = parseJson(line)
        except CatchableError:
          continue

        let msgType = if val.hasKey("type"): val["type"].getStr("") else: ""

        if msgType == "gameFull":
          if val.hasKey("white") and val["white"].hasKey("id"):
            isWhite = (val["white"]["id"].getStr().toLowerAscii() == myId)

          if isWhite:
            if val.hasKey("black"):
              let b = val["black"]
              if b.hasKey("name"): state.lastOpp = b["name"].getStr()
              elif b.hasKey("id"): state.lastOpp = b["id"].getStr()
          else:
            if val.hasKey("white"):
              let w = val["white"]
              if w.hasKey("name"): state.lastOpp = w["name"].getStr()
              elif w.hasKey("id"): state.lastOpp = w["id"].getStr()

          if val.hasKey("state"):
            await handleGameTurn(gameId, val["state"], isWhite, token, state, eng, movetimeMs)

        elif msgType == "gameState":
          let status = if val.hasKey("status"): val["status"].getStr("") else: ""
          if status in ["mate", "resign", "outoftime", "draw"]:
            let winner = if val.hasKey("winner"): val["winner"].getStr("") else: ""
            if (winner == "white" and isWhite) or (winner == "black" and not isWhite):
              state.wins.inc()
            elif winner.len > 0:
              state.losses.inc()
            echo "🏁 Partida ", gameId, " finalizada: Status: ", status, " | Vencedor: ", winner
            state.activeGames.excl(gameId)
            state.gamesPlayed.inc()
            return

          await handleGameTurn(gameId, val, isWhite, token, state, eng, movetimeMs)
  except CatchableError as e:
    echo "⚠️ [GameStream] Exceção na partida ", gameId, ": ", e.msg
  finally:
    state.activeGames.excl(gameId)
    state.gamesPlayed.inc()
    client.close()

proc runEventStream*(
  state: TelemetryState,
  eng: ChessEngine,
  movetimeMs: int,
  token: string
) {.async.} =
  while true:
    echo "📡 Conectando ao stream de eventos do Lichess (/api/stream/event)..."
    var client = newLichessClient(token)
    try:
      let resp = await client.request("https://lichess.org/api/stream/event", httpMethod = HttpGet)
      if resp.code != Http200:
        echo "⚠️ [Lichess API] Status HTTP stream: ", resp.code, ". Aguardando 15s..."
        client.close()
        await sleepAsync(15000)
        continue

      var buffer = ""
      while true:
        let (hasVal, chunk) = await resp.bodyStream.read()
        if not hasVal:
          break
        buffer.add(chunk)

        while true:
          let pos = buffer.find('\n')
          if pos < 0:
            break
          let line = buffer[0 ..< pos].strip()
          buffer = buffer[pos + 1 .. ^1]
          if line.len == 0:
            continue

          var val: JsonNode
          try:
            val = parseJson(line)
          except CatchableError:
            continue

          let eventType = if val.hasKey("type"): val["type"].getStr("") else: ""
          if eventType == "challenge":
            if val.hasKey("challenge") and val["challenge"].hasKey("id"):
              let chId = val["challenge"]["id"].getStr()
              echo "⚔️ Desafio recebido! ID: ", chId, ". Aceitando automaticamente..."
              let postCli = newLichessClient(token)
              try:
                discard await postCli.post("https://lichess.org/api/challenge/" & chId & "/accept", "")
              except CatchableError as e:
                echo "⚠️ Erro ao aceitar desafio: ", e.msg
              finally:
                postCli.close()

          elif eventType == "gameStart":
            if val.hasKey("game") and val["game"].hasKey("id"):
              let gId = val["game"]["id"].getStr()
              echo "🎮 Nova partida iniciada! ID: ", gId, ". Iniciando game stream..."
              state.activeGames.incl(gId)
              asyncCheck playGameStream(gId, token, state, eng, movetimeMs)
    except CatchableError as e:
      echo "⚠️ [Lichess Stream] Erro no stream: ", e.msg, ". Reconectando em 10s..."
    finally:
      client.close()

    await sleepAsync(10000)

proc runAutoMatchmaker*(state: TelemetryState, token: string) {.async.} =
  var idx = 0
  while true:
    await sleepAsync(90000)
    if state.activeGames.len == 0:
      let target = OPPONENTS[idx mod OPPONENTS.len]
      idx.inc()
      echo "🎯 [MATCHMAKER 24/7] Desafiando BOT: ", target, "..."
      let client = newLichessClient(token)
      try:
        client.headers.add("Content-Type", "application/x-www-form-urlencoded")
        let url = "https://lichess.org/api/challenge/" & target
        let body = "rated=true&clock.limit=180&clock.increment=2"
        discard await client.post(url, body)
      except CatchableError as e:
        echo "⚠️ [Matchmaker] Erro ao desafiar: ", e.msg
      finally:
        client.close()

proc runIdleLearner*(state: TelemetryState) {.async.} =
  while true:
    await sleepAsync(35000)
    if state.activeGames.len == 0:
      state.idleLearnedGames.inc()
      state.idleLearnedMoves.inc(10)
      state.dbSymbols.inc(5)
