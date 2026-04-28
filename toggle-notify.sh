#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./toggle-notify.sh --i <ia> [--project] status
  ./toggle-notify.sh --i <ia> [--project] all on|off
  ./toggle-notify.sh --i <ia> [--project] idle on|off
  ./toggle-notify.sh --i <ia> [--project] error on|off
  ./toggle-notify.sh --i <ia> [--project] debug on|off
  ./toggle-notify.sh --i <ia> [--project] min <seconds|off>
  ./toggle-notify.sh --i <ia> [--project] test
  ./toggle-notify.sh --i <ia> [--project] last-error

Options:
  --i <ia>     Target AI/CLI (required)
  --project    Use plugin from current project (default: global)
  --help       Show this help

Notes:
  - all on   => enabled=true, idle=true, error=true
  - all off  => enabled=false, idle=false, error=false
  - idle/error on force enabled=true
  - min off  => minSessionSeconds=0
  - debug on => shows/saves detailed error
EOF
}

IA=""
SCOPE="global"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --i)
      if [[ $# -lt 2 ]]; then
        echo "Error: --i requires a value."
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
  echo "Error: --i is required."
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
    echo "Error: unsupported AI: $IA"
    echo "Currently supported: opencode"
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
    print("No error recorded yet.")
    raise SystemExit(0)

with open(state_file, "r", encoding="utf-8") as f:
    loaded = json.load(f)

last_error = loaded.get("lastError")
if not isinstance(last_error, dict):
    print("No error recorded yet.")
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
        "message": "Missing OPENCODE_TG_BOT_TOKEN/OPENCODE_TG_CHAT_ID environment variables.",
    }
    save_last_error(payload)
    print("FAILURE: missing environment variables.")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    raise SystemExit(1)

url = f"https://api.telegram.org/bot{token}/sendMessage"
body = {
    "chat_id": chat_id,
    "text": "OpenCode: test message /notify test",
    "disable_web_page_preview": True,
}
raw = json.dumps(body).encode("utf-8")
req = urllib.request.Request(url, data=raw, method="POST", headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req, timeout=20) as response:
        response_text = response.read().decode("utf-8", errors="replace")
        print(f"OK: test message sent (HTTP {response.status}).")
        print(response_text)
except urllib.error.HTTPError as err:
    response_text = err.read().decode("utf-8", errors="replace")
    payload = {
        "at": now,
        "scope": "manual-test",
        "status": err.code,
        "message": "HTTP failure while sending test to Telegram.",
        "body": response_text,
    }
    save_last_error(payload)
    print(f"FAILURE: HTTP {err.code}.")
    print(response_text)
    raise SystemExit(1)
except Exception as err:
    payload = {
        "at": now,
        "scope": "manual-test",
        "message": "Unexpected error while sending test to Telegram.",
        "error": str(err),
    }
    save_last_error(payload)
    print("FAILURE: unexpected error.")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    raise SystemExit(1)
PY
  exit 0
fi

TARGET="${1:-}"
MODE="${2:-}"

if [[ -z "$TARGET" || -z "$MODE" ]]; then
  echo "Error: insufficient parameters."
  usage
  exit 1
fi

if [[ "$TARGET" != "all" && "$TARGET" != "idle" && "$TARGET" != "error" && "$TARGET" != "debug" && "$TARGET" != "min" ]]; then
  echo "Error: invalid target: $TARGET"
  usage
  exit 1
fi

if [[ "$TARGET" == "min" ]]; then
  if [[ "$MODE" == "off" ]]; then
    MODE="0"
  fi
  if [[ ! "$MODE" =~ ^[0-9]+$ ]]; then
    echo "Error: min only accepts integer >= 0 or 'off'."
    usage
    exit 1
  fi
else
  if [[ "$MODE" != "on" && "$MODE" != "off" ]]; then
    echo "Error: invalid mode: $MODE"
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
echo "State updated at: $STATE_FILE"
