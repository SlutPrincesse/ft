#!/bin/bash
set -euo pipefail
# angel-nl — Natural Language Interface for AngelKernel
# Users speak naturally, system translates to tool calls

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
BIN_DIR="$ANGEL_HOME/bin"
NL_MAP="$ANGEL_HOME/profiles/universal-agent.json"

# Parse natural language query and route to appropriate tool
nl_route() {
  local query="$1"
  local lower_query=$(echo "$query" | tr '[:upper:]' '[:lower:]')
  
  # Load natural language map
  local nl_map_json=$(cat "$NL_MAP" 2>/dev/null | python3 -c "
import json, sys
if len(sys.argv) > 1:
    data = json.loads(sys.argv[1])
    print(json.dumps(data.get('natural_language_map', {})))
" "$NL_MAP" 2>/dev/null)
  
  # Check for build/create/make patterns
  if echo "$lower_query" | grep -qE 'build|create|make|develop|setup'; then
    echo "[nl] Detected build/create intent → chain execute"
    bash "$BIN_DIR/angel-chain.sh" execute "$query"
    return $?
  fi
  
  # Check for deploy/publish/host patterns
  if echo "$lower_query" | grep -qE 'deploy|publish|host|release|launch'; then
    echo "[nl] Detected deploy intent → chain execute"
    bash "$BIN_DIR/angel-chain.sh" execute "$query"
    return $?
  fi
  
  # Check for fix/repair/broken patterns
  if echo "$lower_query" | grep -qE 'fix|repair|broken|error|issue|problem'; then
    echo "[nl] Detected fix intent → adapt auto"
    bash "$BIN_DIR/angel-adapt.sh" auto "$query"
    return $?
  fi
  
  # Check for install/get/setup patterns
  if echo "$lower_query" | grep -qE 'install|get|setup|add|download'; then
    echo "[nl] Detected install intent → skill-manager --search-and-install"
    bash "$BIN_DIR/angel-skill-manager.sh" --search-and-install "$query"
    return $?
  fi
  
  # Check for status/health/check patterns
  if echo "$lower_query" | grep -qE 'status|health|check|how.*going|what.*up'; then
    echo "[nl] Detected status intent → angel-status"
    bash "$BIN_DIR/angel-status" status
    return $?
  fi
  
  # Check for run/export/build patterns
  if echo "$lower_query" | grep -qE 'run|export|build|compile|test'; then
    echo "[nl] Detected run/build intent → chain execute"
    bash "$BIN_DIR/angel-chain.sh" execute "$query"
    return $?
  fi
  
  # Default: use kernel router
  echo "[nl] No specific pattern matched → kernel router"
  bash "$BIN_DIR/angel-kernel.sh" "$query"
}

# Handle todo-style natural language
nl_todo() {
  local todo_text="$1"
  echo "[nl] Converting natural todo to chain..."
  bash "$BIN_DIR/angel-chain.sh" from-todo "$todo_text"
}

# Main dispatch
case "${1:-}" in
  route) 
    shift
    nl_route "$@" 
    ;;
  todo)
    shift
    nl_todo "$@"
    ;;
  "")
    echo "AngelKernel Natural Language Interface"
    echo ""
    echo "Usage:"
    echo "  angel-nl route \"Build a Godot card game\""
    echo "  angel-nl route \"Deploy my web app\""
    echo "  angel-nl route \"Fix this broken code\""
    echo "  angel-nl route \"Install SQLite support\""
    echo "  angel-nl todo \"1. Setup project\n2. Write code\n3. Test\""
    echo ""
    echo "Just speak naturally - no tool memorization needed."
    ;;
  *)
    nl_route "$*"
    ;;
esac