#!/bin/bash
set -euo pipefail
# angel-edit — RALPH edit wrapper. Backup first, then edit, verify, and optionally review.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
BACKUP_DIR="$ANGEL_HOME/backups"
AUTO_MODE="${ANGEL_AUTO_MODE:-true}"
DEPTH="${ANGEL_DEPTH:-0}"

if [ $DEPTH -ge ${ANGEL_MAX_DEPTH:-5} ]; then
  echo "FATAL: Max depth reached."
  exit 1
fi

FILE="$1"
ACTION="${2:-patch}"

[ -z "$FILE" ] && { echo "Usage: angel-edit <file> [patch|create|overwrite]"; exit 1; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$(basename "$FILE").$TIMESTAMP.bak"

if [ -f "$FILE" ]; then
  cp "$FILE" "$BACKUP_PATH" && echo "[backup] $BACKUP_PATH"
fi

if [ "$ACTION" = "patch" ]; then
  # Read edit script from stdin and apply
  cat > /tmp/angel_edit_patch_$$.sh
  bash /tmp/angel_edit_patch_$$.sh
  rm -f /tmp/angel_edit_patch_$$.sh
elif [ "$ACTION" = "create" ]; then
  mkdir -p "$(dirname "$FILE")"
  cat > "$FILE"
fi

# No-stub verification
if [ -f "$FILE" ]; then
  STUBS=$(grep -cE '(TODO|FIXME|pass|not implemented|stub)' "$FILE" 2>/dev/null || echo 0)
  if [ "$STUBS" -gt 0 ]; then
    echo "[WARN] $STUBS stub(s) in $FILE"
    if [ "$AUTO_MODE" != "true" ] && [ -f "$BACKUP_PATH" ]; then
      cp "$BACKUP_PATH" "$FILE"
      echo "[REVERT] Reverted to backup"
      exit 1
    fi
  fi
fi

# Review gate
if [ "$AUTO_MODE" != "true" ] && [ -f "$BACKUP_PATH" ]; then
  diff "$BACKUP_PATH" "$FILE" 2>/dev/null || true
  read -p "Apply? (y/n) " -n 1 -r; echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && cp "$BACKUP_PATH" "$FILE" && echo "Reverted." && exit 1
fi

echo "[edit] $FILE — done"
