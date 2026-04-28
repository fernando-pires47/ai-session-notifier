#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Quick installer for ai-session-notifier

Usage:
  curl -fsSL https://raw.githubusercontent.com/fernando-pires47/ai-session-notifier/main/quick-install.sh | bash -s -- --i opencode [--project] [-v 1.0.0]

Options:
  -v, --v <version>     Version/tag to install (example: 1.0.0 or v1.0.0)
                        Default: main

Examples:
  bash quick-install.sh --i opencode
  bash quick-install.sh --i opencode --project -v 1.0.0
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

for bin in curl tar bash; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: required command not found: $bin"
    exit 1
  fi
done

REPO_OWNER="fernando-pires47"
REPO_NAME="ai-session-notifier"
REF="main"

INSTALL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--v)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires a value"
        usage
        exit 1
      fi
      REF="$2"
      shift 2
      ;;
    *)
      INSTALL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "$REF" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  REF="v$REF"
fi

ARCHIVE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/${REF}.tar.gz"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ARCHIVE_PATH="$TMP_DIR/${REPO_NAME}.tar.gz"

echo "Downloading ${REPO_NAME} (${REF})..."
if ! curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"; then
  if [[ "$REF" != "main" ]]; then
    ALT_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/${REF}.tar.gz"
    echo "Primary URL failed. Trying fallback format..."
    curl -fsSL "$ALT_URL" -o "$ARCHIVE_PATH"
  else
    echo "Error: failed to download installer archive from $ARCHIVE_URL"
    exit 1
  fi
fi

tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"

INSTALL_SCRIPT=""
if [[ -d "$TMP_DIR/${REPO_NAME}-${REF#v}" ]]; then
  INSTALL_SCRIPT="$TMP_DIR/${REPO_NAME}-${REF#v}/install.sh"
elif [[ -d "$TMP_DIR/${REPO_NAME}-${REF}" ]]; then
  INSTALL_SCRIPT="$TMP_DIR/${REPO_NAME}-${REF}/install.sh"
else
  FIRST_DIR="$(ls -1 "$TMP_DIR" | grep "^${REPO_NAME}-" | head -n 1 || true)"
  if [[ -n "$FIRST_DIR" ]]; then
    INSTALL_SCRIPT="$TMP_DIR/$FIRST_DIR/install.sh"
  fi
fi

if [[ -z "$INSTALL_SCRIPT" || ! -f "$INSTALL_SCRIPT" ]]; then
  echo "Error: could not locate install.sh in extracted archive"
  exit 1
fi

echo "Running install.sh from ${REF}..."
bash "$INSTALL_SCRIPT" "${INSTALL_ARGS[@]}"

echo
echo "Quick install finished."
