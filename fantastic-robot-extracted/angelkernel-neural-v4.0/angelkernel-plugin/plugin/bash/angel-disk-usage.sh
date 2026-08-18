#!/bin/bash
# angel-disk-usage — Disk usage monitoring and cleanup for AngelKernel
set -euo pipefail

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"

echo "=== AngelKernel Disk Usage Report ==="
echo ""

# Overall disk
echo "--- System Disk ---"
df -h / | tail -1
DISK_PCT=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
echo "Usage: ${DISK_PCT}%"
echo ""

# AngelKernel breakdown
echo "--- AngelKernel Breakdown ---"
for dir in bin skills memory logs store plugins hooks config context repos backups run; do
    path="$ANGEL_HOME/$dir"
    if [ -d "$path" ]; then
        size=$(du -sh "$path" 2>/dev/null | awk '{printf "%-8s", $1}')
        echo "  $size  $dir/"
    fi
done
echo ""

# Largest files
echo "--- Largest Files (>1MB) ---"
find "$ANGEL_HOME" -type f -size +1M -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | sort -rh | head -10
echo ""

# Stale files
echo "--- Stale Files ---"
STALE_SWARM=$(find "$ANGEL_HOME/store/swarm" -type d -name "SWARM-*" -mmin +1440 2>/dev/null | wc -l)
STALE_CONTEXT=$(find "$ANGEL_HOME/context" -type d \( -name "INT-*" -o -name "UNITY-*" \) -mmin +120 2>/dev/null | wc -l)
OLD_LOGS=$(find "$ANGEL_HOME/logs" -type f -size +10M 2>/dev/null | wc -l)
echo "  Stale swarm sessions (>24h): $STALE_SWARM"
echo "  Stale context sessions (>2h): $STALE_CONTEXT"
echo "  Large log files (>10MB): $OLD_LOGS"
echo ""

# Recommendations
echo "--- Recommendations ---"
if [ "$DISK_PCT" -gt 90 ]; then
    echo "  ⚠️  CRITICAL: Disk at ${DISK_PCT}% — immediate cleanup recommended"
    echo "  Run: angel-disk-usage --cleanup"
elif [ "$DISK_PCT" -gt 80 ]; then
    echo "  ⚠️  WARNING: Disk at ${DISK_PCT}% — cleanup recommended"
else
    echo "  ✅ Disk usage healthy at ${DISK_PCT}%"
fi

if [ "$STALE_SWARM" -gt 5 ]; then
    echo "  💡 Clean up $STALE_SWARM stale swarm sessions"
fi
if [ "$STALE_CONTEXT" -gt 3 ]; then
    echo "  💡 Clean up $STALE_CONTEXT stale context sessions"
fi

# Cleanup mode
if [ "${1:-}" = "--cleanup" ]; then
    echo ""
    echo "--- Running Cleanup ---"
    find "$ANGEL_HOME/store/swarm" -type d -name "SWARM-*" -mmin +1440 -exec rm -rf {} \; 2>/dev/null
    echo "  Cleaned stale swarm sessions"
    find "$ANGEL_HOME/context" -type d \( -name "INT-*" -o -name "UNITY-*" \) -mmin +120 -exec rm -rf {} \; 2>/dev/null
    echo "  Cleaned stale context sessions"
    find "$ANGEL_HOME/store/chains" -type f -name "context-*.json" -mtime +7 -delete 2>/dev/null
    echo "  Cleaned old chain contexts"
    for logfile in "$ANGEL_HOME/logs"/system.log "$ANGEL_HOME/logs"/watchdog.log; do
        if [ -f "$logfile" ]; then
            fsize=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
            if [ "$fsize" -gt 10485760 ]; then
                tail -1000 "$logfile" > "${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
                echo "  Truncated $logfile"
            fi
        fi
    done
    echo "  Cleanup complete"
    echo ""
    echo "Disk after cleanup:"
    df -h / | tail -1
fi
