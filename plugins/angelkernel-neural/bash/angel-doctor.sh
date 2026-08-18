#!/bin/bash
# angel-doctor.sh — Full system diagnostic for AngelKernel
set -euo pipefail

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
BIN_DIR="$ANGEL_HOME/bin"
LOG_DIR="$ANGEL_HOME/logs"
PID_DIR="$ANGEL_HOME/run"

ISSUES=0
WARNINGS=0

issue() { echo "  ❌ $1"; ISSUES=$((ISSUES + 1)); }
warn() { echo "  ⚠️  $1"; WARNINGS=$((WARNINGS + 1)); }
ok() { echo "  ✅ $1"; }
info() { echo "  ℹ️  $1"; }

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  AngelKernel Doctor — Full System Diagnostic               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Services
echo "━━━ Services ━━━"
for pf in "$PID_DIR"/*.pid; do
    [ -f "$pf" ] || continue
    pid=$(cat "$pf" 2>/dev/null)
    name=$(basename "$pf" .pid)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        ok "$name (PID $pid)"
    else
        issue "$name is DOWN (stale PID: ${pid:-none})"
    fi
done
echo ""

# 2. MCP Health
echo "━━━ MCP v2 ━━━"
if curl -s --max-time 2 http://127.0.0.1:8200/health 2>/dev/null | grep -q "ok"; then
    TOOLS=$(curl -s --max-time 2 http://127.0.0.1:8200/health | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['tools_count'])" 2>/dev/null || echo "?")
    ok "MCP v2 healthy ($TOOLS tools)"
else
    issue "MCP v2 not responding on port 8200"
fi
echo ""

# 3. Port conflicts
echo "━━━ Ports ━━━"
for port in 8200 8201 5380; do
    if (echo >/dev/tcp/127.0.0.1/$port 2>/dev/null); then
        ok "Port $port: in use"
    else
        warn "Port $port: not in use"
    fi
done
echo ""

# 4. Hook registry
echo "━━━ Hook Registry ━━━"
if [ -f "$ANGEL_HOME/store/hook_registry.json" ]; then
    DUPS=$(python3 -c "
import json
d = json.load(open('$ANGEL_HOME/store/hook_registry.json'))
dupes = sum(1 for h in d.get('hooks',{}).values() if len(h) > 1)
print(dupes)
" 2>/dev/null || echo 0)
    if [ "$DUPS" -gt 0 ]; then
        issue "$DUPS events have duplicate hook registrations"
    else
        ok "No duplicate hooks"
    fi
else
    warn "Hook registry not found"
fi
echo ""

# 5. Memory Cortex
echo "━━━ Memory Cortex ━━━"
if [ -f "$BIN_DIR/angel-cortex.sh" ]; then
    L1=$(find "$ANGEL_HOME/memory/cortex/l1_working" -type f ! -name '*.ttl' 2>/dev/null | wc -l)
    L2=$(wc -l < "$ANGEL_HOME/memory/cortex/l2_episodic/log.ndjson" 2>/dev/null || echo 0)
    L3=$(wc -l < "$ANGEL_HOME/memory/cortex/l3_semantic/knowledge.jsonl" 2>/dev/null || echo 0)
    L4=$(wc -l < "$ANGEL_HOME/memory/cortex/l4_procedural/skills.jsonl" 2>/dev/null || echo 0)
    ok "L1:$L1 L2:$L2 L3:$L3 L4:$L4"
    
    # Check L3 quality
    LOW_CONF=$(python3 -c "
import json
c = 0
with open('$ANGEL_HOME/memory/cortex/l3_semantic/knowledge.jsonl') as f:
    for line in f:
        try:
            e = json.loads(line.strip())
            if e.get('confidence',0) < 0.3: c += 1
        except: pass
print(c)
" 2>/dev/null || echo 0)
    if [ "$LOW_CONF" -gt 5 ]; then
        warn "$LOW_CONF low-confidence L3 concepts (consider consolidation)"
    fi
else
    issue "angel-cortex.sh not found"
fi
echo ""

# 6. Evolution system
echo "━━━ Evolution System ━━━"
if [ -f "$ANGEL_HOME/store/evolution/evolution.json" ]; then
    EVOS=$(python3 -c "import json; print(json.load(open('$ANGEL_HOME/store/evolution/evolution.json')).get('total_evolutions',0))" 2>/dev/null || echo 0)
    ok "Evolutions recorded: $EVOS"
else
    issue "Evolution database not found"
fi
echo ""

# 7. Disk usage
echo "━━━ Disk ━━━"
DISK_PCT=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_PCT" -gt 90 ]; then
    issue "Disk at ${DISK_PCT}% — critical!"
elif [ "$DISK_PCT" -gt 80 ]; then
    warn "Disk at ${DISK_PCT}% — consider cleanup"
else
    ok "Disk at ${DISK_PCT}%"
fi
ANGEL_SIZE=$(du -sh "$ANGEL_HOME" 2>/dev/null | awk '{print $1}')
info "AngelKernel size: $ANGEL_SIZE"
echo ""

# 8. Log health
echo "━━━ Logs ━━━"
for logfile in system.log watchdog.log; do
    fpath="$LOG_DIR/$logfile"
    if [ -f "$fpath" ]; then
        fsize=$(stat -c%s "$fpath" 2>/dev/null || echo 0)
        if [ "$fsize" -gt 10485760 ]; then
            warn "$logfile is $(numfmt --to=iec $fsize 2>/dev/null || echo "${fsize}B") — consider rotation"
        else
            ok "$logfile: $(numfmt --to=iec $fsize 2>/dev/null || echo "${fsize}B")"
        fi
    fi
done
echo ""

# 9. Script health
echo "━━━ Scripts ━━━"
SYNTAX_ERRORS=0
for f in "$BIN_DIR"/angel-*.sh; do
    result=$(bash -n "$f" 2>&1)
    if [ -n "$result" ]; then
        issue "Syntax error in $(basename $f)"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done
[ $SYNTAX_ERRORS -eq 0 ] && ok "All $(ls "$BIN_DIR"/angel-*.sh 2>/dev/null | wc -l) scripts pass syntax"
echo ""

# 10. Config
echo "━━━ Config ━━━"
if bash -n "$ANGEL_HOME/config/angel.conf" 2>/dev/null; then
    ok "Config syntax valid"
else
    issue "Config syntax error"
fi
echo ""

# Summary
echo "══════════════════════════════════════════════════════════════"
if [ $ISSUES -gt 0 ]; then
    echo "  ❌ $ISSUES issue(s), $WARNINGS warning(s) found"
    echo "  Run: angel-disk-usage.sh --cleanup (if disk issue)"
    echo "  Run: angel-logrotate.sh (if log issue)"
    echo "  Run: angel-init (if service issue)"
elif [ $WARNINGS -gt 0 ]; then
    echo "  ⚠️  $WARNINGS warning(s) — system operational"
else
    echo "  ✅ ALL CHECKS PASS — System healthy"
fi
echo "══════════════════════════════════════════════════════════════"
