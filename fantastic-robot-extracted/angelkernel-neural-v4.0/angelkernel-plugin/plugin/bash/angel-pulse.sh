#!/bin/bash
# angel-pulse — Health, repair, and growth daemon (runs via cron or loop)

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="pulse"
angel_console_init 2>/dev/null || true
BIN_DIR="$ANGEL_HOME/bin"
BACKUP_DIR="$ANGEL_HOME/backups"
LOG_DIR="$ANGEL_HOME/logs"
SKILLS_DIR="$ANGEL_HOME/skills"
PID_DIR="$ANGEL_HOME/run"

echo "[$(date)] === AngelKernel Pulse ==="

echo "[pulse] Backend health:"
for be in icm lean-ctx browser39 toktoken engram ghost loct; do
  if command -v "$be" &>/dev/null; then
    echo "  [OK] $be"
  else
    echo "  [MISSING] $be"
  fi
done

# KiloProxy health check + auto-restart
echo "[pulse] KiloProxy health..."
KPID_FILE="$PID_DIR/kilo-proxy.pid"
KPID=""
[ -f "$KPID_FILE" ] && KPID=$(cat "$KPID_FILE")
if [ -n "$KPID" ] && kill -0 "$KPID" 2>/dev/null; then
  echo "  [OK] kilo-proxy (PID $KPID)"
elif command -v kilo-proxy &>/dev/null; then
  angel_print "call" "PULSE RESTART" "kilo-proxy"
  echo "  [RESTART] kilo-proxy not running — starting..."
  bash "$BIN_DIR/angel-daemon.sh start" 2>/dev/null
fi

# AngelKernel proxy health check
ANGEL_PROXY_PID_FILE="$PID_DIR/proxy.pid"
if [ -f "$ANGEL_PROXY_PID_FILE" ]; then
  APID=$(cat "$ANGEL_PROXY_PID_FILE")
  if kill -0 "$APID" 2>/dev/null; then
    echo "  [OK] angel-proxy (PID $APID)"
  else
    echo "  [RESTART] angel-proxy not running — restarting..."
    nohup python3 "$BIN_DIR/angel-proxy.py" > "$LOG_DIR/proxy.log" 2>&1 &
    echo $! > "$ANGEL_PROXY_PID_FILE"
  fi
fi

# MCP health check
MCP_PID_FILE="$PID_DIR/mcp.pid"
if [ -f "$MCP_PID_FILE" ]; then
  MPID=$(cat "$MCP_PID_FILE")
  if kill -0 "$MPID" 2>/dev/null; then
    echo "  [OK] mcp (PID $MPID)"
  else
    echo "  [RESTART] mcp not running — restarting..."
    nohup python3 "$BIN_DIR/angel-mcp-multiplexer.py" > "$LOG_DIR/mcp.log" 2>&1 &
    echo $! > "$MCP_PID_FILE"
  fi
fi

echo "[pulse] Backup rotation: $(find "$BACKUP_DIR" -type f | wc -l) files"
find "$BACKUP_DIR" -type f -mtime +"${ANGEL_BACKUP_RETENTION_DAYS:-7}" -delete 2>/dev/null

# Disk cleanup — prevent disk exhaustion
echo "[pulse] Disk cleanup..."
DISK_USAGE=$(df "$ANGEL_HOME" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 85 ] 2>/dev/null; then
    echo "  [WARN] Disk usage at ${DISK_USAGE}% — cleaning up..."
    # Clean up old swarm sessions (>24 hours)
    if [ -d "$ANGEL_HOME/store/swarm" ]; then
        find "$ANGEL_HOME/store/swarm" -type d -name "SWARM-*" -mmin +1440 -exec rm -rf {} \; 2>/dev/null
    fi
    # Clean up old chain contexts (>7 days)
    if [ -d "$ANGEL_HOME/store/chains" ]; then
        find "$ANGEL_HOME/store/chains" -type f -name "context-*.json" -mtime +7 -delete 2>/dev/null
    fi
    # Clean up old context sessions (>2 hours)
    if [ -d "$ANGEL_HOME/context" ]; then
        find "$ANGEL_HOME/context" -type d \( -name "INT-*" -o -name "UNITY-*" \) -mmin +120 -exec rm -rf {} \; 2>/dev/null
    fi
    # Truncate large log files (>10MB)
    for logfile in "$LOG_DIR"/system.log "$LOG_DIR"/watchdog.log; do
        if [ -f "$logfile" ] && [ $(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0) -gt 10485760 ]; then
            tail -1000 "$logfile" > "${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
            echo "  [CLEAN] Truncated $logfile"
        fi
    done
    echo "  [CLEAN] Disk cleanup complete"
fi

# Pulse counter
PULSE_COUNTER=0
[ -f "$ANGEL_HOME/run/pulse_counter" ] && PULSE_COUNTER=$(cat "$ANGEL_HOME/run/pulse_counter" 2>/dev/null || echo 0)
PULSE_COUNTER=$((PULSE_COUNTER + 1))
echo "$PULSE_COUNTER" > "$ANGEL_HOME/run/pulse_counter"

bash "$BIN_DIR/angel-hooks.sh" fire "system:heartbeat" "{\"counter\":$PULSE_COUNTER}" "true" 2>/dev/null &

# ============================================================================
# NEURAL ENGINE — Every pulse runs neural cognition + auto-skill + error correction
# ============================================================================

# 1. Neural coherence check (every pulse)
if [ -f "$BIN_DIR/angel-neural.sh" ]; then
  bash "$BIN_DIR/angel-neural.sh" coherence 2>/dev/null &
  echo "[pulse] Neural coherence check"
fi

# 2. Fire pulse:tick hook
bash "$BIN_DIR/angel-hooks.sh" fire "pulse:tick" \
  "{\"counter\":$PULSE_COUNTER}" "true" 2>/dev/null &

# 3. Auto-skill scan (every 3rd pulse)
if [ $((PULSE_COUNTER % 3)) -eq 0 ] && [ -f "$BIN_DIR/angel-auto-skill.sh" ]; then
  bash "$BIN_DIR/angel-auto-skill.sh" --scan 2>/dev/null
  echo "[pulse] Auto-skill scan"
fi

# 4. Skill extraction from patterns
bash "$BIN_DIR/angel-self-improve.sh" --extract 2>/dev/null

# 5. Auto-skill cleanup (every 7th pulse)
if [ $((PULSE_COUNTER % 7)) -eq 0 ] && [ -f "$BIN_DIR/angel-auto-skill.sh" ]; then
  bash "$BIN_DIR/angel-auto-skill.sh" --cleanup 2>/dev/null &
fi

MEMORY_LOG_SIZE=0
LOG_FILE="$ANGEL_HOME/memory/interactions/log.tsv"
if [ -f "$LOG_FILE" ]; then MEMORY_LOG_SIZE=$(wc -l < "$LOG_FILE"); fi
echo "[pulse] Skills: $(ls "$SKILLS_DIR" 2>/dev/null | wc -w) | Memory: $MEMORY_LOG_SIZE entries"

# 6. Fire pulse:health for system status
if [ -f "$BIN_DIR/angel-doctor.sh" ]; then
  local issue_count
  issue_count=$(bash "$BIN_DIR/angel-doctor.sh" 2>/dev/null | grep -c "❌" || echo 0)
  if [ "$issue_count" -eq 0 ]; then
    bash "$BIN_DIR/angel-hooks.sh" fire "pulse:health-ok" "{}" "true" 2>/dev/null &
  elif [ "$issue_count" -le 2 ]; then
    bash "$BIN_DIR/angel-hooks.sh" fire "pulse:health-warn" \
      "{\"issues\":$issue_count}" "true" 2>/dev/null &
  else
    bash "$BIN_DIR/angel-hooks.sh" fire "pulse:health-critical" \
      "{\"issues\":$issue_count}" "true" 2>/dev/null &
    # Auto-trigger error correction for critical health
    bash "$BIN_DIR/angel-hooks.sh" fire "error:diagnosed" \
      "{\"error\":\"pulse health critical\",\"issues\":$issue_count}" "true" 2>/dev/null &
  fi
fi

# 7. Auto-discovery (every 5th pulse)
if [ $((PULSE_COUNTER % 5)) -eq 0 ] && [ -f "$ANGEL_HOME/bin/angel-adapt.sh" ]; then
  bash "$ANGEL_HOME/bin/angel-adapt.sh" scan 2>/dev/null &
  echo "[pulse] Auto-discovery scan"
fi

# 8. Evolution check (every 10th pulse)
if [ $((PULSE_COUNTER % 10)) -eq 0 ]; then
  bash "$BIN_DIR/angel-hooks.sh" fire "evolution:check" \
    "{\"trigger\":\"pulse:tick\",\"counter\":$PULSE_COUNTER}" "true" 2>/dev/null &
  bash "$BIN_DIR/angel-hooks-universal.sh" fire "evolution:cycle-start" \
    "{\"trigger\":\"pulse\",\"counter\":$PULSE_COUNTER}" "true" 2>/dev/null &
  echo "[pulse] Evolution cycle"
fi

# 9. Stale session cleanup (every 3rd pulse)
if [ $((PULSE_COUNTER % 3)) -eq 0 ] && [ -d "$ANGEL_HOME/context" ]; then
  find "$ANGEL_HOME/context" -type d \( -name "INT-*" -o -name "UNITY-*" \) -mmin +60 -exec rm -rf {} \; 2>/dev/null
fi

# 10. Log rotation (every 20th pulse)
if [ $((PULSE_COUNTER % 20)) -eq 0 ] && [ -f "$BIN_DIR/angel-logrotate.sh" ]; then
  bash "$BIN_DIR/angel-logrotate.sh" 2>/dev/null &
  bash "$BIN_DIR/angel-hooks.sh" fire "pulse:log-rotate" "{}" "true" 2>/dev/null &
  echo "[pulse] Log rotation"
fi

# 11. Recursive self-improvement (every 50th pulse)
if [ $((PULSE_COUNTER % 50)) -eq 0 ]; then
  echo "[pulse] Deep self-improvement cycle..."
  
  # Neural synthesis
  [ -f "$BIN_DIR/angel-neural.sh" ] && bash "$BIN_DIR/angel-neural.sh" coherence 2>/dev/null
  
  # Consolidate memory
  [ -f "$BIN_DIR/angel-cortex.sh" ] && bash "$BIN_DIR/angel-cortex.sh" consolidate 2>/dev/null
  
  # Auto-skill extraction
  [ -f "$BIN_DIR/angel-auto-skill.sh" ] && bash "$BIN_DIR/angel-auto-skill.sh" --pulse 2>/dev/null
  
  # Evolution check
  [ -f "$BIN_DIR/angel-self-improve.sh" ] && bash "$BIN_DIR/angel-self-improve.sh" --extract 2>/dev/null
  
  # Profile update
  [ -f "$BIN_DIR/angel-profile-update.sh" ] && bash "$BIN_DIR/angel-profile-update.sh" 2>/dev/null
  
  # Doctor report
  [ -f "$BIN_DIR/angel-doctor.sh" ] && bash "$BIN_DIR/angel-doctor.sh" 2>/dev/null > "$LOG_DIR/doctor-report-$(date +%Y%m%d-%H%M%S).log" 2>&1
  
  # Fire milestones
  bash "$BIN_DIR/angel-hooks.sh" fire "evolution:milestone" \
    "{\"milestone\":\"50-pulse\",\"counter\":$PULSE_COUNTER}" "true" 2>/dev/null &
  
  echo "[pulse] Deep self-improvement complete"
fi

echo "[$(date)] === Pulse Complete ==="
