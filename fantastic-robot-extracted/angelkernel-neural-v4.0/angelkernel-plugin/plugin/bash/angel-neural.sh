#!/bin/bash
# angel-neural v4.0 — Autonomous Neural Coherence Engine
# Provides: neural cognition, context coherence, adaptive routing,
# human-level dynamic comprehension, auto-skill detection, error correction
#
# This is the BRAIN of AngelKernel — everything routes through here.
#
# Architecture:
#   Neural Cortex    → Pattern matching, intent classification
#   Context Coherence → Cross-session context, memory synthesis
#   Adaptive Router  → Optimal agent/tool/skill routing
#   Auto-Skill Engine → Pattern detection → skill extraction
#   Error Correction  → Detect → Diagnose → Fix → Learn
#   Coherence Monitor → Self-check, calibration, optimization

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="neural"
angel_console_init 2>/dev/null || true

NEURAL_DIR="$ANGEL_HOME/memory/neural"
COHERENCE_FILE="$NEURAL_DIR/coherence.json"
PATTERN_FILE="$NEURAL_DIR/patterns.ndjson"
ROUTE_CACHE="$NEURAL_DIR/routes.json"
CONTEXT_FILE="$NEURAL_DIR/context.json"
ERROR_PATTERNS="$NEURAL_DIR/error_patterns.json"
mkdir -p "$NEURAL_DIR"

init_neural_db() {
  if [ ! -f "$COHERENCE_FILE" ]; then
    echo '{"created":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","checks":[],"health":"initialized","coherence_score":1.0}' > "$COHERENCE_FILE"
  fi
  if [ ! -f "$ROUTE_CACHE" ]; then
    echo '{"created":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' > "$ROUTE_CACHE"
  fi
  if [ ! -f "$CONTEXT_FILE" ]; then
    echo '{"_meta":{"created":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}}' > "$CONTEXT_FILE"
  fi
  if [ ! -f "$ERROR_PATTERNS" ]; then
    echo '{"created":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","patterns":[],"fixes":[],"learnings":[]}' > "$ERROR_PATTERNS"
  fi
  if [ ! -f "$PATTERN_FILE" ]; then
    touch "$PATTERN_FILE"
  fi
}
init_neural_db

# ============================================================================
# NEURAL COHERENCE — Cross-session context synthesis
# Maintains a dynamic coherence model of all active contexts
# ============================================================================

neural_update_context() {
  local domain="$1" content="$2" weight="${3:-0.5}"
  local ctx
  ctx=$(python3 -c "
import json, time
CORTEX_DIR = '$CORTEX_DIR'
CONTEXT_FILE = '$CONTEXT_FILE'
domain_arg = '$domain'
content_arg = '''$content'''
weight_arg = $weight
ctx = json.load(open(CONTEXT_FILE))
now = time.time()
domain_key = domain_arg.lower().replace(' ', '_')
entry = {
    'domain': domain_arg,
    'content': content_arg[:200],
    'weight': weight_arg,
    'ts': now,
    'decay': max(0.1, weight_arg * 0.95)
}
ctx[domain_key] = entry
ctx = {k:v for k,v in ctx.items() if isinstance(v, dict) and (now - v.get('ts', 0) < 3600 or v.get('weight', 0) >= 0.3)}
json.dump(ctx, open(CONTEXT_FILE, 'w'))
print(f'Context updated: {domain_key} (weight={weight_arg}, domains={len(ctx)})')
")
  angel_print "memory" "NEURAL CONTEXT" "$ctx"
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "neural:context-updated" \
    "{\"domain\":\"$domain\",\"weight\":$weight}" "true" 2>/dev/null &
}

neural_get_context() {
  local domain="${1:-}"
  python3 -c "
import json
ctx = json.load(open('$CONTEXT_FILE'))
if '$domain':
    domain_key = '$domain'.lower().replace(' ', '_')
    if domain_key in ctx:
        print(json.dumps(ctx[domain_key], indent=2))
    else:
        print('No context for: $domain')
else:
    print(f'Active contexts: {len(ctx)}')
    for k,v in sorted(ctx.items(), key=lambda x: x[1].get('weight',0), reverse=True)[:10]:
        import time
        age = int(time.time() - v.get('ts', 0))
        print(f'  {k}: weight={v.get(\"weight\",0)} age={age}s content={v.get(\"content\",\"\")[:60]}')
" 2>/dev/null
}

# ============================================================================
# NEURAL INTENT CLASSIFICATION — Understand what the user wants
# Uses pattern matching and historical routing data
# ============================================================================

neural_classify_intent() {
  local query="$1"
  local result
  result=$(python3 -c "
import json, re, os

query = '''$query'''.lower()

# Load route cache for past routing decisions
route_cache = {}
rc_file = '$ROUTE_CACHE'
if os.path.exists(rc_file):
    try:
        route_cache = json.load(open(rc_file))
    except: pass

# Intent categories with neural pattern matching
intents = {
    'code': {
        'patterns': ['write code', 'create function', 'implement', 'program', 'develop', 'build app',
                     'fix bug', 'debug', 'refactor', 'coding', 'script', 'programming', 'api'],
        'confidence': 0.0, 'agents': ['@coder'], 'skills': []
    },
    'research': {
        'patterns': ['find', 'search', 'research', 'look up', 'what is', 'how does', 'explain',
                     'tell me about', 'information', 'documentation', 'docs', 'learn about'],
        'confidence': 0.0, 'agents': ['@researcher'], 'skills': []
    },
    'system': {
        'patterns': ['health', 'status', 'diagnostic', 'check system', 'doctor', 'pulse',
                     'disk', 'cleanup', 'maintenance', 'log'],
        'confidence': 0.0, 'agents': [], 'skills': ['angel-doctor']
    },
    'memory': {
        'patterns': ['remember', 'recall', 'memory', 'store', 'forget', 'consolidate',
                     'what did i', 'previous', 'before', 'cortex'],
        'confidence': 0.0, 'agents': [], 'skills': ['angel-cortex']
    },
    'evolution': {
        'patterns': ['evolve', 'improve', 'optimize', 'upgrade', 'enhance', 'self-improve',
                     'recursive', 'growth', 'skill extraction'],
        'confidence': 0.0, 'agents': [], 'skills': ['angel-self-improve', 'angel-evolve']
    },
    'reasoning': {
        'patterns': ['think', 'analyze', 'plan', 'design', 'architect', 'strategy',
                     'decide', 'evaluate', 'compare', 'consider'],
        'confidence': 0.0, 'agents': ['@thinker', '@architect'], 'skills': []
    },
    'creative': {
        'patterns': ['create', 'generate', 'design', 'make', 'build', 'compose',
                     'write', 'story', 'poem', 'art', 'image'],
        'confidence': 0.0, 'agents': ['@thinker'], 'skills': ['imagegen']
    },
    'data': {
        'patterns': ['data', 'analyze', 'process', 'transform', 'convert', 'parse',
                     'extract', 'load', 'etl', 'pipeline', 'statistics', 'metrics'],
        'confidence': 0.0, 'agents': ['@researcher'], 'skills': []
    },
    'learn': {
        'patterns': ['learn', 'teach', 'tutorial', 'guide', 'how to', 'training',
                     'practice', 'understand concept'],
        'confidence': 0.0, 'agents': ['@researcher'], 'skills': []
    }
}

# Score each intent by neural pattern matching (word-boundary aware)
import re as re_mod
for intent_name, intent_data in intents.items():
    matched = 0
    for pattern in intent_data['patterns']:
        word_pat = r'\b' + re_mod.escape(pattern) + r'\b'
        if re_mod.search(word_pat, query):
            matched += 1
    if matched > 0:
        intent_data['confidence'] = min(1.0, matched / max(1, len(intent_data['patterns']) * 0.3))

# Find best intent
best_intent = max(intents.items(), key=lambda x: x[1]['confidence'])
best_name, best_data = best_intent

# If confidence is low, default to 'reasoning'
if best_data['confidence'] < 0.15:
    best_name = 'reasoning'
    best_data = intents['reasoning']
    best_data['confidence'] = 0.4

# Check route cache for historical preference
if best_name in route_cache:
    hist = route_cache[best_name]
    hist_confidence = min(1.0, hist.get('success_rate', 0.5) * 0.3)
    best_data['confidence'] = min(1.0, best_data['confidence'] + hist_confidence)

result = {
    'intent': best_name,
    'confidence': round(best_data['confidence'], 2),
    'agents': best_data['agents'],
    'skills': best_data['skills']
}
print(json.dumps(result))
" 2>/dev/null)
  echo "$result"
}

# ============================================================================
# NEURAL ADAPTIVE ROUTER — Route queries to optimal agents/tools/skills
# Uses intent + context + historical success rates
# ============================================================================

neural_route() {
  local query="$1" intent_json="$2"
  local intent agents skills
  
  intent=$(echo "$intent_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('intent','reasoning'))" 2>/dev/null || echo "reasoning")
  agents=$(echo "$intent_json" | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin).get('agents',[])))" 2>/dev/null || echo "")
  skills=$(echo "$intent_json" | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin).get('skills',[])))" 2>/dev/null || echo "")
  
  angel_print "decision" "NEURAL ROUTE" "intent=$intent agents='$agents' skills='$skills'"
  
  # Update route cache with this routing decision
  python3 -c "
import json, os
rc_file = '$ROUTE_CACHE'
rc = {}
if os.path.exists(rc_file):
    try: rc = json.load(open(rc_file))
    except: pass
intent = '$intent'
if intent not in rc:
    rc[intent] = {'count': 0, 'success_rate': 0.5, 'agents': '$agents', 'skills': '$skills'}
rc[intent]['count'] = rc[intent].get('count', 0) + 1
rc[intent]['last_route'] = $(date +%s)
json.dump(rc, open(rc_file, 'w'))
" 2>/dev/null
  
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "neural:route-selected" \
    "{\"intent\":\"$intent\",\"agents\":\"$agents\",\"skills\":\"$skills\"}" "true" 2>/dev/null &
  
  echo "$intent|$agents|$skills"
}

# ============================================================================
# NEURAL COHERENCE CHECK — Self-assessment and calibration
# Checks if the neural system is operating coherently
# ============================================================================

neural_coherence_check() {
  angel_print "decision" "NEURAL COHERENCE" "checking system coherence..."
  
  python3 -c "
import json, os, time

report = {
    'ts': time.time(),
    'iso': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'checks': []
}

# 1. Context coherence — do we have active context?
ctx_file = '$CONTEXT_FILE'
if os.path.exists(ctx_file):
    try:
        ctx = json.load(open(ctx_file))
        report['checks'].append({
            'name': 'context_coherence',
            'status': 'ok' if len(ctx) > 0 else 'warn',
            'detail': f'{len(ctx)} active contexts',
            'contexts': list(ctx.keys())[:5]
        })
    except:
        report['checks'].append({'name': 'context_coherence', 'status': 'warn', 'detail': 'corrupt'})
else:
    report['checks'].append({'name': 'context_coherence', 'status': 'warn', 'detail': 'missing'})

# 2. Route cache health
rc_file = '$ROUTE_CACHE'
if os.path.exists(rc_file):
    try:
        rc = json.load(open(rc_file))
        report['checks'].append({
            'name': 'route_cache',
            'status': 'ok',
            'detail': f'{len(rc)} routes cached',
            'routes': list(rc.keys())
        })
    except:
        report['checks'].append({'name': 'route_cache', 'status': 'warn', 'detail': 'corrupt'})

# 3. Pattern detection health
pat_file = '$PATTERN_FILE'
if os.path.exists(pat_file):
    try:
        with open(pat_file) as f:
            pats = [l for l in f if l.strip()]
        report['checks'].append({
            'name': 'pattern_detection',
            'status': 'ok',
            'detail': f'{len(pats)} patterns tracked'
        })
    except:
        report['checks'].append({'name': 'pattern_detection', 'status': 'warn', 'detail': 'unreadable'})

# 4. Error pattern health
err_file = '$ERROR_PATTERNS'
if os.path.exists(err_file):
    try:
        err = json.load(open(err_file))
        err_count = len(err.get('patterns', []))
        report['checks'].append({
            'name': 'error_correction',
            'status': 'ok',
            'detail': f'{err_count} error patterns tracked'
        })
    except:
        report['checks'].append({'name': 'error_correction', 'status': 'warn', 'detail': 'corrupt'})

# Overall health
ok_count = sum(1 for c in report['checks'] if c['status'] == 'ok')
total = len(report['checks'])
report['health'] = 'optimal' if ok_count == total else 'degraded' if ok_count > 0 else 'critical'
report['coherence_score'] = round(ok_count / max(1, total), 2)

print(json.dumps(report, indent=2))
" 2>&1
  
  angel_print "decision" "NEURAL COHERENCE" "check complete"
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "neural:coherence-check" "{}" "true" 2>/dev/null &
}

# ============================================================================
# NEURAL PATTERN DETECTION — Find recurring patterns for auto-skilling
# ============================================================================

neural_detect_patterns() {
  local source="$1" content="$2"
  local pattern_id="PAT-$(date +%s)"
  
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|$source|$pattern_id|$content" >> "$PATTERN_FILE"
  
  # Check if pattern repeats (same source, similar content)
  local count
  count=$(grep -c "|$source|" "$PATTERN_FILE" 2>/dev/null || echo 0)
  
  if [ "$count" -ge 3 ]; then
    angel_print "evolve" "PATTERN DETECTED" "source=$source occurrences=$count"
    bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "neural:pattern-detected" \
      "{\"source\":\"$source\",\"occurrences\":$count,\"content\":\"$content\"}" "true" 2>/dev/null &
    
    # Auto-trigger skill extraction
    if [ "$count" -ge 3 ] && [ "${ANGEL_EVOLUTION_SKILL_EXTRACTION:-true}" = "true" ]; then
      bash "$ANGEL_HOME/bin/angel-auto-skill.sh" --extract "$source" "$content" 2>/dev/null &
    fi
  fi
  
  echo "$count"
}

# ============================================================================
# NEURAL ERROR CORRECTION — Detect → Diagnose → Fix → Learn
# ============================================================================

neural_handle_error() {
  local error_msg="$1" context="$2"
  
  angel_print "error" "NEURAL ERROR" "msg='${error_msg:0:80}' context='${context:0:40}'"
  
  # Store error pattern
  python3 -c "
import json, os, time
err_file = '$ERROR_PATTERNS'
err = {'patterns': [], 'fixes': [], 'learnings': []}
if os.path.exists(err_file):
    try: err = json.load(open(err_file))
    except: pass
# Normalize error message for pattern matching
import re
error_key = re.sub(r'[0-9]+', 'N', '$error_msg'.lower())[:100]
# Check if we've seen this before
existing = [p for p in err['patterns'] if p.get('key') == error_key]
if existing:
    existing[0]['count'] = existing[0].get('count', 0) + 1
    existing[0]['last_seen'] = time.time()
else:
    err['patterns'].append({
        'key': error_key,
        'original': '$error_msg'[:200],
        'count': 1,
        'first_seen': time.time(),
        'last_seen': time.time(),
        'context': '$context'[:100]
    })
json.dump(err, open(err_file, 'w'))
print(f'Error pattern logged: {error_key} (total={len(err[\"patterns\"])})')
" 2>/dev/null
  
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "error:occurred" \
    "{\"error\":\"$error_msg\",\"context\":\"$context\"}" "true" 2>/dev/null &
  
  # Auto-heal: if error pattern repeats 3+ times, auto-fire evolution
  local count
  count=$(python3 -c "
import json, os
err_file = '$ERROR_PATTERNS'
if os.path.exists(err_file):
    err = json.load(open(err_file))
    import re
    error_key = re.sub(r'[0-9]+', 'N', '$error_msg'.lower())[:100]
    for p in err.get('patterns', []):
        if p.get('key') == error_key:
            print(p.get('count', 1))
            break
    else:
        print(1)
else:
    print(1)
" 2>/dev/null || echo 1)
  
  if [ "$count" -ge 3 ]; then
    angel_print "evolve" "AUTO-HEAL" "error repeated ${count}x — triggering evolution"
    bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "error:diagnosed" \
      "{\"error\":\"$error_msg\",\"count\":$count}" "true" 2>/dev/null &
    bash "$ANGEL_HOME/bin/angel-self-improve.sh" --evolve "Auto-heal: $error_msg" 2>/dev/null &
  fi
}

# ============================================================================
# NEURAL SYNTHESIS — Bring everything together for a query
# Full neural pipeline: classify → route → execute → learn
# ============================================================================

neural_synthesize() {
  local query="$1"
  
  angel_print "decision" "NEURAL SYNTHESIS" "processing: ${query:0:60}..."
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "neural:intent-detected" "{\"query\":\"$query\"}" "true" 2>/dev/null &
  
  # Step 1: Classify intent
  local intent_json
  intent_json=$(neural_classify_intent "$query")
  local intent
  intent=$(echo "$intent_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('intent','reasoning'))" 2>/dev/null || echo "reasoning")
  
  # Step 2: Update context
  neural_update_context "$intent" "$query" 0.8
  
  # Step 3: Route
  local route_result
  route_result=$(neural_route "$query" "$intent_json")
  
  # Step 4: Detect patterns
  neural_detect_patterns "query" "$intent" > /dev/null 2>&1
  
  # Step 5: Return routing info
  echo "$intent_json"
  
  angel_print "ok" "NEURAL SYNTHESIS" "routed as: $intent"
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "neural:learning-consolidated" \
    "{\"intent\":\"$intent\"}" "true" 2>/dev/null &
}

# ============================================================================
# DISPATCH
# ============================================================================

case "${1:-}" in
  synthesize)
    shift; neural_synthesize "$1" ;;
  classify)
    shift; neural_classify_intent "$1" ;;
  route)
    shift; neural_route "$1" "$2" ;;
  context-update)
    shift; neural_update_context "$1" "$2" "${3:-0.5}" ;;
  context-get)
    shift; neural_get_context "$1" ;;
  coherence)
    neural_coherence_check ;;
  pattern)
    shift; neural_detect_patterns "$1" "$2" ;;
  error)
    shift; neural_handle_error "$1" "$2" ;;
  init)
    init_neural_db; neural_coherence_check ;;
  *)
    echo "AngelKernel Neural Engine v4.0"
    echo "Usage: angel-neural.sh {synthesize|classify|route|context-update|context-get|coherence|pattern|error|init} [args]"
    ;;
esac
