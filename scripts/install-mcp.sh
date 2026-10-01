#!/usr/bin/env bash
# Registra o servidor MCP do app Chaves.
#
#   ./scripts/install-mcp.sh            # imprime o JSON
#   ./scripts/install-mcp.sh cursor     # escreve em ~/.cursor/mcp.json
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_NAME="chaves"
TARGET="${1:-print}"

for candidate in \
  "/Applications/Chaves.app/Contents/MacOS/Chaves" \
  "$ROOT/dist/Chaves.app/Contents/MacOS/Chaves" \
  "$ROOT/.build/release/Chaves"; do
  if [ -x "$candidate" ]; then
    BIN="$candidate"
    break
  fi
done

if [ -z "${BIN:-}" ]; then
  echo "Erro: binário não encontrado. Rode 'make app' (ou 'make build') antes." >&2
  exit 1
fi

case "$TARGET" in
  print)
    cat <<JSON
{
  "mcpServers": {
    "$SERVER_NAME": {
      "command": "$BIN",
      "args": ["--mcp"]
    }
  }
}
JSON
    ;;

  cursor)
    CONFIG="$HOME/.cursor/mcp.json"
    mkdir -p "$(dirname "$CONFIG")"
    [ -f "$CONFIG" ] || echo '{"mcpServers":{}}' > "$CONFIG"
    cp "$CONFIG" "$CONFIG.bak.$(date +%s)"

    BIN="$BIN" SERVER_NAME="$SERVER_NAME" CONFIG="$CONFIG" python3 <<'PY'
import json, os

config_path = os.environ["CONFIG"]
name = os.environ["SERVER_NAME"]

with open(config_path) as handle:
    config = json.load(handle)

servers = config.setdefault("mcpServers", {})
servers[name] = {"command": os.environ["BIN"], "args": ["--mcp"]}

with open(config_path, "w") as handle:
    json.dump(config, handle, indent=2, ensure_ascii=False)
    handle.write("\n")

print(f"Registrado '{name}' em {config_path}")
PY
    echo "Backup salvo ao lado do arquivo. Reinicie o Cursor para carregar o servidor."
    ;;

  *)
    echo "Alvo desconhecido: $TARGET (use 'print' ou 'cursor')" >&2
    exit 1
    ;;
esac
