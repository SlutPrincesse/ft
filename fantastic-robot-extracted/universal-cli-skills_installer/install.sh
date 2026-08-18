#!/usr/bin/env bash
#
# universal-cli-skills Installer (wrapper)
# ----------------------------------------
# This package bundles the universal-cli-skills project. After extraction,
# run this script (or cd into universal-cli-skills and use its own install.sh)
# to install the skills into your coding CLI agent(s).
#
# Usage:
#   ./install.sh [--agent AGENT] [--copy] [--dry-run] [--prefix DIR] [--help]
#
set -euo pipefail

PREFIX="${PREFIX:-$HOME/universal-cli-skills}"

usage() {
  cat <<EOF
universal-cli-skills installer

Options:
  --prefix DIR   Where to extract the project (default: $PREFIX). The real
                 installer lives at \$PREFIX/universal-cli-skills/install.sh
  --agent AGENT  Target agent: codex, claude, kilo, aider, opencode, cursor,
                 gemini, openclaw, or all  (passed through to bundled installer)
  --copy         Copy skills instead of symlinking (passed through)
  --dry-run      Preview actions without making changes (passed through)
  --help         Show this help and exit
EOF
}

PASS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --agent|--copy|--dry-run|-h|--help) PASS+=("$1"); shift ;;
    --agent=*) PASS+=("$1"); shift ;;
    *) PASS+=("$1"); shift ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/universal-cli-skills"

echo "==> Extracting universal-cli-skills to: $PREFIX"
mkdir -p "$PREFIX"
( cd "$SRC" && tar cf - --exclude='__pycache__' --exclude='*.pyc' . ) | ( cd "$PREFIX" && tar xf - )

echo "==> Running bundled installer"
exec "$PREFIX/install.sh" "${PASS[@]:-all}"
