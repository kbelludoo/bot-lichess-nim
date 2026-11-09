# bot-lichess-nim ♟️

Lichess Autonomous Bot reescrito em **Nim 2.2** com 100% de paridade com as versões em Go e Rust.

## Recursos
- **Modo Berserk & Stockfish UCI:** Suporte a Stockfish 19 NNUE nativo com fallback heurístico instantâneo.
- **Lichess Event & Game Streaming:** Consumo assíncrono de streaming NDJSON via `asyncdispatch` / `httpclient`.
- **Matchmaker 24/7:** Desafia bots automaticamente quando ocioso.
- **Idle Learner Simulator:** Monitoramento e aprendizado contínuo sem partidas ativas.
- **Telemetria HTTP na Porta 3016:** Endpoints `/api/status` e `/status.json` com schema idêntico ao original.

## Compilação Cruzada (Linux x86_64 via Zig)
```powershell
nim c --os:linux --cpu:amd64 --gcc.exe:zigcc-linux-gnu.bat --gcc.linkerexe:zigcc-linux-gnu.bat -d:ssl -d:release -o:bot-lichess-linux-nim main.nim
```
