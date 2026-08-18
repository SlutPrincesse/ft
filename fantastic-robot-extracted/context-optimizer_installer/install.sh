#!/usr/bin/env bash
#
# context-optimizer Installer
# ---------------------------
# This package bundles the context-optimizer plugin (a Codex/Kilo plugin that
# expands vague queries into professionally optimized prompts using a 6-stage
# reasoning pipeline). After extraction, run this script to install the plugin
# into your coding CLI agent(s).
#
# Usage:
#   ./install.sh [--agent AGENT] [--copy] [--dry-run] [--prefix DIR] [--help]
#
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.config/kilo/plugins}"

usage() {
  cat <<EOF
context-optimizer installer

Options:
  --prefix DIR   Where to install the plugin (default: $PREFIX)
  --agent AGENT  Target agent config dir: kilo, codex, or all (default: kilo)
  --copy         Copy files instead of leaving the package in place
  --dry-run      Preview actions without making changes
  --help         Show this help and exit
EOF
}

AGENT="kilo"
COPY=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent=*) AGENT="${1#*=}"; shift ;;
    --copy) COPY=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/context-optimizer"
DEST="$PREFIX/context-optimizer"

if [ "$DRY" -eq 1 ]; then
  echo "[dry-run] mkdir -p $DEST"
  echo "[dry-run] install context-optimizer -> $DEST (agent=$AGENT, copy=$COPY)"
  exit 0
fi

echo "==> Installing context-optimizer to: $DEST"
mkdir -p "$DEST"
if [ "$COPY" -eq 1 ]; then
  ( cd "$SRC" && tar cf - --exclude='__pycache__' --exclude='*.pyc' . ) | ( cd "$DEST" && tar xf - )
else
  ( cd "$SRC" && tar cf - --exclude='__pycache__' --exclude='*.pyc' . ) | ( cd "$DEST" && tar xf - )
fi

echo "==> Done. context-optimizer installed for agent(s): $AGENT"
echo "    Plugin manifest: $DEST/.codex-plugin/plugin.json"
