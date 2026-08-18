#!/bin/bash
# angel-observe — Observability, metrics, and performance dashboard.
#
# Tracks:
#   - System metrics (CPU, memory, processes)
#   - Performance metrics (execution time, success rate)
#   - Memory metrics (cortex size, recall frequency)
#   - Model metrics (responses, tokens, latency)
#   - Evolution metrics (skills extracted, errors, improvements)
#
# Dashboard modes:
#   - live: real-time metrics stream
#   - report: comprehensive system report
#   - graph: trend visualization (ASCII)
#   - export: JSON export for external monitoring

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="observe"
angel_console_init 2>/dev/null || true

METRICS_FILE="$ANGEL_HOME/store/metrics.ndjson"
REPORT_DIR="$ANGEL_HOME/logs/reports"
mkdir -p "$REPORT_DIR"

# === Collect system metrics ===
observe_system() {
  local metrics="{"
  
  # CPU
  local cpu_load
  cpu_load=$(uptime | grep -oE 'load average: [0-9.]+' | grep -oE '[0-9.]+$' 2>/dev/null || echo 0)
  metrics+="\"cpu_load\": $cpu_load,"
  
  # Memory
  local mem_total mem_used mem_percent
  if [ -f /proc/meminfo ]; then
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_used=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_percent=$(python3 -c "print(round(100 - ($mem_used * 100.0 / $mem_total), 1))" 2>/dev/null)
    metrics+="\"memory_percent\": $mem_percent,"
  fi
  
  # Disk
  local disk_percent
  disk_percent=$(df "$ANGEL_HOME" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo 0)
  metrics+="\"disk_percent\": $disk_percent,"
  
  # Processes
  local proc_count
  proc_count=$(ps aux 2>/dev/null | wc -l || echo 0)
  metrics+="\"processes\": $proc_count,"
  
  # Uptime
  local uptime_seconds
  uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
  metrics+="\"uptime\": $uptime_seconds"
  
  metrics+="}"
  echo "$metrics"
}

# === Collect AngelKernel metrics ===
observe_kernel() {
  local metrics="{"
  
  # RALPH loop stats
  local ralph_count=0
  [ -f "$ANGEL_HOME/memory/interactions/log.tsv" ] && ralph_count=$(wc -l < "$ANGEL_HOME/memory/interactions/log.tsv" 2>/dev/null)
  ralph_count=$(echo "$ralph_count" | tr -d ' ')
  metrics+="\"ralph_loops\": $ralph_count,"
  
  # SuperLoop stats
  local superloop_count=0
  [ -f "$ANGEL_HOME/memory/interactions/superloop.tsv" ] && superloop_count=$(wc -l < "$ANGEL_HOME/memory/interactions/superloop.tsv")
  metrics+="\"superloop_runs\": $superloop_count,"
  
  # Memory stats
  local episodic_count=0 semantic_count=0 procedural_count=0
  [ -f "$ANGEL_HOME/memory/cortex/l2_episodic/log.ndjson" ] && episodic_count=$(wc -l < "$ANGEL_HOME/memory/cortex/l2_episodic/log.ndjson")
  [ -f "$ANGEL_HOME/memory/cortex/l3_semantic/knowledge.jsonl" ] && semantic_count=$(wc -l < "$ANGEL_HOME/memory/cortex/l3_semantic/knowledge.jsonl")
  [ -f "$ANGEL_HOME/memory/cortex/l4_procedural/skills.jsonl" ] && procedural_count=$(wc -l < "$ANGEL_HOME/memory/cortex/l4_procedural/skills.jsonl")
  metrics+="\"episodic_memories\": $episodic_count,"
  metrics+="\"semantic_concepts\": $semantic_count,"
  metrics+="\"procedural_skills\": $procedural_count,"
  
  # Error count
  local error_count=0
  [ -f "$ANGEL_HOME/memory/learnings/ERRORS.md" ] && error_count=$(grep -c '^\*\*' "$ANGEL_HOME/memory/learnings/ERRORS.md" 2>/dev/null)
  [ -z "$error_count" ] && error_count=0
  metrics+="\"errors\": $error_count,"
  
  # Learning count
  local learning_count=0
  [ -f "$ANGEL_HOME/memory/learnings/LEARNINGS.md" ] && learning_count=$(grep -c '^\*\*' "$ANGEL_HOME/memory/learnings/LEARNINGS.md" 2>/dev/null)
  [ -z "$learning_count" ] && learning_count=0
  metrics+="\"learnings\": $learning_count,"
  
  # Skill count
  local skill_count
  skill_count=$(ls "$ANGEL_HOME/skills" 2>/dev/null | wc -l)
  metrics+="\"skills\": $skill_count,"
  
  # Daemon status
  local daemons_running=0 daemons_total=0
  for pid_file in "$ANGEL_HOME/run"/*.pid; do
    [ -f "$pid_file" ] || continue
    daemons_total=$((daemons_total + 1))
    kill -0 "$(cat "$pid_file")" 2>/dev/null && daemons_running=$((daemons_running + 1))
  done
  metrics+="\"daemons_running\": $daemons_running,"
  metrics+="\"daemons_total\": $daemons_total,"
  
  # Swarm stats
  local swarm_sessions=0
  swarm_sessions=$(ls -d "$ANGEL_HOME/store/swarm"/SWARM-* 2>/dev/null | wc -l)
  metrics+="\"swarm_sessions\": $swarm_sessions"
  
  metrics+="}"
  echo "$metrics"
}

# === Record a metric point ===
observe_record() {
  local name="$1" value="$2" labels="${3:-}"
  angel_metric "$name" "$value" "$labels"
}

# === Generate ASCII trend graph ===
observe_graph() {
  local metric_name="$1" window="${2:-50}"
  
  python3 -c "
import json, sys
from collections import deque

values = deque(maxlen=$window)
try:
    with open('$METRICS_FILE') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except: continue
            if d.get('name') == '$metric_name':
                values.append(d.get('value', 0))
except FileNotFoundError:
    print(f'No data for $metric_name')
    sys.exit(0)

if not values:
    print(f'No data for $metric_name')
    sys.exit(0)

max_val = max(values) or 1
min_val = min(values)
height = 10
width = min(len(values), 80)

# Normalize
normalized = [int((v - min_val) / (max_val - min_val + 1) * height) for v in values]

# Draw
for y in range(height, -1, -1):
    line = ''
    for v in normalized:
        line += '█' if v >= y else ' '
    print(f'{y * (max_val - min_val) // height + min_val:>8} |{line}')

print(f'         +{\"─\" * width}')
print(f'         Time →')
print(f'')
print(f'Metric: $metric_name')
print(f'Min: {min_val}  Max: {max_val}  Avg: {sum(values)/len(values):.1f}  Latest: {values[-1]}')
" 2>/dev/null
}

# === Generate comprehensive report ===
observe_report() {
  local format="${1:-text}"
  local report_file="$REPORT_DIR/report-$(date +%Y%m%d-%H%M%S)"
  
  local sys_metrics kernel_metrics
  
  sys_metrics=$(observe_system)
  kernel_metrics=$(observe_kernel)
  
  # Merge metrics
  local full_report
  full_report=$(python3 -c "
import json
s = json.loads('$sys_metrics')
k = json.loads('$kernel_metrics')
s.update(k)
print(json.dumps(s, indent=2))
" 2>/dev/null)
  
  if [ "$format" = "json" ]; then
    echo "$full_report" > "${report_file}.json"
    echo "Report written: ${report_file}.json"
    echo "$full_report"
  else
    # Text format
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║     AngelKernel Observability Report             ║"
    echo "║     $(date)              ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "── System ──"
    echo "  CPU Load:       $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cpu_load','?'))")"
    echo "  Memory:         $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('memory_percent','?'))")%"
    echo "  Disk:           $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('disk_percent','?'))")%"
    echo "  Processes:      $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('processes','?'))")"
    echo "  Uptime:         $(echo "$full_report" | python3 -c "
import json
s = json.load(sys.stdin)
u = s.get('uptime', 0)
days = u // 86400
hours = (u % 86400) // 3600
mins = (u % 3600) // 60
print(f'{days}d {hours}h {mins}m')
")"
    echo ""
    echo "── Kernel ──"
    echo "  RALPH Loops:    $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ralph_loops','?'))")"
    echo "  SuperLoops:     $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('superloop_runs','?'))")"
    echo "  Errors:         $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('errors','?'))")"
    echo "  Learnings:      $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('learnings','?'))")"
    echo ""
    echo "── Memory Cortex ──"
    echo "  Episodic:       $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('episodic_memories','?'))")"
    echo "  Semantic:       $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('semantic_concepts','?'))")"
    echo "  Procedural:     $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('procedural_skills','?'))")"
    echo ""
    echo "── Agents ──"
    echo "  Skills:         $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('skills','?'))")"
    echo "  Daemons:        $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('daemons_running','?'))")/$(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('daemons_total','?'))") running"
    echo "  Swarm Sessions: $(echo "$full_report" | python3 -c "import json,sys; print(json.load(sys.stdin).get('swarm_sessions','?'))")"
    echo ""
    
    # Recent activity graph if metrics available
    if [ -f "$METRICS_FILE" ]; then
      local metric_count
      metric_count=$(wc -l < "$METRICS_FILE")
      if [ "$metric_count" -gt 5 ]; then
        echo "── Activity (RALPH loops) ──"
        observe_graph "angel_ralph" 40 2>/dev/null || true
        echo ""
        echo "── Success Rate ──"
        observe_graph "angel_success" 40 2>/dev/null || true
      fi
    fi
    
    echo "╚══════════════════════════════════════════════════╝"
    
    # Save text report
    echo "$full_report" > "${report_file}.json"
    echo "" > "${report_file}.txt"
    # Performance benchmark
    echo ""
    echo "── Performance ──"
    observe_benchmark 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); [print(f\"  {k}: {v}\") for k,v in d.items()]" 2>/dev/null || echo "  (benchmark unavailable)"
    echo "Report: ${report_file}.json"
  fi
}

# === Live metrics stream ===
observe_live() {
  local interval="${1:-5}"
  angel_info "[observe] Live metrics every ${interval}s (Ctrl+C to stop)"
  
  while true; do
    clear 2>/dev/null || true
    echo "=== AngelKernel Live Metrics (refreshing every ${interval}s) ==="
    echo ""
    
    # System
    local sys
    sys=$(observe_system)
    echo "── System ──"
    echo "  CPU:  $(echo "$sys" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cpu_load','?'))")"
    echo "  Mem:  $(echo "$sys" | python3 -c "import json,sys; print(json.load(sys.stdin).get('memory_percent','?'))")%"
    echo "  Disk: $(echo "$sys" | python3 -c "import json,sys; print(json.load(sys.stdin).get('disk_percent','?'))")%"
    
    # Kernel
    local kernel
    kernel=$(observe_kernel)
    echo ""
    echo "── Kernel ──"
    echo "  RALPH:    $(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ralph_loops','?'))")"
    echo "  Memory:   $(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('episodic_memories','?'))")E $(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('semantic_concepts','?'))")S $(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('procedural_skills','?'))")P"
    echo "  Skills:   $(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('skills','?'))")"
    echo "  Errors:   $(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('errors','?'))")"
    echo "  Daemons:  $(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('daemons_running','?'))")/$(echo "$kernel" | python3 -c "import json,sys; print(json.load(sys.stdin).get('daemons_total','?'))")"
    echo ""
    echo "── Recent Metrics ──"
    tail -10 "$METRICS_FILE" 2>/dev/null | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        ts = d.get('ts', 0)
        name = d.get('name', '?')
        val = d.get('value', '?')
        print(f'  [{ts}] {name} = {val}')
    except: pass
" 2>/dev/null
    
    sleep "$interval"
  done
}

# === Export metrics for Prometheus/grafana ===
observe_export() {
  local format="${1:-prometheus}"
  
  case "$format" in
    prometheus)
      # Prometheus format
      echo "# HELP angel_kernel AngelKernel metrics"
      echo "# TYPE angel_kernel gauge"
      if [ -f "$METRICS_FILE" ]; then
        tail -100 "$METRICS_FILE" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
    except: continue
    name = d.get('name', 'unknown').replace('.', '_').replace(':', '_')
    val = d.get('value', 0)
    labels = d.get('labels', {})
    label_str = ','.join([f'{k}=\"{v}\"' for k, v in labels.items()])
    print(f'angel_{name}{{{label_str}}} {val}')
" 2>/dev/null
      fi
      ;;
    json)
      # Full JSON export
      echo "{"
      echo "  \"system\": $(observe_system),"
      echo "  \"kernel\": $(observe_kernel),"
      echo "  \"timestamp\": $(date +%s)"
      echo "}"
      ;;
  esac
}

# === Performance Benchmarking ===
observe_benchmark() {
  local metrics="{"
  
  # Memory Cortex metrics
  local l2_count l3_count l4_count
  l2_count=$(wc -l < "$ANGEL_HOME/memory/cortex/l2_episodic/log.ndjson" 2>/dev/null || echo 0)
  l3_count=$(wc -l < "$ANGEL_HOME/memory/cortex/l3_semantic/knowledge.jsonl" 2>/dev/null || echo 0)
  l4_count=$(wc -l < "$ANGEL_HOME/memory/cortex/l4_procedural/skills.jsonl" 2>/dev/null || echo 0)
  metrics+="\"l2_episodes\": $l2_count,"
  metrics+="\"l3_concepts\": $l3_count,"
  metrics+="\"l4_skills\": $l4_count,"
  
  # Evolution metrics
  local evos
  evos=$(python3 -c "import json; print(json.load(open('$ANGEL_HOME/store/evolution/evolution.json')).get('total_evolutions',0))" 2>/dev/null || echo 0)
  metrics+="\"total_evolutions\": $evos,"
  
  # Service health
  local services_up=0
  local services_total=0
  for pf in "$ANGEL_HOME/run"/*.pid; do
    [ -f "$pf" ] || continue
    services_total=$((services_total + 1))
    pid=$(cat "$pf" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && services_up=$((services_up + 1))
  done
  metrics+="\"services_up\": $services_up,"
  metrics+="\"services_total\": $services_total,"
  
  # Disk usage
  local disk_pct
  disk_pct=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
  metrics+="\"disk_percent\": ${disk_pct:-0},"
  
  # AngelKernel size
  local ak_size
  ak_size=$(du -sk "$ANGEL_HOME" 2>/dev/null | awk '{print $1}')
  metrics+="\"angelkernel_size_kb\": ${ak_size:-0}"
  
  metrics+="}"
  echo "$metrics"
}


case "${1:-}" in
  system)
    observe_system ;;
  kernel)
    observe_kernel ;;
  record)
    shift; observe_record "$1" "$2" "${3:-}" ;;
  graph)
    shift; observe_graph "$1" "${2:-50}" ;;
  report)
    shift; observe_report "$1" ;;
  live)
    shift; observe_live "$1" ;;
  export)
    shift; observe_export "$1" ;;
  trace)
    shift; angel_trace_show "$1" "$2" ;;
  trace-summary)
    angel_trace_summary ;;
  *)
    echo "Usage: angel-observe.sh {system|kernel|record|graph|report|live|export|trace|trace-summary} [args]"
    echo ""
    echo "  trace [lines] [filter]     — Show recent trace entries"
    echo "  trace-summary              — Show trace summary statistics"
    ;;
esac
