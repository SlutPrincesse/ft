#!/bin/bash
set -euo pipefail
# angel-autonomous — Ultra-Autonomous AngelKernel Engine
# Full self-directed operation with auto-tool creation, skill discovery, and evolution

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true

BIN_DIR="$ANGEL_HOME/bin"
AUTO_DIR="$ANGEL_HOME/autonomous"
mkdir -p "$AUTO_DIR"

# Auto-discover and install missing capabilities
auto_bootstrap() {
  local query="$*"
  angel_info "[auto] Bootstrapping for: ${query:0:60}..."
  
  # Analyze query
  local analysis
  analysis=$(bash "$BIN_DIR/angel-adapt.sh" analyze "$query" 2>/dev/null)
  
  # Check for missing skills
  local has_gaps
  has_gaps=$(echo "$analysis" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
keywords = d.get('skill_keywords', [])
need_skills = len(keywords) > 0
print('true' if need_skills else 'false')
" 2>/dev/null)
  
  if [ "$has_gaps" = "true" ]; then
    angel_info "[auto] Auto-installing skills..."
    bash "$BIN_DIR/angel-adapt.sh" auto "$query" 2>/dev/null | head -10
  fi
}

# Self-healing error recovery
self_heal() {
  local error="$1"
  local context="$2"
  
  angel_info "[auto] Self-healing from error..."
  
  # Analyze error pattern
  local pattern
  pattern=$(bash "$BIN_DIR/angel-evolve.sh" analyze "$error" "$context" 2>/dev/null)
  
  case "$pattern" in
    missing_tool)
      local tool_name
      tool_name=$(echo "$error" | grep -oP 'command not found:?\s*\K\w+' | head -1)
      [ -n "$tool_name" ] && bash "$BIN_DIR/angel-evolve.sh" create-tool "$tool_name" "$error" 2>/dev/null
      ;;
    missing_skill)
      bash "$BIN_DIR/angel-evolve.sh" install-skill "$context" 2>/dev/null
      ;;
  esac
}

# Full autonomous cycle with learning
autonomous_cycle() {
  local query="$*"
  local max_attempts="${ANGEL_MAX_AUTO_ATTEMPTS:-3}"
  
  angel_info "[auto] Starting autonomous cycle..."
  
  for attempt in $(seq 1 $max_attempts); do
    angel_info "[auto] Attempt $attempt/$max_attempts"
    
    # Bootstrap if needed
    auto_bootstrap "$query"
    
    # Execute
    local result
    result=$(bash "$BIN_DIR/angel-chain.sh" execute "$query" 2>/dev/null)
    local status="$?"
    
    if [ $status -eq 0 ] && echo "$result" | grep -qi "completed"; then
      angel_info "[auto] Success on attempt $attempt"
      echo "$result"
      return 0
    fi
    
    # Self-heal on failure
    if echo "$result" | grep -qi "error\|failed"; then
      self_heal "$(echo "$result" | head -c 200)" "$query"
    fi
  done
  
  echo '{"status": "failed", "attempts": '$max_attempts'}'
}

# Continuous learning daemon
continuous_learn() {
  local query="$*"
  
  # Run intensive analysis
  bash "$BIN_DIR/angel-intensive.sh" "$query" 2>/dev/null &
  local pid=$!
  
  # Also run adaptation
  bash "$BIN_DIR/angel-adapt.sh" auto "$query" 2>/dev/null &
  
  wait $pid $! 2>/dev/null
  
  angel_metric "autonomous.learning" 1 "{\"query\":\"$query\"}"
}

# Main
case "${1:-}" in
  bootstrap) auto_bootstrap "${*:2}" ;;
  heal) shift; self_heal "$@" ;;
  cycle) autonomous_cycle "$@" ;;
  learn) continuous_learn "$@" ;;
  daemon)
    while true; do
      angel_info "[auto] Daemon heartbeat $(date +%H:%M)"
      sleep 30
    done
    ;;
  *)
    echo "AngelKernel Autonomous Engine"
    echo "  bootstrap <query> — Install missing capabilities"
    echo "  heal <error> <context> — Self-heal from error"
    echo "  cycle <query> — Full autonomous cycle"
    echo "  learn <query> — Continuous learning"
    echo "  daemon — Run as continuous daemon"
    ;;
esac