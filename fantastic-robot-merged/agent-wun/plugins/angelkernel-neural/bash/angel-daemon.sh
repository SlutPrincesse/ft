#!/bin/bash
set -euo pipefail
# angel-daemon — Manages lifecycle of all AngelKernel sub-daemons (ICM, lean-ctx, browser39, kilo-proxy, etc.)

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
CONFIG_FILE="$ANGEL_HOME/config/angel.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

PID_DIR="$ANGEL_HOME/run"
LOG_DIR="$ANGEL_HOME/logs"
mkdir -p "$PID_DIR" "$LOG_DIR"

# Daemon backends — installed if binaries exist
DAEMONS=(
  "icm:icm serve:ANGEL_MEMORY_PORT:3032"
  "lean-ctx:lean-ctx serve:ANGEL_CTX_PORT:3879"
  "browser39:browser39 mcp:ANGEL_BROWSER_PORT:0"
  "toktoken:toktoken serve:ANGEL_TOKTOKEN_PORT:0"
  "engram:engram mcp:ANGEL_ENGRAM_PORT:0"
  "ghost:ghost mcp-serve:ANGEL_GHOST_PORT:0"
)

start_daemon() {
  local name="$1" cmd="$2" port_var="$3" default_port="$4"
  local pid_file="$PID_DIR/$name.pid"
  local log_file="$LOG_DIR/$name.log"

  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    return 0
  fi

  echo "[daemon] Starting $name..."
  $cmd > "$log_file" 2>&1 & disown
  local pid=$!
  sleep 1
  if kill -0 $pid 2>/dev/null; then
    echo $pid > "$pid_file"
    echo "[daemon] $name started (PID $pid)"
  else
    echo "[daemon] $name FAILED to start"
    cat "$log_file" | tail -5
    rm -f "$pid_file"
  fi
}

stop_daemon() {
  local name="$1"
  local pid_file="$PID_DIR/$name.pid"
  if [ -f "$pid_file" ]; then
    kill "$(cat "$pid_file")" 2>/dev/null && echo "[daemon] $name stopped"
    rm -f "$pid_file"
  fi
}

start_kilo_proxy() {
  local pid_file="$PID_DIR/kilo-proxy.pid"
  local log_file="$LOG_DIR/kilo-proxy.log"
  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "[daemon] kilo-proxy already running (PID $(cat "$pid_file"))"
    return 0
  fi
  echo "[daemon] Starting kilo-proxy..."
  if command -v kilo-proxy &>/dev/null; then
    kilo-proxy start 2>/dev/null & disown
    sleep 2
    # Read PID from the status command
    KILO_PID=$(kilo-proxy status 2>/dev/null | grep -oP 'PID: \K\d+')
    if [ -n "$KILO_PID" ]; then
      echo "$KILO_PID" > "$pid_file"
      echo "[daemon] kilo-proxy started (PID $KILO_PID)"
    else
      echo "[daemon] kilo-proxy failed to start"
    fi
  else
    echo "[daemon] kilo-proxy binary not found — install with: npm install -g kilo-proxy"
  fi
}

stop_kilo_proxy() {
  local pid_file="$PID_DIR/kilo-proxy.pid"
  if [ -f "$pid_file" ]; then
    local pid=$(cat "$pid_file")
    kill "$pid" 2>/dev/null && echo "[daemon] kilo-proxy stopped (PID $pid)"
    rm -f "$pid_file"
  fi
  # Also try kilo-proxy stop
  if command -v kilo-proxy &>/dev/null; then
    kilo-proxy stop 2>/dev/null
  fi
}

case "${1:-status}" in
  start)
    echo "=== Starting AngelKernel Daemons ==="
    start_kilo_proxy
    # Start MCP v2 if enabled (config already loaded in the angel-init flow)
    if [ "${ANGEL_MCP_V2_ENABLED:-false}" = "true" ] && [ -f "$ANGEL_HOME/bin/angel-mcp-v2.py" ]; then
      local mcp_pid_file="$PID_DIR/mcp.pid"
      if [ ! -f "$mcp_pid_file" ] || ! kill -0 "$(cat "$mcp_pid_file")" 2>/dev/null; then
        echo "[daemon] Starting MCP v2 server..."
        python3 "$ANGEL_HOME/bin/angel-mcp-v2.py" > "$LOG_DIR/mcp.log" 2>&1 & disown
        echo $! > "$mcp_pid_file"
      fi
    fi
    for entry in "${DAEMONS[@]}"; do
      IFS=':' read -r name cmd port_var default_port <<< "$entry"
      start_daemon "$name" "$cmd" "$port_var" "$default_port"
    done
    ;;
  stop)
    echo "=== Stopping AngelKernel Daemons ==="
    stop_kilo_proxy
    stop_daemon "mcp"
    for entry in "${DAEMONS[@]}"; do
      IFS=':' read -r name _ <<< "$entry"
      stop_daemon "$name"
    done
    ;;
  restart)
    "$0" stop; sleep 1; "$0" start
    ;;
  watchdog)
    INTERVAL="${2:-30}"
    MCP_PORT="${ANGEL_MCP_PORT:-8200}"
    echo "[watchdog] Monitoring kilo-proxy + MCP v2 every ${INTERVAL}s"
    while true; do
      # Check kilo-proxy
      KPID_FILE="$PID_DIR/kilo-proxy.pid"
      KPID=""
      [ -f "$KPID_FILE" ] && KPID=$(cat "$KPID_FILE")
      if [ -n "$KPID" ] && kill -0 "$KPID" 2>/dev/null; then
        : # running
      elif command -v kilo-proxy &>/dev/null; then
        echo "[watchdog] kilo-proxy down! Restarting..."
        start_kilo_proxy
      fi
      # Check MCP v2 health (if enabled)
      if [ "${ANGEL_MCP_V2_ENABLED:-false}" = "true" ]; then
        MPID_FILE="$PID_DIR/mcp.pid"
        MPID=""
        [ -f "$MPID_FILE" ] && MPID=$(cat "$MPID_FILE")
        if [ -n "$MPID" ] && kill -0 "$MPID" 2>/dev/null; then
          # Health check using bash /dev/tcp with retry (avoid false positives)
          if (echo >/dev/tcp/127.0.0.1/${MCP_PORT}) 2>/dev/null; then
            : # MCP healthy — port is open
          else
            # Wait briefly and retry to avoid false positives during transient load
            sleep 2
            if (echo >/dev/tcp/127.0.0.1/${MCP_PORT}) 2>/dev/null; then
              : # MCP recovered on retry — was a transient blip
            else
              echo "[watchdog] MCP v2 not responding on port ${MCP_PORT} (confirmed after retry)! Restarting..."
              kill "$MPID" 2>/dev/null
              python3 "$ANGEL_HOME/bin/angel-mcp-v2.py" > "$LOG_DIR/mcp.log" 2>&1 & disown
              echo $! > "$MPID_FILE"
            fi
          fi
        else
          echo "[watchdog] MCP v2 down! Restarting..."
          python3 "$ANGEL_HOME/bin/angel-mcp-v2.py" > "$LOG_DIR/mcp.log" 2>&1 & disown
          echo $! > "$MPID_FILE"
        fi
      fi
      sleep "$INTERVAL"
    done
    ;;
  status)
    echo "=== AngelKernel Daemon Status ==="
    KILO_PID=""
    if command -v kilo-proxy &>/dev/null; then
      KILO_PID=$(kilo-proxy status 2>/dev/null | grep -i "PID" | grep -oE '[0-9]+' | head -1)
    fi
    KPID_FILE="$PID_DIR/kilo-proxy.pid"
    if [ -f "$KPID_FILE" ] && kill -0 "$(cat "$KPID_FILE")" 2>/dev/null; then
      echo "  [RUNNING] kilo-proxy (PID $(cat "$KPID_FILE"))"
    elif command -v kilo-proxy &>/dev/null && kilo-proxy status 2>/dev/null | grep -q "Running"; then
      echo "  [RUNNING] kilo-proxy (external)"
    else
      echo "  [STOPPED] kilo-proxy"
    fi
    # MCP v2 status
    MCP_PID_FILE="$PID_DIR/mcp.pid"
    if [ -f "$MCP_PID_FILE" ] && kill -0 "$(cat "$MCP_PID_FILE")" 2>/dev/null; then
      echo "  [RUNNING] mcp-v2 (PID $(cat "$MCP_PID_FILE"))"
    else
      echo "  [STOPPED] mcp-v2"
    fi
    for entry in "${DAEMONS[@]}"; do
      IFS=':' read -r name _ <<< "$entry"
      pid_file="$PID_DIR/$name.pid"
      if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "  [RUNNING] $name (PID $(cat "$pid_file"))"
      else
        echo "  [STOPPED] $name"
      fi
    done
    ;;
  *)
    echo "Usage: angel-daemon {start|stop|restart|status|watchdog}"
    ;;
esac
