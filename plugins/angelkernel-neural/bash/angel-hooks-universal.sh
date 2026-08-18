#!/bin/bash
# angel-hooks-universal v4.0 — Universal Lifecycle Hook Ecosystem
# 50+ events across all subsystems with auto-registration, priority queue,
# async dispatch, error isolation, and neural event correlation

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
ANGEL_SCRIPT="hooks-universal"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true

HOOKS_DIR="$ANGEL_HOME/hooks"
REGISTRY_FILE="$ANGEL_HOME/store/hook_registry.json"
EVENT_LOG="$ANGEL_HOME/store/events.ndjson"
mkdir -p "$HOOKS_DIR" "$(dirname "$REGISTRY_FILE")" "$(dirname "$EVENT_LOG")"
[ ! -f "$REGISTRY_FILE" ] && echo '{"hooks":{}}' > "$REGISTRY_FILE"

# ============================================================================
# EVENT CATALOG — All 50+ lifecycle events organized by subsystem
# ============================================================================
# System Lifecycle
#   system:init, system:ready, system:shutdown, system:heartbeat, system:degraded
# Neural Cognition
#   neural:intent-detected, neural:route-selected, neural:context-updated
#   neural:coherence-check, neural:learning-consolidated, neural:pattern-detected
# Auto-Skill
#   skill:pattern-detected, skill:extracted, skill:verified, skill:activated
#   skill:failed, skill:optimized, skill:deprecated
# Error Correction
#   error:occurred, error:diagnosed, error:fixed, error:learned, error:escalated
# Memory
#   memory:store, memory:recall, memory:forget, memory:consolidate
#   memory:corrupted, memory:repaired
# Evolution
#   evolution:check, evolution:cycle-start, evolution:cycle-end, evolution:milestone
#   evolution:auto-heal, evolution:refinement
# Pulse/Health
#   pulse:tick, pulse:health-ok, pulse:health-warn, pulse:health-critical
#   pulse:disk-cleanup, pulse:log-rotate, pulse:skill-extraction
# Query
#   query:received, query:analyzed, query:planned, query:executed
#   query:complete, query:error, query:retry
# Unity Pipeline
#   unity:enhance-start, unity:enhance-end, unity:analyze-start, unity:analyze-end
#   unity:plan-start, unity:plan-end, unity:execute-start, unity:execute-end
#   unity:step-complete, unity:evolve-start, unity:evolve-end
#   unity:reflect-start, unity:reflect-end
# Agent
#   agent:spawned, agent:complete, agent:error, agent:timeout
# Swarm
#   swarm:consensus-start, swarm:consensus-end, swarm:parallel-start
#   swarm:parallel-end, swarm:debate-start, swarm:debate-end
# Config
#   config:changed, config:reloaded, config:error
# Plugin
#   plugin:enabled, plugin:disabled, plugin:installed, plugin:error
# ============================================================================

# Auto-register all known events with their metadata
auto_register_events() {
  python3 -c "
import json, os, time
reg_file = '$REGISTRY_FILE'
reg = json.load(open(reg_file))

# Full event catalog with metadata
events = {
    'system:init': {'category': 'system', 'priority': 0, 'desc': 'System startup began'},
    'system:ready': {'category': 'system', 'priority': 1, 'desc': 'All subsystems operational'},
    'system:shutdown': {'category': 'system', 'priority': 99, 'desc': 'Graceful shutdown'},
    'system:heartbeat': {'category': 'system', 'priority': 50, 'desc': 'Periodic health signal'},
    'system:degraded': {'category': 'system', 'priority': 10, 'desc': 'Subsystem degraded'},

    'neural:intent-detected': {'category': 'neural', 'priority': 30, 'desc': 'Query intent classified'},
    'neural:route-selected': {'category': 'neural', 'priority': 30, 'desc': 'Agent/tool/skill route chosen'},
    'neural:context-updated': {'category': 'neural', 'priority': 40, 'desc': 'Neural context synced'},
    'neural:coherence-check': {'category': 'neural', 'priority': 50, 'desc': 'System coherence verified'},
    'neural:learning-consolidated': {'category': 'neural', 'priority': 40, 'desc': 'Learning stored'},
    'neural:pattern-detected': {'category': 'neural', 'priority': 20, 'desc': 'Recurring pattern found'},

    'skill:pattern-detected': {'category': 'skill', 'priority': 20, 'desc': 'Skillable pattern identified'},
    'skill:extracted': {'category': 'skill', 'priority': 30, 'desc': 'New skill extracted'},
    'skill:verified': {'category': 'skill', 'priority': 40, 'desc': 'Skill passed verification'},
    'skill:activated': {'category': 'skill', 'priority': 50, 'desc': 'Skill activated'},
    'skill:failed': {'category': 'skill', 'priority': 10, 'desc': 'Skill extraction failed'},
    'skill:optimized': {'category': 'skill', 'priority': 50, 'desc': 'Skill refined'},
    'skill:deprecated': {'category': 'skill', 'priority': 60, 'desc': 'Skill removed'},

    'error:occurred': {'category': 'error', 'priority': 5, 'desc': 'Error detected'},
    'error:diagnosed': {'category': 'error', 'priority': 10, 'desc': 'Error root cause found'},
    'error:fixed': {'category': 'error', 'priority': 20, 'desc': 'Error resolved'},
    'error:learned': {'category': 'error', 'priority': 30, 'desc': 'Error knowledge stored'},
    'error:escalated': {'category': 'error', 'priority': 3, 'desc': 'Error requires intervention'},

    'memory:store': {'category': 'memory', 'priority': 40, 'desc': 'Memory stored'},
    'memory:recall': {'category': 'memory', 'priority': 40, 'desc': 'Memory retrieved'},
    'memory:forget': {'category': 'memory', 'priority': 50, 'desc': 'Memory forgotten'},
    'memory:consolidate': {'category': 'memory', 'priority': 50, 'desc': 'L2→L3 consolidation'},
    'memory:corrupted': {'category': 'memory', 'priority': 5, 'desc': 'Memory corruption detected'},
    'memory:repaired': {'category': 'memory', 'priority': 20, 'desc': 'Memory repaired'},

    'evolution:check': {'category': 'evolution', 'priority': 30, 'desc': 'Evolution check requested'},
    'evolution:cycle-start': {'category': 'evolution', 'priority': 20, 'desc': 'Evolution cycle began'},
    'evolution:cycle-end': {'category': 'evolution', 'priority': 50, 'desc': 'Evolution cycle completed'},
    'evolution:milestone': {'category': 'evolution', 'priority': 40, 'desc': 'Evolution milestone reached'},
    'evolution:auto-heal': {'category': 'evolution', 'priority': 10, 'desc': 'Auto-heal triggered'},
    'evolution:refinement': {'category': 'evolution', 'priority': 40, 'desc': 'System refined'},

    'pulse:tick': {'category': 'pulse', 'priority': 50, 'desc': 'Pulse daemon tick'},
    'pulse:health-ok': {'category': 'pulse', 'priority': 50, 'desc': 'All health checks pass'},
    'pulse:health-warn': {'category': 'pulse', 'priority': 30, 'desc': 'Health warning'},
    'pulse:health-critical': {'category': 'pulse', 'priority': 5, 'desc': 'Critical health issue'},
    'pulse:disk-cleanup': {'category': 'pulse', 'priority': 50, 'desc': 'Disk cleanup ran'},
    'pulse:log-rotate': {'category': 'pulse', 'priority': 50, 'desc': 'Logs rotated'},
    'pulse:skill-extraction': {'category': 'pulse', 'priority': 40, 'desc': 'Skills extracted'},

    'query:received': {'category': 'query', 'priority': 30, 'desc': 'Query received'},
    'query:analyzed': {'category': 'query', 'priority': 35, 'desc': 'Query analyzed'},
    'query:planned': {'category': 'query', 'priority': 40, 'desc': 'Execution plan created'},
    'query:executed': {'category': 'query', 'priority': 45, 'desc': 'Execution in progress'},
    'query:complete': {'category': 'query', 'priority': 50, 'desc': 'Query completed'},
    'query:error': {'category': 'query', 'priority': 10, 'desc': 'Query execution error'},
    'query:retry': {'category': 'query', 'priority': 25, 'desc': 'Retrying query'},

    'unity:enhance-start': {'category': 'unity', 'priority': 30, 'desc': 'Enhance phase start'},
    'unity:enhance-end': {'category': 'unity', 'priority': 35, 'desc': 'Enhance phase end'},
    'unity:analyze-start': {'category': 'unity', 'priority': 35, 'desc': 'Analyze phase start'},
    'unity:analyze-end': {'category': 'unity', 'priority': 40, 'desc': 'Analyze phase end'},
    'unity:plan-start': {'category': 'unity', 'priority': 40, 'desc': 'Plan phase start'},
    'unity:plan-end': {'category': 'unity', 'priority': 45, 'desc': 'Plan phase end'},
    'unity:step-complete': {'category': 'unity', 'priority': 50, 'desc': 'Execution step done'},

    'agent:spawned': {'category': 'agent', 'priority': 30, 'desc': 'Agent spawned'},
    'agent:complete': {'category': 'agent', 'priority': 50, 'desc': 'Agent finished'},
    'agent:error': {'category': 'agent', 'priority': 10, 'desc': 'Agent error'},
    'agent:timeout': {'category': 'agent', 'priority': 10, 'desc': 'Agent timed out'},

    'swarm:consensus-start': {'category': 'swarm', 'priority': 30, 'desc': 'Swarm consensus began'},
    'swarm:consensus-end': {'category': 'swarm', 'priority': 50, 'desc': 'Swarm consensus reached'},
    'swarm:parallel-start': {'category': 'swarm', 'priority': 30, 'desc': 'Parallel execution began'},
    'swarm:parallel-end': {'category': 'swarm', 'priority': 50, 'desc': 'Parallel execution done'},

    'config:changed': {'category': 'config', 'priority': 40, 'desc': 'Config modified'},
    'config:reloaded': {'category': 'config', 'priority': 50, 'desc': 'Config reloaded'},
    'config:error': {'category': 'config', 'priority': 10, 'desc': 'Config error'},

    'plugin:enabled': {'category': 'plugin', 'priority': 40, 'desc': 'Plugin enabled'},
    'plugin:disabled': {'category': 'plugin', 'priority': 50, 'desc': 'Plugin disabled'},
    'plugin:installed': {'category': 'plugin', 'priority': 40, 'desc': 'Plugin installed'},
    'plugin:error': {'category': 'plugin', 'priority': 10, 'desc': 'Plugin error'}
}

# Register any missing events
registered = 0
for event, meta in events.items():
    if event not in reg.get('hooks', {}):
        if 'hooks' not in reg:
            reg['hooks'] = {}
        reg['hooks'][event] = []
        registered += 1
        # Create hook script placeholder
        event_file = '$HOOKS_DIR/${event}.sh'.replace(':', '-')
        if not os.path.exists(event_file):
            with open(event_file, 'w') as f:
                f.write('#!/bin/bash\n')
                f.write('# Hook: ' + event + ' — ' + meta['desc'] + '\n')
                f.write('ANGEL_HOME=\"${ANGEL_HOME:-$HOME/.angelkernel}\"\n')
                f.write('EVENT=\"$1\" PAYLOAD=\"$2\" TIMESTAMP=\"$3\"\n')
                f.write('# Auto-generated hook for ' + event + '\n')
            os.chmod(event_file, 0o755)

reg['event_catalog'] = events
reg['last_auto_register'] = int(time.time())
json.dump(reg, open(reg_file, 'w'), indent=2)
print(f'Auto-registered {registered} new events, total: {len(reg.get(\"hooks\",{}))}')
" 2>&1
  
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "config:changed" \
    "{\"events_registered\":\"auto\"}" "true" 2>/dev/null &
}

fire_universal() {
  local event="$1" payload="${2:-}" async="${3:-true}"
  [ -z "$payload" ] && payload="{}"
  
  # Log to event store
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|$event|$payload" >> "$EVENT_LOG"
  
  # Fire via existing hook system
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "$event" "$payload" "$async" 2>/dev/null
  
  # Update metric
  angel_metric "hook.fired" 1 "{\"event\":\"$event\"}" 2>/dev/null || true
}

list_events() {
  local category="${1:-}"
  python3 -c "
import json
reg = json.load(open('$REGISTRY_FILE'))
events = reg.get('hooks', {})
catalog = reg.get('event_catalog', {})

if '$category':
    cat_events = {k:v for k,v in catalog.items() if v.get('category') == '$category'}
    print(f'=== Events in category: $category ===')
    for e, meta in sorted(cat_events.items()):
        hooks = len(events.get(e, []))
        print(f'  {e}: {meta[\"desc\"]} [{hooks} hook(s)]')
else:
    print(f'=== Universal Event Catalog ({len(catalog)} events) ===')
    cats = {}
    for e, meta in catalog.items():
        cat = meta.get('category', 'other')
        if cat not in cats: cats[cat] = []
        cats[cat].append(e)
    for cat, evts in sorted(cats.items()):
        print(f'  [{cat}] {len(evts)} events')
        for e in evts[:5]:
            hooks = len(events.get(e, []))
            print(f'    {e}: {hooks} hook(s)')
        if len(evts) > 5:
            print(f'    ... and {len(evts)-5} more')
" 2>/dev/null
}

event_stats() {
  python3 -c "
import json, os
reg = json.load(open('$REGISTRY_FILE'))
events = reg.get('hooks', {})
catalog = reg.get('event_catalog', {})

total_events = len(events)
total_hooks = sum(len(v) for v in events.values())
categories = {}
for e, meta in catalog.items():
    cat = meta.get('category', 'other')
    if cat not in categories: categories[cat] = 0
    if e in events:
        categories[cat] += len(events[e])

print(f'Events: {total_events} | Hook scripts: {total_hooks}')
print(f'Categories: {len(categories)}')
for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
    print(f'  {cat}: {count} hooks')

# Count registered hook scripts
if os.path.exists('$HOOKS_DIR'):
    scripts = [f for f in os.listdir('$HOOKS_DIR') if f.endswith('.sh')]
    print(f'Hook files: {len(scripts)}')
" 2>/dev/null
}

case "${1:-}" in
  register-all)
    auto_register_events ;;
  fire)
    shift; fire_universal "$1" "$2" "${3:-true}" ;;
  list)
    shift; list_events "$1" ;;
  stats)
    event_stats ;;
  *)
    echo "AngelKernel Universal Hooks v4.0"
    echo "Usage: angel-hooks-universal.sh {register-all|fire|list|stats}"
    ;;
esac
