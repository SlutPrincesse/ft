#!/usr/bin/env bash
set -euo pipefail

# install-openclaw.sh — register universal-cli-skills as an OpenClaw plugin.
#
# What it does:
#   1. Symlink the three toolkit skills into OpenClaw's skills dir
#      (~/.openclaw/skills, which is normally a symlink to ~/.shared-skills).
#   2. Place the packaged plugin (with its openclaw.plugin.json manifest) under
#      ~/.openclaw/plugins/universal-cli-skills so OpenClaw can resolve it by id.
#   3. Enable the plugin:
#        - if the `openclaw` CLI runs on a compatible Node version:
#            openclaw plugins enable universal-cli-skills
#        - otherwise: edit ~/.openclaw/openclaw.json to set
#            plugins.entries.universal-cli-skills.enabled = true
#
# Usage:
#   bash scripts/install-openclaw.sh [--copy] [--kind tool|skill] [--dry-run]
#
# NOTE: OpenClaw's gateway/daemon calls os.networkInterfaces() at startup
# (initSelfPresence). In some sandboxed environments that syscall returns
# EACCES ("Unknown system error 13") and the gateway cannot start. The CLI
# (--version/--help/config/plugins) still works. If the gateway won't start,
# run OpenClaw in a less-restricted environment.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_SRC="$REPO_ROOT/skills"
PLUGIN_SRC="$REPO_ROOT/../plugins/universal-cli-skills"

# Allow override of OpenClaw home (mirrors OPENCLAW_STATE_DIR conventions).
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
OPENCLAW_JSON="$OPENCLAW_HOME/openclaw.json"
PLUGINS_DIR="$OPENCLAW_HOME/plugins"
# OpenClaw's skills dir is often a symlink (~/.openclaw/skills -> ~/.shared-skills).
SKILLS_DIR="${OPENCLAW_HOME}/skills"

DRY_RUN=0
USE_SYMLINK=1
USE_COPY=0
PLUGIN_KIND="skill"  # or "tool"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Register universal-cli-skills as an OpenClaw plugin (skills + enable entry).

Options:
  --copy               Copy skills instead of symlinking (default: symlink)
  --kind KIND          Plugin manifest kind: "skill" (default) or "tool"
  --dry-run            Preview actions without making changes
  -h, --help           Show this help message
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy) USE_SYMLINK=0; USE_COPY=1; shift ;;
    --kind) PLUGIN_KIND="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# Select the manifest to install into the plugin (.openclaw-plugin/openclaw.plugin.json).
select_manifest() {
  local src="$PLUGIN_SRC/.openclaw-plugin"
  local chosen="$src/openclaw.plugin.json"
  if [[ "$PLUGIN_KIND" == "tool" ]]; then
    if [[ -f "$src/openclaw.plugin.tool.json" ]]; then
      chosen="$src/openclaw.plugin.tool.json"
    else
      echo "[WARN] --kind tool requested but openclaw.plugin.tool.json missing; using skill manifest." >&2
    fi
  fi
  echo "$chosen"
}

# Resolve the real skills target (follow the ~/.openclaw/skills symlink if present).
resolve_skills_dir() {
  if [[ -L "$SKILLS_DIR" ]]; then
    readlink -f "$SKILLS_DIR"
  elif [[ -d "$SKILLS_DIR" ]]; then
    echo "$SKILLS_DIR"
  else
    echo "$SKILLS_DIR"
  fi
}

SKILLS_REAL="$(resolve_skills_dir)"

log() { echo "$1"; }
skip() { echo "[SKIP] $1"; }
ok() { echo "[OK] $1"; }
dry() { echo "[DRY-RUN] $1"; }

# Node >= 22.22.3 (excluding 22.16), or >= 24.15, or >= 25.9 — matches openclaw's requirement.
node_ok() {
  local v
  v="$(node --version 2>/dev/null | tr -d 'v' | cut -d. -f1,2,3)"
  [[ -z "$v" ]] && return 1
  local major minor patch
  major="$(echo "$v" | cut -d. -f1)"
  minor="$(echo "$v" | cut -d. -f2)"
  patch="$(echo "$v" | cut -d. -f3)"
  # 24.x / 25.x fully supported.
  if [[ "$major" -ge 24 ]]; then
    if [[ "$major" -eq 24 && "$minor" -lt 15 ]]; then return 1; fi
    if [[ "$major" -eq 25 && "$minor" -lt 9 ]]; then return 1; fi
    return 0
  fi
  # 22.x: need >= 22.22.3 (and 22.16 is explicitly rejected).
  if [[ "$major" -eq 22 ]]; then
    if [[ "$minor" -gt 22 ]]; then return 0; fi
    if [[ "$minor" -eq 22 && "$patch" -ge 3 ]]; then return 0; fi
    return 1
  fi
  return 1
}

link_skill() {
  local name="$1"
  local src="$SKILL_SRC/$name"
  local target="$SKILLS_REAL/$name"
  if [[ ! -d "$src" ]]; then skip "skill source missing: $src"; return; fi
  if [[ -e "$target" || -L "$target" ]]; then skip "skill already present: $target"; return; fi
  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $USE_SYMLINK -eq 1 ]]; then dry "symlink $src -> $target"; else dry "copy $src -> $target"; fi
    return
  fi
  mkdir -p "$SKILLS_REAL"
  if [[ $USE_SYMLINK -eq 1 ]]; then
    ln -s "$src" "$target"; ok "symlinked skill $name -> $target"
  else
    cp -R "$src" "$target"; ok "copied skill $name -> $target"
  fi
}

install_plugin_dir() {
  local target="$PLUGINS_DIR/universal-cli-skills"
  if [[ ! -d "$PLUGIN_SRC" ]]; then
    echo "[WARN] packaged plugin not found at $PLUGIN_SRC; skipping plugin dir placement." >&2
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then skip "plugin dir already present: $target"; return; fi
  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $USE_SYMLINK -eq 1 ]]; then dry "symlink $PLUGIN_SRC -> $target"; else dry "copy $PLUGIN_SRC -> $target"; fi
    return
  fi
  mkdir -p "$PLUGINS_DIR"
  if [[ $USE_SYMLINK -eq 1 ]]; then
    ln -s "$PLUGIN_SRC" "$target"; ok "symlinked plugin -> $target"
  else
    cp -R "$PLUGIN_SRC" "$target"; ok "copied plugin -> $target"
  fi
  # Ensure the installed plugin exposes the requested manifest kind.
  local manifest; manifest="$(select_manifest)"
  if [[ -n "$manifest" && -f "$manifest" ]]; then
    if [[ $DRY_RUN -eq 0 ]]; then
      cp "$manifest" "$target/.openclaw-plugin/openclaw.plugin.json"
    fi
    ok "plugin manifest kind=$PLUGIN_KIND ($(basename "$manifest"))"
  fi
}

enable_via_cli() {
  if ! command -v openclaw >/dev/null 2>&1; then return 1; fi
  if ! node_ok; then
    echo "[INFO] openclaw requires Node >=22.22.3/24.15/25.9; current $(node --version 2>/dev/null) — using config edit fallback." >&2
    return 1
  fi
  if [[ $DRY_RUN -eq 1 ]]; then dry "openclaw plugins enable universal-cli-skills"; return 0; fi
  # Time-box the CLI call: openclaw can spawn the gateway and hang in some
  # environments, so fall back to a direct config edit if it doesn't return fast.
  if timeout 25 openclaw plugins enable universal-cli-skills >/dev/null 2>&1; then
    ok "enabled plugin via 'openclaw plugins enable universal-cli-skills'"
    return 0
  fi
  echo "[INFO] 'openclaw plugins enable' unavailable/timed out; using config edit." >&2
  return 1
}

enable_via_config() {
  if [[ ! -f "$OPENCLAW_JSON" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then dry "would create $OPENCLAW_JSON with universal-cli-skills enabled"; return; fi
    mkdir -p "$(dirname "$OPENCLAW_JSON")"
    printf '{\n  "plugins": {\n    "entries": {\n      "universal-cli-skills": { "enabled": true }\n    }\n  }\n}\n' > "$OPENCLAW_JSON"
    ok "created $OPENCLAW_JSON with universal-cli-skills enabled"
    return
  fi
  if [[ $DRY_RUN -eq 1 ]]; then dry "would set plugins.entries.universal-cli-skills.enabled=true in $OPENCLAW_JSON"; return; fi
  python3 - <<PY
import json, sys
p = "$OPENCLAW_JSON"
try:
    with open(p) as f:
        cfg = json.load(f)
except Exception as e:
    print(f"[ERROR] cannot read {p}: {e}", file=sys.stderr); sys.exit(1)
cfg.setdefault("plugins", {}).setdefault("entries", {})["universal-cli-skills"] = {"enabled": True}
with open(p, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("enabled universal-cli-skills in", p)
PY
  ok "set plugins.entries.universal-cli-skills.enabled=true in $OPENCLAW_JSON"
}

main() {
  log "== OpenClaw install: universal-cli-skills (kind=$PLUGIN_KIND) =="
  log "Skills target: $SKILLS_REAL"
  log "Plugin dir:    $PLUGINS_DIR/universal-cli-skills"
  log "Config:        $OPENCLAW_JSON"
  echo
  link_skill "skill-creator"
  link_skill "plugin-creator"
  link_skill "intake"
  install_plugin_dir
  echo
  if ! enable_via_cli; then
    enable_via_config
  fi
  echo
  log "Done. Verify with: openclaw plugins list && openclaw skills list"
  log "NOTE: OpenClaw's gateway calls os.networkInterfaces() at startup; in"
  log "sandboxed environments where that returns EACCES the gateway won't start."
}

main
