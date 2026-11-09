import std/[os, json]

type
  BotConfigFile* = object
    token*: string
    engine_path*: string
    db_path*: string
    port*: int
    move_time_ms*: int
    skill_level*: int
    mode*: string
    accept_rated*: bool
    accept_casual*: bool
    auto_learn*: bool
    auto_match*: bool
    idle_learn*: bool
    idle_min_rating*: int

proc defaultBotConfig*(): BotConfigFile =
  result.token = ""
  result.engine_path = "native"
  result.db_path = "chess.mbvmdb"
  result.port = 3016
  result.move_time_ms = 3000
  result.skill_level = 20
  result.mode = "berserk"
  result.accept_rated = true
  result.accept_casual = true
  result.auto_learn = true
  result.auto_match = true
  result.idle_learn = true
  result.idle_min_rating = 2200

proc loadConfig*(path: string): BotConfigFile =
  result = defaultBotConfig()
  if fileExists(path):
    try:
      let txt = readFile(path)
      let j = parseJson(txt)
      if j.hasKey("token"): result.token = j["token"].getStr()
      if j.hasKey("engine_path"): result.engine_path = j["engine_path"].getStr()
      if j.hasKey("db_path"): result.db_path = j["db_path"].getStr()
      if j.hasKey("port"): result.port = j["port"].getInt(3016)
      if j.hasKey("move_time_ms"): result.move_time_ms = j["move_time_ms"].getInt(3000)
      if j.hasKey("skill_level"): result.skill_level = j["skill_level"].getInt(20)
      if j.hasKey("mode"): result.mode = j["mode"].getStr("berserk")
      if j.hasKey("accept_rated"): result.accept_rated = j["accept_rated"].getBool(true)
      if j.hasKey("accept_casual"): result.accept_casual = j["accept_casual"].getBool(true)
      if j.hasKey("auto_learn"): result.auto_learn = j["auto_learn"].getBool(true)
      if j.hasKey("auto_match"): result.auto_match = j["auto_match"].getBool(true)
      if j.hasKey("idle_learn"): result.idle_learn = j["idle_learn"].getBool(true)
      if j.hasKey("idle_min_rating"): result.idle_min_rating = j["idle_min_rating"].getInt(2200)
    except CatchableError as e:
      echo "⚠️ Erro ao carregar config '", path, "': ", e.msg
