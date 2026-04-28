#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./install.sh --i <ia> [--project]

Opcoes:
  --i <ia>     IA/CLI alvo da instalacao (obrigatorio)
  --project    Instala no projeto atual (padrao: global)
  --help       Mostra esta ajuda

Exemplos:
  ./install.sh --i opencode
  ./install.sh --i opencode --project
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
      echo "Erro: argumento invalido: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$IA" ]]; then
  echo "Erro: --i e obrigatorio."
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SOURCE="$SCRIPT_DIR/telegram-notify.plugin.js"
TOGGLE_SOURCE="$SCRIPT_DIR/toggle-notify.sh"

if [[ ! -f "$PLUGIN_SOURCE" ]]; then
  echo "Erro: plugin nao encontrado em $PLUGIN_SOURCE"
  exit 1
fi

if [[ ! -f "$TOGGLE_SOURCE" ]]; then
  echo "Erro: script de toggle nao encontrado em $TOGGLE_SOURCE"
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

echo "Plugin instalado com sucesso."
echo "IA: $IA"
echo "Escopo: $SCOPE"
echo "Destino: $TARGET_DIR/telegram-notify.plugin.js"
echo "Arquivo state: $STATE_FILE"
echo "Notificacao de erro (default): false"
echo "Debug de erro (default): false"
echo "Duracao minima (default): 60s"

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
description: Controla notificacoes Telegram (status/on/off/min)
---
Execute o comando abaixo e responda com o resultado de forma objetiva.

!\`"$TOGGLE_COMMAND" --i opencode $COMMAND_ARGS \$ARGUMENTS\`

Regras:
- Se sem argumentos, mostrar status.
- Atalhos: \`on\` = \`all on\`; \`off\` = \`all off\`.
- Duracao minima: \`min <segundos>\` ou \`min off\`.
- Teste de envio: \`test\`.
- Debug de erro: \`debug on\` ou \`debug off\`.
- Ultimo erro: \`last-error\`.
EOF

echo
echo "Configure as variaveis de ambiente antes de abrir o OpenCode:"
echo "  export OPENCODE_TG_BOT_TOKEN='<seu_bot_token>'"
echo "  export OPENCODE_TG_CHAT_ID='<seu_chat_id>'"
echo
echo "Comando customizado instalado: $COMMAND_TARGET_DIR/notify.md"
echo "Uso no OpenCode: /notify test | /notify debug on | /notify last-error"
