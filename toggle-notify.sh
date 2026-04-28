#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./toggle-notify.sh --i <ia> [--project] status
  ./toggle-notify.sh --i <ia> [--project] all on|off
  ./toggle-notify.sh --i <ia> [--project] idle on|off
  ./toggle-notify.sh --i <ia> [--project] error on|off
  ./toggle-notify.sh --i <ia> [--project] debug on|off
  ./toggle-notify.sh --i <ia> [--project] min <segundos|off>
  ./toggle-notify.sh --i <ia> [--project] test
  ./toggle-notify.sh --i <ia> [--project] last-error

Opcoes:
  --i <ia>     IA/CLI alvo (obrigatorio)
  --project    Usa plugin do projeto atual (padrao: global)
  --help       Mostra esta ajuda

Notas:
  - all on   => enabled=true, idle=true, error=true
  - all off  => enabled=false, idle=false, error=false
  - idle/error on forcam enabled=true
  - min off  => minSessionSeconds=0
  - debug on => mostra/guarda erro detalhado
EOF
}

IA=""
SCOPE="global"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --i)
      if [[ $# -lt 2 ]]; then
        echo "Erro: --i requer um valor."
        usage
        exit 1
      fi
      IA="$2"
      shift 2
      ;;
    --project)
      SCOPE="project"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [[ -z "$IA" ]]; then
  echo "Erro: --i e obrigatorio."
  usage
  exit 1
fi

case "$IA" in
  opencode)
    if [[ "$SCOPE" == "project" ]]; then
      TARGET_DIR="$(pwd)/.opencode/plugins"
    else
      TARGET_DIR="$HOME/.config/opencode/plugins"
    fi
    ;;
  *)
    echo "Erro: IA nao suportada: $IA"
    echo "Atualmente suportadas: opencode"
    exit 1
    ;;
esac

STATE_FILE="$TARGET_DIR/telegram-notify.state.json"

ACTION="${1:-status}"

if [[ "$ACTION" == "on" || "$ACTION" == "off" ]]; then
  set -- all "$ACTION"
  ACTION="all"
fi

if [[ "$ACTION" == "status" ]]; then
  python3 - "$STATE_FILE" <<'PY'
import json
import os
import sys

state_file = sys.argv[1]

state = {
    "enabled": True,
    "idle": True,
    "error": False,
    "debugError": False,
    "minSessionSeconds": 60,
}
if os.path.exists(state_file):
    with open(state_file, "r", encoding="utf-8") as f:
        loaded = json.load(f)
    for key in ("enabled", "idle", "error", "debugError"):
        if isinstance(loaded.get(key), bool):
            state[key] = loaded[key]
    if isinstance(loaded.get("minSessionSeconds"), (int, float)):
        state["minSessionSeconds"] = max(0, int(loaded["minSessionSeconds"]))

print(json.dumps(state, indent=2))
PY
  exit 0
fi

if [[ "$ACTION" == "last-error" ]]; then
  python3 - "$STATE_FILE" <<'PY'
import json
import os
import sys

state_file = sys.argv[1]

if not os.path.exists(state_file):
    print("Nenhum erro registrado ainda.")
    raise SystemExit(0)

with open(state_file, "r", encoding="utf-8") as f:
    loaded = json.load(f)

last_error = loaded.get("lastError")
if not isinstance(last_error, dict):
    print("Nenhum erro registrado ainda.")
    raise SystemExit(0)

print(json.dumps(last_error, indent=2, ensure_ascii=False))
PY
  exit 0
fi

if [[ "$ACTION" == "test" ]]; then
  python3 - "$STATE_FILE" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

state_file = sys.argv[1]
token = os.environ.get("OPENCODE_TG_BOT_TOKEN")
chat_id = os.environ.get("OPENCODE_TG_CHAT_ID")

state = {
    "enabled": True,
    "idle": True,
    "error": False,
    "debugError": False,
    "minSessionSeconds": 60,
}
if os.path.exists(state_file):
    with open(state_file, "r", encoding="utf-8") as f:
        loaded = json.load(f)
    for key in ("enabled", "idle", "error", "debugError"):
        if isinstance(loaded.get(key), bool):
            state[key] = loaded[key]
    if isinstance(loaded.get("minSessionSeconds"), (int, float)):
        state["minSessionSeconds"] = max(0, int(loaded["minSessionSeconds"]))
    if isinstance(loaded.get("lastError"), dict):
        state["lastError"] = loaded["lastError"]

now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def save_last_error(data):
    state["lastError"] = data
    os.makedirs(os.path.dirname(state_file), exist_ok=True)
    with open(state_file, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)
        f.write("\n")

if not token or not chat_id:
    payload = {
        "at": now,
        "scope": "manual-test",
        "message": "Variáveis OPENCODE_TG_BOT_TOKEN/OPENCODE_TG_CHAT_ID ausentes.",
    }
    save_last_error(payload)
    print("FALHA: variáveis de ambiente ausentes.")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    raise SystemExit(1)

url = f"https://api.telegram.org/bot{token}/sendMessage"
body = {
    "chat_id": chat_id,
    "text": "OpenCode: mensagem de teste /notify test",
    "disable_web_page_preview": True,
}
raw = json.dumps(body).encode("utf-8")
req = urllib.request.Request(url, data=raw, method="POST", headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req, timeout=20) as response:
        response_text = response.read().decode("utf-8", errors="replace")
        print(f"OK: mensagem de teste enviada (HTTP {response.status}).")
        print(response_text)
except urllib.error.HTTPError as err:
    response_text = err.read().decode("utf-8", errors="replace")
    payload = {
        "at": now,
        "scope": "manual-test",
        "status": err.code,
        "message": "Falha HTTP ao enviar teste para Telegram.",
        "body": response_text,
    }
    save_last_error(payload)
    print(f"FALHA: HTTP {err.code}.")
    print(response_text)
    raise SystemExit(1)
except Exception as err:
    payload = {
        "at": now,
        "scope": "manual-test",
        "message": "Erro inesperado ao enviar teste para Telegram.",
        "error": str(err),
    }
    save_last_error(payload)
    print("FALHA: erro inesperado.")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    raise SystemExit(1)
PY
  exit 0
fi

TARGET="${1:-}"
MODE="${2:-}"

if [[ -z "$TARGET" || -z "$MODE" ]]; then
  echo "Erro: parametros insuficientes."
  usage
  exit 1
fi

if [[ "$TARGET" != "all" && "$TARGET" != "idle" && "$TARGET" != "error" && "$TARGET" != "debug" && "$TARGET" != "min" ]]; then
  echo "Erro: alvo invalido: $TARGET"
  usage
  exit 1
fi

if [[ "$TARGET" == "min" ]]; then
  if [[ "$MODE" == "off" ]]; then
    MODE="0"
  fi
  if [[ ! "$MODE" =~ ^[0-9]+$ ]]; then
    echo "Erro: min aceita apenas numero inteiro >= 0 ou 'off'."
    usage
    exit 1
  fi
else
  if [[ "$MODE" != "on" && "$MODE" != "off" ]]; then
    echo "Erro: modo invalido: $MODE"
    usage
    exit 1
  fi
fi

python3 - "$STATE_FILE" "$TARGET" "$MODE" <<'PY'
import json
import os
import sys

state_file = sys.argv[1]
target = sys.argv[2]
mode = sys.argv[3]
on = mode == "on"

state = {
    "enabled": True,
    "idle": True,
    "error": False,
    "debugError": False,
    "minSessionSeconds": 60,
}
if os.path.exists(state_file):
    with open(state_file, "r", encoding="utf-8") as f:
        loaded = json.load(f)
    for key in ("enabled", "idle", "error", "debugError"):
        if isinstance(loaded.get(key), bool):
            state[key] = loaded[key]
    if isinstance(loaded.get("minSessionSeconds"), (int, float)):
        state["minSessionSeconds"] = max(0, int(loaded["minSessionSeconds"]))

if target == "all":
    state["enabled"] = on
    state["idle"] = on
    state["error"] = on
elif target == "idle":
    state["idle"] = on
    if on:
        state["enabled"] = True
elif target == "error":
    state["error"] = on
    if on:
        state["enabled"] = True
elif target == "debug":
    state["debugError"] = on
elif target == "min":
    state["minSessionSeconds"] = max(0, int(mode))

os.makedirs(os.path.dirname(state_file), exist_ok=True)
with open(state_file, "w", encoding="utf-8") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(json.dumps(state, indent=2))
PY

echo
echo "State atualizado em: $STATE_FILE"
