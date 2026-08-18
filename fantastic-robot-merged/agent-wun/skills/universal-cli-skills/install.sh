#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_CREATOR_SRC="$REPO_ROOT/skills/skill-creator"
PLUGIN_CREATOR_SRC="$REPO_ROOT/skills/plugin-creator"
INTAKE_SRC="$REPO_ROOT/skills/intake"
INTAKE_SCRIPT_SRC="$REPO_ROOT/scripts/intake.py"

AGENTS=()
DRY_RUN=0
USE_SYMLINK=1
USE_COPY=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] --agent AGENT

Install universal-cli-skills into supported coding CLI agent directories.

Options:
  --agent AGENT        Target agent: codex, claude, kilo, aider, opencode, cursor, gemini, openclaw, or all
  --copy               Copy skills instead of symlinking (default: symlink)
  --dry-run            Preview actions without making changes
  -h, --help           Show this help message
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      AGENTS+=("$2")
      shift 2
      ;;
    --copy)
      USE_SYMLINK=0
      USE_COPY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if [[ ${#AGENTS[@]} -eq 0 ]]; then
  echo "Error: --agent is required" >&2
  usage
fi

install_skill() {
  local agent_name="$1"
  local dest_dir="$2"
  local skill_name="$3"
  local skill_src="$4"

  if [[ ! -d "$skill_src" ]]; then
    echo "[SKIP] $agent_name: source skill missing at $skill_src"
    return
  fi

  if [[ ! -d "$dest_dir" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[DRY-RUN] $agent_name: would create directory $dest_dir"
    else
      mkdir -p "$dest_dir"
      echo "[OK] $agent_name: created directory $dest_dir"
    fi
  fi

  local target="$dest_dir/$skill_name"

  if [[ -e "$target" || -L "$target" ]]; then
    echo "[SKIP] $agent_name: $skill_name already exists at $target"
    return
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $USE_SYMLINK -eq 1 ]]; then
      echo "[DRY-RUN] $agent_name: would symlink $skill_src -> $target"
    else
      echo "[DRY-RUN] $agent_name: would copy $skill_src -> $target"
    fi
    return
  fi

  if [[ $USE_SYMLINK -eq 1 ]]; then
    ln -s "$skill_src" "$target"
    echo "[OK] $agent_name: symlinked $skill_name -> $target"
  else
    cp -R "$skill_src" "$target"
    echo "[OK] $agent_name: copied $skill_name -> $target"
  fi
}

install_intake() {
  local agent_name="$1"
  local dest_dir="$2"
  install_skill "$agent_name" "$dest_dir" "intake" "$INTAKE_SRC"
  # Also drop a copy of the intake runner script next to the skill for convenience.
  local script_dest="$dest_dir/intake/intake.py"
  if [[ -f "$INTAKE_SCRIPT_SRC" && ! -e "$script_dest" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[DRY-RUN] $agent_name: would copy intake.py -> $script_dest"
    else
      mkdir -p "$dest_dir/intake"
      cp "$INTAKE_SCRIPT_SRC" "$script_dest"
      echo "[OK] $agent_name: copied intake.py -> $script_dest"
    fi
  fi
}

install_for_agent() {
  local agent="$1"
  case "$agent" in
    codex)
      install_skill "codex" "${CODEX_HOME:-$HOME/.codex}/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "codex" "${CODEX_HOME:-$HOME/.codex}/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "codex" "${CODEX_HOME:-$HOME/.codex}/skills"
      ;;
    claude)
      install_skill "claude" "$HOME/.claude/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "claude" "$HOME/.claude/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "claude" "$HOME/.claude/skills"
      ;;
    kilo)
      install_skill "kilo" "$HOME/.config/kilo/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "kilo" "$HOME/.config/kilo/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "kilo" "$HOME/.config/kilo/skills"
      install_skill "kilo" "$HOME/.claude/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "kilo" "$HOME/.claude/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "kilo" "$HOME/.claude/skills"
      ;;
    aider)
      install_skill "aider" "$HOME/.aider/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "aider" "$HOME/.aider/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "aider" "$HOME/.aider/skills"
      ;;
    opencode)
      install_skill "opencode" "$HOME/.opencode/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "opencode" "$HOME/.opencode/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "opencode" "$HOME/.opencode/skills"
      ;;
    cursor)
      install_skill "cursor" "$HOME/.cursor/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "cursor" "$HOME/.cursor/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "cursor" "$HOME/.cursor/skills"
      ;;
    gemini)
      install_skill "gemini" "$HOME/.gemini/skills" "skill-creator" "$SKILL_CREATOR_SRC"
      install_skill "gemini" "$HOME/.gemini/skills" "plugin-creator" "$PLUGIN_CREATOR_SRC"
      install_intake "gemini" "$HOME/.gemini/skills"
      ;;
    openclaw)
      if [[ -x "$REPO_ROOT/scripts/install-openclaw.sh" ]]; then
        bash "$REPO_ROOT/scripts/install-openclaw.sh" ${DRY_RUN:+--dry-run} ${USE_COPY:+--copy}
      else
        echo "[SKIP] openclaw: scripts/install-openclaw.sh missing"
      fi
      ;;
    all)
      install_for_agent "codex"
      install_for_agent "claude"
      install_for_agent "kilo"
      install_for_agent "aider"
      install_for_agent "opencode"
      install_for_agent "cursor"
      install_for_agent "gemini"
      install_for_agent "openclaw"
      ;;
    *)
      echo "Unknown agent: $agent" >&2
      exit 1
      ;;
  esac
}

for agent in "${AGENTS[@]}"; do
  install_for_agent "$agent"
done
