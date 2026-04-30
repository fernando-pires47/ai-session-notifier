#!/usr/bin/env bash
set -euo pipefail

detect_os() {
  local uname_out
  uname_out="$(uname -s 2>/dev/null || true)"
  case "$uname_out" in
    Linux)
      echo "linux"
      ;;
    Darwin)
      echo "macos"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "windows"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

ensure_supported_os() {
  local os
  os="$(detect_os)"

  case "$os" in
    linux|macos)
      return 0
      ;;
    windows)
      echo "Error: unsupported OS environment (Windows detected)."
      echo "This installer requires a Unix-like shell and tools."
      echo "Use WSL on Windows, then run the installer again."
      exit 1
      ;;
    *)
      echo "Error: unsupported OS environment."
      echo "Supported systems: Linux and macOS."
      exit 1
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  ./install.sh --i <ia> [--project]

Supported OS:
  Linux and macOS
  Windows: use WSL

Options:
  --i <ia>     Target AI/CLI for installation (required)
               Supported platform(s): opencode only
  --project    Install in current project (default: global)
  --help       Show this help

Examples:
  ./install.sh --i opencode
  ./install.sh --i opencode --project
EOF
}

IA=""
SCOPE="global"

ensure_supported_os

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
      echo "Error: invalid argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$IA" ]]; then
  echo "Error: --i is required."
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SOURCE="$SCRIPT_DIR/telegram-notify.plugin.js"
TOGGLE_SOURCE="$SCRIPT_DIR/toggle-notify.sh"

if [[ ! -f "$PLUGIN_SOURCE" ]]; then
  echo "Error: plugin not found at $PLUGIN_SOURCE"
  exit 1
fi

if [[ ! -f "$TOGGLE_SOURCE" ]]; then
  echo "Error: toggle script not found at $TOGGLE_SOURCE"
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
    echo "Error: unsupported platform '$IA'."
    echo "Supported platform(s): opencode"
    echo "Example: ./install.sh --i opencode"
    exit 1
    ;;
esac

mkdir -p "$TARGET_DIR"
install -m 0644 "$PLUGIN_SOURCE" "$TARGET_DIR/telegram-notify.plugin.js"
install -m 0755 "$TOGGLE_SOURCE" "$TARGET_DIR/toggle-notify.sh"

STATE_FILE="$TARGET_DIR/telegram-notify.state.json"
python3 - "$STATE_FILE" <<'PY'
import json
import os
import sys

state_file = sys.argv[1]

defaults = {
    "enabled": True,
    "idle": True,
    "error": False,
    "debugError": False,
    "minSessionSeconds": 60,
}

state = {}
if os.path.exists(state_file):
    try:
        with open(state_file, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, dict):
            state = loaded
    except Exception:
        state = {}

for key, value in defaults.items():
    state.setdefault(key, value)

os.makedirs(os.path.dirname(state_file), exist_ok=True)
with open(state_file, "w", encoding="utf-8") as f:
    json.dump(state, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

rm -f "$TARGET_DIR/telegram-notify.config.json"

echo "Plugin installed successfully."
echo "IA: $IA"
echo "Scope: $SCOPE"
echo "Destination: $TARGET_DIR/telegram-notify.plugin.js"
echo "State file: $STATE_FILE"
echo "Error notification (default): false"
echo "Error debug (default): false"
echo "Minimum duration (default): 60s"

if [[ "$SCOPE" == "project" ]]; then
  COMMAND_TARGET_DIR="$(pwd)/.opencode/commands"
  TOGGLE_COMMAND="$(pwd)/.opencode/plugins/toggle-notify.sh"
  COMMAND_ARGS="--project"
else
  COMMAND_TARGET_DIR="$HOME/.config/opencode/commands"
  TOGGLE_COMMAND="$HOME/.config/opencode/plugins/toggle-notify.sh"
  COMMAND_ARGS=""
fi

mkdir -p "$COMMAND_TARGET_DIR"
cat > "$COMMAND_TARGET_DIR/notify.md" <<EOF
---
description: Controls Telegram notifications (status/on/off/min)
---
Run the command below and reply with the result objectively.

!\`"$TOGGLE_COMMAND" --i opencode $COMMAND_ARGS \$ARGUMENTS\`

Rules:
- If no arguments are provided, show status.
- Shortcuts: \`on\` = \`all on\`; \`off\` = \`all off\`.
- Minimum duration: \`min <seconds>\` or \`min off\`.
- Send test: \`test\`.
- Error debug: \`debug on\` or \`debug off\`.
- Last error: \`last-error\`.
EOF

echo
echo "Set environment variables before opening OpenCode:"
echo "  export OPENCODE_TG_BOT_TOKEN='<your_bot_token>'"
echo "  export OPENCODE_TG_CHAT_ID='<your_chat_id>'"
echo
echo "Custom command installed: $COMMAND_TARGET_DIR/notify.md"
echo "Usage in OpenCode: /notify test | /notify debug on | /notify last-error"
