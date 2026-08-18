#!/bin/bash
set -euo pipefail
# angel-shell — Source this in .bashrc to get AngelKernel in your shell.
# Adds angel-* commands to PATH and sets up shell hooks.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"

export PATH="$ANGEL_HOME/bin:/usr/local/bin:$PATH"

# Auto-source config
[ -f "$ANGEL_HOME/config/angel.conf" ] && source "$ANGEL_HOME/config/angel.conf"

# RALPH shell hook — intercept commands for learning
angel_hook() {
  local last_cmd="$1"
  local last_ret="$2"
  if [ "$last_ret" -ne 0 ] && [ -n "$last_cmd" ]; then
    bash "$ANGEL_HOME/bin/angel-self-improve.sh" --error "shell" "bash" "Exit code $last_ret: $last_cmd" 2>/dev/null &
  fi
}

# Aliases
alias angel-start='angel-init'
alias angel-stop='angel-stop'
alias angel-status='angel-status'
alias angel-kernel='angel-kernel.sh'

echo "[AngelKernel] Loaded. PATH includes $ANGEL_HOME/bin"
