#!/bin/bash
# angel-console v2.2 — Live Console Output for all AngelKernel CLI tools
# Shows real-time telemetry from all angel-* scripts, providers, subagents, chains, etc.
#
# Usage:
#   angel-console                  Live streaming mode (default)
#   angel-console live             Same as default
#   angel-console recent [N] [f]   Show last N entries, optional filter
#   angel-console errors           Live stream filtered to errors/warnings only
#   angel-console watch <script>   Live stream filtered to one script
#   angel-console stats            Live summary dashboard
#   angel-console export [file]    Export buffer to file
#   angel-console help             Show this help

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true

CONSOLE_BUFFER="$ANGEL_HOME/store/console-buffer.ndjson"
CONSOLE_PIPE="$ANGEL_HOME/run/console.pipe"

# ─── Color / Icon definitions ────────────────────────────────────────────────
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
COLOR_CALL='\033[36m'     # cyan
COLOR_MCP='\033[33m'      # yellow
COLOR_MEMORY='\033[35m'   # magenta
COLOR_DECISION='\033[32m' # green
COLOR_HOOK='\033[34m'     # blue
COLOR_PLUGIN='\033[94m'   # bright blue
COLOR_SWARM='\033[93m'    # bright yellow
COLOR_EVOLVE='\033[92m'   # bright green
COLOR_ERROR='\033[91m'    # bright red
COLOR_WARN='\033[93m'     # bright yellow (warning)
COLOR_OK='\033[32m'       # green
COLOR_INFO='\033[37m'     # white
COLOR_DEFAULT='\033[37m'  # white

# ─── Format a single JSON entry into a colored console line ───────────────────
console_format_line() {
  local line="$1"
  local ts event script func msg details depth
  
  # Parse JSON fields using python
  IFS=$'\x1f' read -r ts event script func msg details depth < <(
    echo "$line" | python3 -c "
import json, sys
line = sys.stdin.read().strip()
if not line: sys.exit(0)
try:
    d = json.loads(line)
    ts = d.get('ts', 0)
    event = d.get('event', 'info')
    script = d.get('script', '?')
    func = d.get('func', '-')
    msg = d.get('msg', '')
    details = d.get('details', '')
    depth = d.get('depth', 0)
    # Use \x1f separator for safe IFS splitting
    print(f'{ts}\x1f{event}\x1f{script}\x1f{func}\x1f{msg}\x1f{details}\x1f{depth}')
except Exception as e:
    print(f'0\x1finfo\x1fparse\x1ferror\x1fParse failed: {e}\x1f\x1f0')
" 2>/dev/null
  )
  
  [ -z "$ts" ] || [ "$ts" = "0" ] && [ -z "$msg" ] && { echo "$line"; return; }
  
  # Format timestamp
  local ts_str
  if [ "$ts" -gt 0 ] 2>/dev/null; then
    ts_str=$(date -d "@${ts%???}" +%H:%M:%S 2>/dev/null || date -r "${ts%???}" +%H:%M:%S 2>/dev/null || echo "??:??:??")
  else
    ts_str="??:??:??"
  fi
  
  # Select color and icon
  local color icon
  case "$event" in
    call)     color="$COLOR_CALL";     icon="➜" ;;
    mcp)      color="$COLOR_MCP";      icon="⚡" ;;
    memory)   color="$COLOR_MEMORY";   icon="🧠" ;;
    decision) color="$COLOR_DECISION"; icon="◆" ;;
    hook)     color="$COLOR_HOOK";     icon="⚙" ;;
    plugin)   color="$COLOR_PLUGIN";   icon="🔌" ;;
    swarm)    color="$COLOR_SWARM";    icon="🐝" ;;
    evolve)   color="$COLOR_EVOLVE";   icon="🔄" ;;
    error)    color="$COLOR_ERROR";    icon="✖" ;;
    warn)     color="$COLOR_WARN";     icon="⚠" ;;
    ok)       color="$COLOR_OK";       icon="✔" ;;
    info)     color="$COLOR_INFO";     icon="•" ;;
    *)        color="$COLOR_DEFAULT";  icon="·" ;;
  esac
  
  # Shorten long messages
  local msg_short="${msg:0:80}"
  local details_short=""
  [ -n "$details" ] && details_short=" ${DIM}| ${details:0:50}${RST}"
  
  # Depth indentation
  local depth_prefix=""
  [ "$depth" -gt 0 ] 2>/dev/null && depth_prefix=$(printf '%*s' "$depth" '' | tr ' ' '·')
  
  # Source label
  local source="${script}:${func}"
  source="${source:0:24}"
  
  # Event label
  local event_label="${event:0:8}"
  
  # Build line
  echo -e "${DIM}[${ts_str}]${RST} ${color}${icon} ${event_label}${RST} ${BOLD}${source}${RST} ${msg_short}${details_short}"
}

# ─── Format stream (read from stdin, output formatted lines) ──────────────────
console_format_stream() {
  local filter_event="${1:-}"
  local filter_script="${2:-}"
  
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Client-side filtering
    if [ -n "$filter_event" ]; then
      local line_event
      line_event=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('event',''))" 2>/dev/null)
      [ "$line_event" != "$filter_event" ] && [ "$filter_event" != "error" ] && continue
      [ "$filter_event" = "error" ] && [[ "$line_event" != "error" ]] && [[ "$line_event" != "warn" ]] && continue
    fi
    if [ -n "$filter_script" ]; then
      local line_script
      line_script=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('script',''))" 2>/dev/null)
      [[ "$line_script" != *"$filter_script"* ]] && continue
    fi
    console_format_line "$line"
  done
}

# ─── Mode: live stream ────────────────────────────────────────────────────────
console_live() {
  local filter="${1:-}"
  
  # Create FIFO if not exists
  angel_console_init
  
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║     AngelKernel Live Console — all tool calls in real-time  ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Watching: all angel-* scripts, providers, subagents, chains..."
  echo "  Filter:   ${filter:-none (showing all)}"
  echo "  Buffer:   $CONSOLE_BUFFER"
  echo "  PID:      $$"
  echo "  ────────────────────────────────────────────────────────────"
  echo ""
  
  # Show recent entries first as context
  if [ -f "$CONSOLE_BUFFER" ]; then
    local recent_count
    recent_count=$(wc -l < "$CONSOLE_BUFFER" 2>/dev/null || echo 0)
    if [ "$recent_count" -gt 0 ]; then
      local show_n=5
      [ "$recent_count" -lt "$show_n" ] && show_n=$recent_count
      echo -e "${DIM}── Last ${show_n} entries (buffer has ${recent_count}) ──${RST}"
      tail -n "$show_n" "$CONSOLE_BUFFER" 2>/dev/null | console_format_stream "$filter"
      echo -e "${DIM}── Live stream follows ──${RST}"
    fi
  fi
  
  # Watch the ring buffer file for changes (most reliable approach)
  # All angel_console writes go to console-buffer.ndjson, so tail -f catches everything.
  # The FIFO (console.pipe) is used for ultra-low-latency when directly connected.
  tail -n 0 -f "$CONSOLE_BUFFER" 2>/dev/null | console_format_stream "$filter"
}

# ─── Mode: recent entries ─────────────────────────────────────────────────────
console_recent() {
  local count="${1:-30}"
  local filter="${2:-}"
  
  if [ ! -f "$CONSOLE_BUFFER" ]; then
    echo "[console] No entries yet."
    exit 0
  fi
  
  local total
  total=$(wc -l < "$CONSOLE_BUFFER" 2>/dev/null || echo 0)
  
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║     AngelKernel Console — Recent Activity                  ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Total entries: $total  Showing: last $count  Filter: ${filter:-none}"
  echo ""
  
  # Apply optional filter
  if [ -n "$filter" ]; then
    # Filter in Python and pipe to formatter
    python3 -c "
import json, sys
filter_txt = '$filter'.lower()
lines = []
try:
    with open('$CONSOLE_BUFFER') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
                text = (d.get('event','') + ' ' + d.get('script','') + ' ' + d.get('func','') + ' ' + d.get('msg','')).lower()
                if filter_txt in text:
                    lines.append(line)
            except: pass
except FileNotFoundError:
    pass
for line in lines[-$count:]:
    print(line)
" 2>/dev/null | console_format_stream
  else
    tail -n "$count" "$CONSOLE_BUFFER" 2>/dev/null | console_format_stream
  fi
}

# ─── Mode: errors only live stream ────────────────────────────────────────────
console_errors() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║     AngelKernel Console — Errors & Warnings (live)         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  console_live "error"
}

# ─── Mode: watch specific script ──────────────────────────────────────────────
console_watch() {
  local script_filter="$1"
  if [ -z "$script_filter" ]; then
    echo "[console] Usage: angel-console watch <script_name>"
    echo "  Example: angel-console watch proxy"
    exit 1
  fi
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║     AngelKernel Console — Watching: ${script_filter}${RST}"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  console_live "" "$script_filter"
}

# ─── Mode: stats dashboard ────────────────────────────────────────────────────
console_stats() {
  if [ ! -f "$CONSOLE_BUFFER" ]; then
    echo "[console] No data yet."
    exit 0
  fi
  
  python3 -c "
import json, sys
from collections import Counter, defaultdict

events = []
scripts = Counter()
event_types = Counter()
funcs = Counter()
durations = []
total = 0

try:
    with open('$CONSOLE_BUFFER') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except: continue
            total += 1
            events.append(d)
            scripts[d.get('script','?')] += 1
            event_types[d.get('event','?')] += 1
            funcs[d.get('func','?')] += 1
except FileNotFoundError:
    print('[console] No buffer file yet.')
    sys.exit(0)

errors = event_types.get('error', 0)
warns = event_types.get('warn', 0)
calls = event_types.get('call', 0)
memory = event_types.get('memory', 0)
decisions = event_types.get('decision', 0)
hooks = event_types.get('hook', 0)
plugins = event_types.get('plugin', 0)
evolves = event_types.get('evolve', 0)
mcp = event_types.get('mcp', 0)

print()
print('╔══════════════════════════════════════════════════════════════╗')
print('║     AngelKernel Console — Activity Stats                   ║')
print('╚══════════════════════════════════════════════════════════════╝')
print()
print(f'  Total events: {total}')
print(f'  Calls:        {calls}  |  Memory ops:  {memory}  |  MCP: {mcp}')
print(f'  Decisions:    {decisions}  |  Hooks:       {hooks}   |  Plugins: {plugins}')
print(f'  Errors:       {errors}  |  Warnings:    {warns}   |  Evolve: {evolves}')
print()
print('  Top Scripts:')
for script, count in scripts.most_common(10):
    bar = '█' * min(count, 40)
    pct = count * 100 // total
    print(f'    {script:24s} {count:5d} ({pct:2d}%) {bar}')
print()
print('  Event Types:')
for ev, count in event_types.most_common():
    bar = '█' * min(count, 40)
    pct = count * 100 // total
    print(f'    {ev:12s} {count:4d} ({pct:2d}%) {bar}')
print()
d = list(scripts.items())
if d:
    print(f'  Unique scripts: {len(d)} | Top: {d[0][0]} ({d[0][1]} calls)')
" 2>/dev/null
}

# ─── Mode: export ─────────────────────────────────────────────────────────────
console_export() {
  local output="${1:-$ANGEL_HOME/logs/console-export-$(date +%Y%m%d-%H%M%S).log}"
  
  if [ ! -f "$CONSOLE_BUFFER" ]; then
    echo "[console] No entries to export."
    exit 0
  fi
  
  cat "$CONSOLE_BUFFER" | console_format_stream > "$output" 2>/dev/null
  local lines
  lines=$(wc -l < "$CONSOLE_BUFFER" 2>/dev/null || echo 0)
  echo "[console] Exported $lines entries to: $output"
}

# ─── Mode: TUI dashboard ──────────────────────────────────────────────────────
console_tui() {
  local interval="${1:-3}"

  if ! command -v watch &>/dev/null; then
    echo "[console] 'watch' command not found. Install it or use the live stream mode."
    echo "  Try: angel-console live"
    exit 1
  fi

  watch -n "$interval" -t "
echo ''
echo 'AngelKernel Live Console (TUI) — refreshing every ${interval}s'
echo ''
echo '── Last 15 entries ──'
if [ -f '${CONSOLE_BUFFER}' ]; then
  tail -15 '${CONSOLE_BUFFER}' 2>/dev/null | python3 -c '
import json, sys, time, collections

lines = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try: d = json.loads(line)
    except: continue
    lines.append(d)

total = len(lines)
calls = sum(1 for d in lines if d.get(\"event\") == \"call\")
errors = sum(1 for d in lines if d.get(\"event\") == \"error\")
mem = sum(1 for d in lines if d.get(\"event\") == \"memory\")
scripts = collections.Counter(d.get(\"script\",\"?\") for d in lines)

print(f\"Total: {total}  Calls: {calls}  Errors: {errors}  Memory: {mem}\")
print(\"Top scripts:\")
for s, c in scripts.most_common(5):
    print(f\"  {s}: {c}\")
print(\"\")
print(\"Event timeline (last 15):\")
for d in lines[-15:]:
    ts = d.get(\"ts\", 0)
    t = time.strftime(\"%H:%M:%S\", time.localtime(ts / 1000)) if ts else \"??:??:??\"
    ev = d.get(\"event\", \"?\")[:6]
    sc = d.get(\"script\", \"?\")[:15]
    msg = d.get(\"msg\", \"\")[:50]
    print(f\"  [{t}] {ev:6s} {sc:15s} {msg}\")
'
else
  echo '  No entries yet.'
fi
"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

# Ensure source was successful (even if lib not fully loaded, critical paths exist)
mkdir -p "$(dirname "$CONSOLE_BUFFER")" 2>/dev/null || true

case "${1:-}" in
  live|stream)
    shift 2>/dev/null || true
    console_live "$1"
    ;;
  recent|history|tail )
    shift
    console_recent "$1" "$2"
    ;;
  errors|warnings )
    console_errors
    ;;
  watch|filter )
    shift
    console_watch "$1"
    ;;
  stats|dashboard )
    console_stats
    ;;
  export|dump )
    shift
    console_export "$1"
    ;;
  tui|dashboard-live )
    shift
    console_tui "$1"
    ;;
  help|--help|-h )
    echo "AngelKernel Live Console v2.2"
    echo ""
    echo "Usage:"
    echo "  angel-console                     Live streaming mode (default)"
    echo "  angel-console live [filter]       Live stream, optional event filter"
    echo "  angel-console recent [N] [filter] Show last N entries"
    echo "  angel-console errors              Live stream: errors & warnings only"
    echo "  angel-console watch <script>      Live stream: filter by script name"
    echo "  angel-console stats               Activity statistics dashboard"
    echo "  angel-console export [file]       Export buffer to colored log file"
    echo "  angel-console tui                 TUI mode (requires 'watch' command)"
    echo ""
    echo "Examples:"
    echo "  angel-console                     # Watch everything live"
    echo "  angel-console watch proxy         # Only proxy/provider calls"
    echo "  angel-console watch subagent      # Only subagent activity"
    echo "  angel-console errors              # Only errors and warnings"
    echo "  angel-console recent 50           # Last 50 entries"
    echo "  angel-console recent 20 chain     # Last 20 chain-related entries"
    echo "  angel-console stats               # Show aggregated stats"
    echo "  angel-console export ~/console.log"
    ;;
  ''|* )
    if [ -z "$1" ]; then
      console_live
    else
      echo "Unknown mode: $1"
      echo "Usage: angel-console {live|recent|errors|watch|stats|export|tui|help}"
      exit 1
    fi
    ;;
esac
