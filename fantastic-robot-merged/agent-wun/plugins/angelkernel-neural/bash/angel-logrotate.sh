#!/bin/bash
# angel-logrotate — Log rotation for AngelKernel
set -euo pipefail

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
LOG_DIR="$ANGEL_HOME/logs"
MAX_SIZE=$((10 * 1024 * 1024))  # 10MB
MAX_FILES=5

echo "=== AngelKernel Log Rotation ==="

for logfile in "$LOG_DIR"/*.log; do
    [ -f "$logfile" ] || continue
    fname=$(basename "$logfile")
    
    # Get file size (portable across Linux/macOS)
    fsize=$(stat -c%s "$logfile" 2>/dev/null || stat -f%z "$logfile" 2>/dev/null || echo 0)
    
    if [ "$fsize" -gt "$MAX_SIZE" ]; then
        echo "  Rotating $fname ($(numfmt --to=iec $fsize 2>/dev/null || echo "${fsize}B"))"
        
        # Rotate: move existing backups
        for i in $(seq $((MAX_FILES - 1)) -1 1); do
            if [ -f "${logfile}.$i" ]; then
                mv "${logfile}.$i" "${logfile}.$((i + 1))"
            fi
        done
        
        # Move current to .1 and create new
        mv "$logfile" "${logfile}.1"
        touch "$logfile"
        
        # Compress old logs
        for i in $(seq 1 $MAX_FILES); do
            if [ -f "${logfile}.$i" ] && [ ! -f "${logfile}.$i.gz" ]; then
                gzip -k "${logfile}.$i" 2>/dev/null || true
            fi
        done
        
        # Remove old compressed logs
        find "$LOG_DIR" -name "${fname}.*.gz" -mtime +30 -delete 2>/dev/null
        
        echo "  Rotated $fname"
    else
        echo "  OK: $fname ($(numfmt --to=iec $fsize 2>/dev/null || echo "${fsize}B"))"
    fi
done

echo "Log rotation complete"
