#!/bin/bash
# ==============================================================================
# angel-unity — AngelKernel Unified Neural Execution Engine v4.0
# SINGLE autonomous path for ALL queries. NEURAL cognition runs first as P0,
# then merges SuperLoop + Intensive + all AngelKernel subsystems into ONE
# adaptive workflow that dynamically scales complexity depth based on context.
#
# Architecture:
#   Phase 0: NEURAL    — Neural synthesise: intent classify + route + context coherence
#   Phase 1: ENHANCE   — Memory recall + cross-chain + context + subagent mentions
#   Phase 2: ANALYZE   — Intent + complexity + subsystem requirements
#   Phase 3: PLAN      — Dynamic planning with subagent routing + todo creation
#   Phase 4: EXECUTE   — Multi-modal execution (subagents/MCP/tools/hooks)
#   Phase 5: EVOLVE    — Verification + auto-skill extraction + evolution DB
#   Phase 6: REFLECT   — Recursive workspace analysis + auto-loop
#
# Features:
#   - Neural cognition engine (v4.0) as automatic P0 for every query
#   - Zero API keys required (Pollinations tier1 primary)
#   - Auto-skill extraction (3+ pattern repeats → L4 procedural skill)
#   - Universal hook ecosystem (60+ events, 13 categories)
#   - Error-correction loop: Detect → Diagnose → Fix → Learn
#   - Full mycelium cross-pollination (folded into neural)
#   - Auto-todo creation with @subagent routing
#   - Recursive post-task analysis with auto-loop on critical findings
#   - Context enhancement via memory recall + cross-chain discovery
#   - Full permissions mode — autonomous operation
# ==============================================================================

ANGEL_SCRIPT="unity"
ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true

BIN_DIR="$ANGEL_HOME/bin"
DEPTH="${ANGEL_DEPTH:-0}"
MAX_DEPTH="${ANGEL_MAX_DEPTH:-5}"
SESSION_ID="UNITY-$(date +%s)-$$"
WORK_DIR="$ANGEL_HOME/context/$SESSION_ID"
mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR" 2>/dev/null' EXIT

CONTEXT_FILE="$WORK_DIR/context.json"
ENHANCED_QUERY_FILE="$WORK_DIR/enhanced_query.txt"
PLAN_FILE="$WORK_DIR/plan.json"
RESULTS_FILE="$WORK_DIR/results.json"
TODOS_FILE="$WORK_DIR/todos.json"
REFLECTION_FILE="$WORK_DIR/reflection.json"
NEURAL_RESULT_FILE="$WORK_DIR/neural_result.json"

# ============================================================================
# PHASE 0: NEURAL — Neural Cognition Pre-Phase
# Runs angel-neural.sh synthesize BEFORE any other phase.
# Classifies intent, routes to optimal agents, updates context coherence.
# If NEURAL_FIRST env var is false, this phase is skipped.
# ============================================================================

unity_neural() {
    local query="$*"
    local start_time
    start_time=$(date +%s)

    if [ "${ANGEL_NEURAL_ENABLED:-true}" != "true" ] || [ "${ANGEL_NEURAL_FIRST:-true}" != "true" ]; then
        angel_info "  🧠 Neural P0: skipped (ANGEL_NEURAL_FIRST=${ANGEL_NEURAL_FIRST:-true})"
        echo "$query"
        return
    fi

    angel_info ""
    angel_info "╔══════════════════════════════════════════════════════════════════╗"
    angel_info "║  UNITY Phase 0: NEURAL — Cognition, Intent & Route             ║"
    angel_info "╚══════════════════════════════════════════════════════════════════╝"

    if [ -f "$BIN_DIR/angel-neural.sh" ]; then
        # Step 0a: Neural synthesise — classify intent + route + update context
        angel_print "neural" "SYNTHESIZE" "classifying intent for: ${query:0:60}..."
        local neural_result
        neural_result=$(bash "$BIN_DIR/angel-neural.sh" synthesize "$query" 2>/dev/null)
        local neural_exit=$?

        if [ $neural_exit -eq 0 ] && [ -n "$neural_result" ]; then
            local intent confidence
            intent=$(echo "$neural_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('intent','reasoning'))" 2>/dev/null || echo "reasoning")
            confidence=$(echo "$neural_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('confidence',0.5))" 2>/dev/null || echo "0.5")
            angel_info "  🧠 Intent: $intent (confidence=$confidence)"
            echo "$neural_result" > "$NEURAL_RESULT_FILE"

            # Step 0b: Register universal hooks if not yet done
            if [ "${ANGEL_UNIVERSAL_HOOKS_ENABLED:-true}" = "true" ] && [ ! -f "$ANGEL_HOME/store/hook_registry.json" ]; then
                bash "$BIN_DIR/angel-hooks-universal.sh" register-all 2>/dev/null &
            fi

            # Step 0c: Fire neural hooks
            if [ -f "$BIN_DIR/angel-hooks.sh" ]; then
                bash "$BIN_DIR/angel-hooks.sh" fire "neural:intent-detected" \
                    "{\"intent\":\"$intent\",\"query\":\"${query:0:100}\"}" "true" 2>/dev/null &
            fi
        else
            angel_warn "  🧠 Neural synthesise unavailable — continuing without neural context"
        fi
    else
        angel_warn "  🧠 angel-neural.sh not found — neural P0 unavailable"
    fi

    local elapsed=$(( $(date +%s) - start_time ))
    angel_info "  🧠 Neural phase: ${elapsed}s"
    echo "$query"
}

# ============================================================================
# PHASE 1: ENHANCE
# Enhance user query with memory context, cross-chain discovery,
# and optimal subagent routing suggestions
# ============================================================================

unity_enhance() {
    local query="$*"
    local start_time
    start_time=$(date +%s)
    
    angel_info ""
    angel_info "╔══════════════════════════════════════════════════════════════════╗"
    angel_info "║  UNITY Phase 0: ENHANCE — Context & Chain Discovery            ║"
    angel_info "╚══════════════════════════════════════════════════════════════════╝"
    
    # --- Step 0a: Cortex Memory Recall ---
    local memory_context=""
    if [ -f "$BIN_DIR/angel-cortex.sh" ] && [ "${ANGEL_CORTEX_ENABLED:-true}" = "true" ]; then
        angel_print "memory" "RECALL" "for: ${query:0:60}..."
        memory_context=$(bash "$BIN_DIR/angel-cortex.sh" recall "$query" 5 2>/dev/null)
        local mem_count
        mem_count=$(echo "$memory_context" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()) if sys.stdin.read() else {}; print(len(d.get('results',d.get('memories',[]))))" 2>/dev/null || echo "0")
        angel_info "  📖 Memory: $mem_count relevant entries recalled"
    fi
    
    # --- Step 0b: Cross-Chain Discovery ---
    local chain_discovery=""
    if [ -f "$BIN_DIR/angel-chain.sh" ]; then
        angel_print "call" "CHAIN DISCOVER" "for: ${query:0:60}..."
        chain_discovery=$(bash "$BIN_DIR/angel-chain.sh" discover "$query" 2>/dev/null)
        local chain_steps
        chain_steps=$(echo "$chain_discovery" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('steps',0))" 2>/dev/null || echo "0")
        angel_info "  🔗 Chain: $chain_steps steps discovered"
    fi
    
    # --- Step 0c: Optimal Subagent Detection ---
    local optimal_mentions=""
    optimal_mentions=$(python3 -c "
import sys
query = '''$query'''.lower()

# Map task patterns to optimal @mentions
patterns = {
    '@thinker': ['why', 'reason', 'complex', 'analyze', 'deep', 'philosophy', 'theory',
                 'strategy', 'plan', 'architecture', 'design', 'system'],
    '@coder': ['code', 'program', 'script', 'function', 'class', 'implement', 'build',
               'api', 'debug', 'fix', 'repair', 'test', 'refactor'],
    '@researcher': ['search', 'find', 'research', 'what is', 'learn', 'study',
                    'investigate', 'explore', 'discover'],
    '@critic': ['review', 'verify', 'validate', 'check', 'audit', 'inspect',
                'quality', 'security', 'safety'],
    '@artist': ['image', 'design', 'visual', 'art', 'logo', 'icon', 'illustration',
                'draw', 'picture', 'photo', 'graphic'],
    '@speaker': ['audio', 'speech', 'voice', 'say', 'narrate', 'pronounce', 'tts',
                 'listen', 'sound'],
    '@analyst': ['data', 'analyze', 'statistics', 'chart', 'graph', 'metrics',
                 'report', 'dashboard', 'trend'],
    '@writer': ['write', 'content', 'article', 'blog', 'email', 'document',
                'story', 'narrative', 'copy'],
}

matched = []
for mention, keywords in patterns.items():
    for kw in keywords:
        if kw in query:
            matched.append(mention)
            break

result = ', '.join(matched) if matched else '@general'
print(result)
" 2>/dev/null)
    angel_info "  🎯 Optimal subagents: $optimal_mentions"
    
    # --- Step 0d: Auto-Todo Creation (when multi-step detected) ---
    local auto_todos=""
    auto_todos=$(python3 -c "
import sys, json

query = '''$query'''

# Detect if this is a multi-step task by looking for:
# - numbered lists, bullet points
# - conjunctions (then, and, also, plus)
# - sequential indicators (first, then, finally)

lines = query.split('\n')
if len(lines) > 1:
    # Already a list — create todos from lines
    todos = []
    for i, line in enumerate(lines):
        line = line.strip()
        if line and not line.startswith('#'):
            todos.append({
                'id': i+1,
                'task': line,
                'status': 'pending',
                'auto_created': True
            })
    print(json.dumps({'todos': todos, 'count': len(todos)}))
    sys.exit(0)

# Check for sequential language
seq_words = ['then', 'and then', 'first', 'second', 'finally', 'next', 'after', 'also']
seq_count = sum(1 for w in seq_words if w in query.lower())

if seq_count >= 2 or len(query.split(',')) >= 4:
    # Split into logical steps
    parts = query.replace(' and then ', '\n').replace(' then ', '\n').replace(' first ', '\n').replace(' finally ', '\n')
    parts = [p.strip() for p in parts.split('\n') if p.strip()]
    todos = [{'id': i+1, 'task': parts[i], 'status': 'pending', 'auto_created': True} for i in range(len(parts))]
    print(json.dumps({'todos': todos, 'count': len(todos)}))
else:
    print(json.dumps({'todos': [], 'count': 0}))
" 2>/dev/null)
    
    local todo_count
    todo_count=$(echo "$auto_todos" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('count',0))" 2>/dev/null || echo "0")
    
    if [ "$todo_count" -gt 0 ]; then
        angel_info "  📋 Auto-created $todo_count todos from query"
        echo "$auto_todos" > "$TODOS_FILE"
    fi
    
    # --- Step 0e: Autonomous Adaptation ---
    if [ -f "$BIN_DIR/angel-adapt.sh" ] && [ "${ANGEL_AUTO_MODE:-true}" = "true" ] && [ "$DEPTH" -eq 0 ]; then
        angel_print "call" "ADAPT" "discovering capabilities for task..."
        bash "$BIN_DIR/angel-adapt.sh" auto "$query" 2>/dev/null &
    fi
    
    # --- Step 0f: MCP Connection Check ---
    local mcp_ready=false
    if [ -f "$BIN_DIR/angel-mcp-multiplexer.py" ]; then
        mcp_ready=true
        angel_info "  ⚡ MCP multiplexer available"
    fi
    
    # --- Step 0g: Build Enhanced Context ---
    python3 -c "
import json, sys

query = '''$query'''
memory = '''$memory_context'''
chain = '''$chain_discovery'''
mentions = '''$optimal_mentions'''

context = {
    'session_id': '$SESSION_ID',
    'depth': $DEPTH,
    'original_query': query,
    'enhanced_mentions': mentions.split(', ') if mentions else ['@general'],
    'memory_recall_count': '''$memory_context'''.count('\"id\"') if '''$memory_context''' else 0,
    'chain_steps': 0,
    'has_mcp': $mcp_ready,
    'todo_count': $todo_count,
    'timestamp': $(date +%s)
}

# Extract chain info
try:
    cd = json.loads('''$chain''')
    context['chain_domains'] = cd.get('intents', [])
    context['chain_steps'] = cd.get('steps', 0)
    context['chain_tools'] = [s.get('tool','') for s in cd.get('chain', [])]
except:
    context['chain_domains'] = []
    context['chain_tools'] = []

# Build enhanced query with context
enhanced_parts = [query]
if mentions:
    enhanced_parts.append(f'[Optimal subagents: {mentions}]')
if '''$memory_context''':
    enhanced_parts.append('[Memory context available]')
if chain:
    enhanced_parts.append('[Cross-chain tools discovered]')

context['enhanced_query'] = ' '.join(enhanced_parts)

with open('$CONTEXT_FILE', 'w') as f:
    json.dump(context, f, indent=2)

print(f'Context built: depth={context[\"depth\"]} todo_count={context[\"todo_count\"]} mentions={mentions}')
" 2>/dev/null
    
    # --- Step 0h: L1 Working Memory Store ---
    # Store session context in L1 (ephemeral, TTL-based)
    if [ -f "$BIN_DIR/angel-cortex.sh" ]; then
        local l1_key="unity-${SESSION_ID}"
        bash "$BIN_DIR/angel-cortex.sh" l1-store "$l1_key" "$query" 7200 2>/dev/null
        angel_print "memory" "L1 STORE" "session=$l1_key ttl=7200s"
    fi
    
    local elapsed=$(( $(date +%s) - start_time ))
    angel_info "  ✔ Enhance phase: ${elapsed}s"
    echo "$query"
}

# ============================================================================
# PHASE 1: ANALYZE — Deep understanding with ALL subsystems considered
# ============================================================================

unity_analyze() {
    local query="$1"
    local start_time
    start_time=$(date +%s)
    
    angel_info ""
    angel_info "╔══════════════════════════════════════════════════════════════════╗"
    angel_info "║  UNITY Phase 1: ANALYZE — Full System Analysis                  ║"
    angel_info "╚══════════════════════════════════════════════════════════════════╝"
    
    # Load enhanced context
    local context_json="{}"
    [ -f "$CONTEXT_FILE" ] && context_json=$(cat "$CONTEXT_FILE")
    
    # Full intent classification
    local intent complexity domains tools
    intent=$(angel_classify_intent "$query")
    complexity=$(angel_estimate_complexity "$query")
    domains=$(angel_detect_domains "$query")
    tools=$(angel_detect_tools "$query")
    
    angel_info "  🎯 Intent: $intent"
    angel_info "  📊 Complexity: $complexity (using full unified path regardless)"
    angel_info "  🏷️  Domains: $(echo "$domains" | python3 -c "import json,sys; print(', '.join(json.load(sys.stdin)))" 2>/dev/null || echo "$domains")"
    angel_info "  🛠️  Tools: $(echo "$tools" | python3 -c "import json,sys; print(', '.join(json.load(sys.stdin)))" 2>/dev/null || echo "$tools")"
    
    # Check ALL AngelKernel subsystems
    local subsystems_available=""
    local subsystems_used=""
    
    # Memory Cortex
    if [ -f "$BIN_DIR/angel-cortex.sh" ] && [ "${ANGEL_CORTEX_ENABLED:-true}" = "true" ]; then
        subsystems_available="$subsystems_available memory-cortex"
        subsystems_used="$subsystems_used memory-cortex"
    fi
    
    # Swarm Intelligence
    if [ -f "$BIN_DIR/angel-swarm.sh" ] && [ "${ANGEL_SWARM_ENABLED:-true}" = "true" ]; then
        subsystems_available="$subsystems_available swarm"
        # Only use swarm for critical decisions
        if echo "$domains" | python3 -c "import json,sys; d=json.load(sys.stdin); print('true' if any(x in str(d) for x in ['critical','decision','architect','consensus']) else 'false')" 2>/dev/null | grep -q "true"; then
            subsystems_used="$subsystems_used swarm"
            angel_info "  🐝 Swarm enabled for critical decisions"
        fi
    fi
    
    # Meta-Cognition
    if [ -f "$BIN_DIR/angel-metacog.sh" ] && [ "${ANGEL_METACOG_ENABLED:-true}" = "true" ]; then
        subsystems_available="$subsystems_available metacog"
        # Always use metacog for verification
        subsystems_used="$subsystems_used metacog"
    fi
    
    # Plugins
    if [ -f "$BIN_DIR/angel-plugin.sh" ] && [ "${ANGEL_PLUGIN_ENABLED:-true}" = "true" ]; then
        subsystems_available="$subsystems_available plugins"
        subsystems_used="$subsystems_used plugins"
    fi
    
    # Hooks
    if [ -f "$BIN_DIR/angel-hooks.sh" ] && [ "${ANGEL_HOOKS_ENABLED:-true}" = "true" ]; then
        subsystems_available="$subsystems_available hooks"
        subsystems_used="$subsystems_used hooks"
    fi
    
    # Self-Evolution
    if [ -f "$BIN_DIR/angel-self-improve.sh" ] && [ "${ANGEL_EVOLUTION_ENABLED:-true}" = "true" ]; then
        subsystems_available="$subsystems_available evolution"
        subsystems_used="$subsystems_used evolution"
    fi
    
    # MCP
    if [ -f "$BIN_DIR/angel-mcp-multiplexer.py" ]; then
        subsystems_available="$subsystems_available mcp"
        # MCP always available
        subsystems_used="$subsystems_used mcp"
    fi
    
    # Observability
    if [ -f "$BIN_DIR/angel-observe.sh" ] && [ "${ANGEL_OBSERVE_ENABLED:-true}" = "true" ]; then
        subsystems_available="$subsystems_available observe"
    fi
    
    # Subagents
    if [ -f "$BIN_DIR/angel-subagent.sh" ]; then
        subsystems_available="$subsystems_available subagents"
        subsystems_used="$subsystems_used subagents"
    fi
    
    angel_info "  ⚙️  Subsystems:${subsystems_used}"
    
    # Build analysis JSON
    python3 -c "
import json, sys

query = '''$query'''
intent = '''$intent'''
complexity = '''$complexity'''

analysis = {
    'session_id': '$SESSION_ID',
    'intent': intent,
    'complexity': complexity,
    'domains': json.loads('''$domains'''),
    'required_tools': json.loads('''$tools'''),
    'subsystems_available': '''${subsystems_available}'''.strip().split(),
    'subsystems_used': '''${subsystems_used}'''.strip().split(),
    'has_memory': int('$subsystems_used' != ''),
    'needs_swarm': 0 if 'swarm' not in '''$subsystems_used''' else 1,
    'needs_metacog': 1 if 'metacog' in '''$subsystems_used''' else 0,
    'needs_mcp': 1 if 'mcp' in '''$subsystems_used''' else 0,
    'needs_evolution': 1 if 'evolution' in '''$subsystems_used''' else 0,
    'optimal_mentions': json.loads(open('$CONTEXT_FILE').read()).get('enhanced_mentions', ['@general']),
    'plan_type': 'complex_multi_step' if complexity in ('complex', 'very_complex') else 'standard',
    'will_use_todos': int(open('$TODOS_FILE').read().strip() != '') if __import__('os').path.exists('$TODOS_FILE') else 0
}

with open('$WORK_DIR/analysis.json', 'w') as f:
    json.dump(analysis, f, indent=2)

print(json.dumps(analysis, indent=2))
" 2>/dev/null
    
    local elapsed=$(( $(date +%s) - start_time ))
    angel_info "  ✔ Analyze phase: ${elapsed}s"
}

# ============================================================================
# PHASE 2: PLAN — Dynamic plan with full subagent/tool/MCP routing
# ============================================================================

unity_plan() {
    local query="$1"
    local analysis="$2"
    local start_time
    start_time=$(date +%s)
    
    angel_info ""
    angel_info "╔══════════════════════════════════════════════════════════════════╗"
    angel_info "║  UNITY Phase 2: PLAN — Dynamic Execution Plan                   ║"
    angel_info "╚══════════════════════════════════════════════════════════════════╝"
    
    local plan
    plan=$(python3 -c "
import json, sys

query = '''$query'''
analysis = json.loads('''$analysis''')

intent = analysis.get('intent', 'autonomous')
complexity = analysis.get('complexity', 'medium')
domains = analysis.get('domains', ['general'])
tools = analysis.get('required_tools', [])
mentions = analysis.get('optimal_mentions', ['@general'])
use_todos = analysis.get('will_use_todos', 0)
has_mcp = analysis.get('needs_mcp', 0)
has_evolution = analysis.get('needs_evolution', 0)

# Load todos if they exist
todos = []
if use_todos and __import__('os').path.exists('$TODOS_FILE'):
    with open('$TODOS_FILE') as f:
        todos_data = json.load(f)
        todos = todos_data.get('todos', [])

# If we have auto-generated todos, use them as plan steps
if todos:
    steps = []
    for i, todo in enumerate(todos):
        task = todo.get('task', '')
        task_lower = task.lower()
        
        # Assign optimal subagent per todo
        if any(w in task_lower for w in ['code', 'program', 'script', 'function', 'implement', 'build', 'fix', 'debug']):
            agent = '@coder'
        elif any(w in task_lower for w in ['why', 'reason', 'plan', 'strategy', 'design', 'architect']):
            agent = '@thinker'
        elif any(w in task_lower for w in ['search', 'research', 'find', 'learn', 'investigate']):
            agent = '@researcher'
        elif any(w in task_lower for w in ['image', 'picture', 'design', 'art', 'logo', 'illustration']):
            agent = '@artist'
        elif any(w in task_lower for w in ['audio', 'speech', 'voice', 'sound']):
            agent = '@speaker'
        elif any(w in task_lower for w in ['write', 'content', 'article', 'story']):
            agent = '@writer'
        elif any(w in task_lower for w in ['review', 'verify', 'check', 'test']):
            agent = '@critic'
        elif any(w in task_lower for w in ['data', 'analyze', 'metrics', 'report']):
            agent = '@analyst'
        else:
            agent = '@general' if i == 0 else '@fast'
        
        # Detect tool type for this step
        tool_type = 'auto'
        if any(w in task_lower for w in ['image', 'picture', 'photo', 'illustration', 'design', 'logo']):
            tool_type = 'image_gen'
        elif any(w in task_lower for w in ['audio', 'speech', 'voice', 'music']):
            tool_type = 'audio_gen'
        elif any(w in task_lower for w in ['deploy', 'publish', 'upload']):
            tool_type = 'deploy'
        elif any(w in task_lower for w in ['search', 'research', 'find']):
            tool_type = 'research'
        
        steps.append({
            'id': i + 1,
            'task': task,
            'agent': agent,
            'tool_type': tool_type,
            'needs_mcp': has_mcp,
            'uses_memory': True,
            'dependencies': list(range(1, i)) if i > 0 else [],
            'parallel': False,
            'verify': True
        })
else:
    # Build steps from query analysis
    base_steps = 2  # Minimum: execute + verify
    if complexity in ('complex', 'very_complex'):
        base_steps = 5
    
    steps = []
    
    # Step 1: Always research/gather context
    steps.append({
        'id': 1,
        'task': f'Research and gather context for: {query}',
        'agent': mentions[0] if mentions else '@general',
        'tool_type': 'research',
        'needs_mcp': has_mcp,
        'uses_memory': True,
        'dependencies': [],
        'parallel': False,
        'verify': True
    })
    
    # Step 2: Plan/architect (if complex)
    if complexity in ('complex', 'very_complex'):
        steps.append({
            'id': 2,
            'task': f'Architect solution for: {query}',
            'agent': '@thinker',
            'tool_type': 'reasoning',
            'needs_mcp': has_mcp,
            'uses_memory': True,
            'dependencies': [1],
            'parallel': False,
            'verify': True
        })
    
    # Main execution step(s)
    base_id = len(steps) + 1
    
    # Use the primary optimal mention for execution
    primary_agent = mentions[0] if mentions else '@general'
    steps.append({
        'id': base_id,
        'task': f'Execute primary action: {query}',
        'agent': primary_agent,
        'tool_type': intent,
        'needs_mcp': True,
        'uses_memory': True,
        'dependencies': list(range(1, base_id)),
        'parallel': False,
        'verify': True
    })
    
    # If complex, add a verification step
    if complexity in ('complex', 'very_complex'):
        steps.append({
            'id': base_id + 1,
            'task': f'Verify and test results for: {query}',
            'agent': '@critic',
            'tool_type': 'verify',
            'needs_mcp': has_mcp,
            'uses_memory': True,
            'dependencies': [base_id],
            'parallel': False,
            'verify': False
        })
        
        # Add parallel execution branches for very complex
        if complexity == 'very_complex' and len(domains) > 1:
            for i, domain in enumerate(domains[:3]):
                if domain != 'general':
                    steps.append({
                        'id': base_id + 2 + i,
                        'task': f'Execute parallel domain: {domain} for: {query}',
                        'agent': '@fast' if i > 0 else '@executor',
                        'tool_type': domain,
                        'needs_mcp': True,
                        'uses_memory': True,
                        'dependencies': [base_id],
                        'parallel': True,
                        'verify': False
                    })

# Build final plan
plan = {
    'session_id': '$SESSION_ID',
    'query': query,
    'intent': intent,
    'complexity': complexity,
    'total_steps': len(steps),
    'steps': steps,
    'parallel_groups': [
        [s['id'] for s in steps if s.get('parallel')]
    ] if any(s.get('parallel') for s in steps) else [],
    'verification_points': [s['id'] for s in steps if s.get('verify')],
    'all_subsystems_active': True,
    'max_depth': ${MAX_DEPTH},
    'current_depth': ${DEPTH}
}

with open('$PLAN_FILE', 'w') as f:
    json.dump(plan, f, indent=2)

print(json.dumps(plan, indent=2))
" 2>/dev/null)
    
    # Display plan
    local step_count
    step_count=$(echo "$plan" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_steps',0))" 2>/dev/null)
    angel_info "  📋 Plan: $step_count steps"
    
    # Show steps
    echo "$plan" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for s in d.get('steps', []):
    agent = s.get('agent', '@general')
    task = s.get('task', '')[:70]
    deps = s.get('dependencies', [])
    dep_str = f' (after step {deps})' if deps else ''
    par_str = ' [PARALLEL]' if s.get('parallel') else ''
    print(f'    Step {s[\"id\"]}: [{agent}] {task}{dep_str}{par_str}')
" 2>/dev/null
    
    local elapsed=$(( $(date +%s) - start_time ))
    angel_info "  ✔ Plan phase: ${elapsed}s"
    echo "$plan"
}

# ============================================================================
# PHASE 3: EXECUTE — Multi-modal execution with ALL capabilities
# ============================================================================

unity_execute() {
    local query="$1"
    local plan_json="$2"
    local start_time
    start_time=$(date +%s)
    
    angel_info ""
    angel_info "╔══════════════════════════════════════════════════════════════════╗"
    angel_info "║  UNITY Phase 3: EXECUTE — Full Autonomous Execution             ║"
    angel_info "╚══════════════════════════════════════════════════════════════════╝"
    
    local step_count
    step_count=$(echo "$plan_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('steps',[])))" 2>/dev/null)
    local results='[]'
    local all_success=true
    
    for ((i=0; i<step_count; i++)); do
        local step_id step_task step_agent step_tool step_verify step_deps
        step_id=$(echo "$plan_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['steps'][$i]['id'])" 2>/dev/null)
        step_task=$(echo "$plan_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['steps'][$i]['task'])" 2>/dev/null)
        step_agent=$(echo "$plan_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['steps'][$i]['agent'])" 2>/dev/null)
        step_tool=$(echo "$plan_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['steps'][$i].get('tool_type','auto'))" 2>/dev/null)
        step_verify=$(echo "$plan_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['steps'][$i].get('verify',False))" 2>/dev/null)
        
        angel_info ""
        angel_info "  ── Step $step_id/$step_count: [$step_agent] ${step_task:0:80}... ──"
        
        # Execute with auto-retry
        local step_result=""
        local step_success=false
        local max_attempts=3
        local attempt=1
        
        while [ $attempt -le $max_attempts ] && [ "$step_success" = "false" ]; do
            if [ $attempt -gt 1 ]; then
                angel_info "  🔄 Retry $attempt/$max_attempts (different approach)"
            fi
            
            # Route to execution mode based on tool type
            case "$step_tool" in
                image_gen)
                    angel_print "call" "IMAGE GEN" "$step_task"
                    step_result=$(bash "$BIN_DIR/angel-proxy.sh" generate image "$step_task" "$WORK_DIR/step-${step_id}.png" 2>/dev/null)
                    [ -n "$step_result" ] && step_success=true
                    ;;
                    
                audio_gen)
                    angel_print "call" "AUDIO GEN" "$step_task"
                    step_result=$(bash "$BIN_DIR/angel-proxy.sh" generate audio "$step_task" "$WORK_DIR/step-${step_id}.mp3" 2>/dev/null)
                    [ -n "$step_result" ] && step_success=true
                    ;;
                    
                research)
                    angel_print "call" "RESEARCH" "$step_task"
                    # Try multiple research sources
                    step_result=$(bash "$BIN_DIR/angel-subagent.sh" @researcher "$step_task" 2>/dev/null)
                    if [ -z "$step_result" ] || [ $? -ne 0 ]; then
                        # Fallback to cortex recall
                        step_result=$(bash "$BIN_DIR/angel-cortex.sh" recall "$step_task" 3 2>/dev/null)
                    fi
                    [ -n "$step_result" ] && step_success=true
                    ;;
                    
                verify)
                    angel_print "call" "VERIFY" "$step_task"
                    if [ -f "$BIN_DIR/angel-metacog.sh" ]; then
                        step_result=$(bash "$BIN_DIR/angel-metacog.sh" assess "Verify results: $step_task" 2>/dev/null)
                    fi
                    step_success=true
                    ;;
                    
                *)
                    # Default: use optimal subagent
                    angel_print "call" "SUBAGENT" "$step_agent → $step_task"
                    if [ -f "$BIN_DIR/angel-subagent.sh" ]; then
                        # Extract @mention without the @
                        local agent_name="${step_agent#@}"
                        step_result=$(bash "$BIN_DIR/angel-subagent.sh" "$step_agent" "$step_task" 2>/dev/null)
                        
                        if [ -z "$step_result" ] && [ "$step_agent" != "@general" ]; then
                            # Fallback to @general
                            angel_info "  ⚠️  $step_agent failed, falling back to @general"
                            step_result=$(bash "$BIN_DIR/angel-subagent.sh" @general "$step_task" 2>/dev/null)
                        fi
                    fi
                    [ -n "$step_result" ] && step_success=true
                    ;;
            esac
            
            # Verify if needed
            if [ "$step_success" = "true" ] && [ "$step_verify" = "True" ]; then
                if [ -f "$BIN_DIR/angel-metacog.sh" ] && [ "${ANGEL_METACOG_ENABLED:-true}" = "true" ]; then
                    local verified
                    verified=$(bash "$BIN_DIR/angel-metacog.sh" assess "Verify: $step_task" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('passed', 'false'))" 2>/dev/null || echo "true")
                    if [ "$verified" != "true" ]; then
                        angel_warn "  ✖ Step $step_id verification failed"
                        step_success=false
                        # Log to evolution
                        [ -f "$BIN_DIR/angel-self-improve.sh" ] && \
                            bash "$BIN_DIR/angel-self-improve.sh" --error "verify" "step-$step_id" "Verification failed: $step_task" 2>/dev/null
                    else
                        angel_info "  ✔ Step $step_id verified"
                    fi
                fi
            fi
            
            if [ "$step_success" = "false" ]; then
                attempt=$((attempt + 1))
                # Self-heal on failure
                if [ -f "$BIN_DIR/angel-evolve.sh" ] && [ "${ANGEL_EVOLUTION_ENABLED:-true}" = "true" ]; then
                    angel_print "evolve" "HEAL" "attempt=$attempt for step $step_id"
                    bash "$BIN_DIR/angel-evolve.sh" cycle "Step $step_id failed: $step_task" "query=$query" 2>/dev/null &
                fi
                sleep 1
            fi
        done
        
        if [ "$step_success" = "true" ]; then
            angel_info "  ✔ Step $step_id completed (attempt $attempt)"
        else
            angel_warn "  ✖ Step $step_id failed after $max_attempts attempts"
            all_success=false
            # Log failure to evolution
            [ -f "$BIN_DIR/angel-self-improve.sh" ] && \
                bash "$BIN_DIR/angel-self-improve.sh" --error "execution" "step-$step_id" "Failed after $max_attempts attempts: $step_task" 2>/dev/null
        fi
        
        # Store step in memory
        if [ -f "$BIN_DIR/angel-cortex.sh" ] && [ "${ANGEL_CORTEX_ENABLED:-true}" = "true" ]; then
            local summary
            summary="[unity] Step $step_id ($step_agent): ${step_task:0:80} | success=$step_success"
            bash "$BIN_DIR/angel-cortex.sh" store "$summary" "execution" "{\"session\":\"$SESSION_ID\",\"step\":$step_id,\"agent\":\"$step_agent\",\"success\":$step_success}" 2>/dev/null &
        fi
        
        # Update results
        results=$(python3 -c "
import json, sys
r = json.loads('''$results''')
r.append({
    'step': $step_id,
    'agent': '$step_agent',
    'task': '''$step_task''',
    'success': $step_success,
    'attempts': $attempt,
    'tool_type': '$step_tool'
})
print(json.dumps(r))
" 2>/dev/null)
        
        # Fire step hook
        if [ -f "$BIN_DIR/angel-hooks.sh" ] && [ "${ANGEL_HOOKS_ENABLED:-true}" = "true" ]; then
            bash "$BIN_DIR/angel-hooks.sh" fire "unity:step-complete" "$SESSION_ID" "$step_id" "$step_success" 2>/dev/null &
        fi
    done
    
    echo "$results" > "$RESULTS_FILE"
    
    local elapsed=$(( $(date +%s) - start_time ))
    angel_info ""
    angel_info "  ═══════════════════════════════════════════"
    if [ "$all_success" = "true" ]; then
        angel_info "  ✔ EXECUTION COMPLETE: $step_count steps in ${elapsed}s"
    else
        angel_warn "  ⚠️  EXECUTION PARTIAL: $step_count steps in ${elapsed}s with failures"
    fi
    angel_info "  ═══════════════════════════════════════════"
    
    echo "$results"
}

# ============================================================================
# PHASE 4: EVOLVE — Verify + Learn + Mycelium Cross-Pollination + Evolution
# Integrates mycelium patterns into self-improvement:
#   - After steps, cross-pollinate learnings across domains
#   - Forage for unexpected connections
#   - Extract skills from patterns
#   - Store evolution history
# ============================================================================

unity_evolve() {
    local query="$1"
    local results="$2"
    local success="$3"
    local start_time
    start_time=$(date +%s)
    
    angel_info ""
    angel_info "╔══════════════════════════════════════════════════════════════════╗"
    angel_info "║  UNITY Phase 4: EVOLVE — Verification & Mycelium Learning      ║"
    angel_info "╚══════════════════════════════════════════════════════════════════╝"
    
    # --- Step 4a: Meta-Cognition Verification ---
    if [ -f "$BIN_DIR/angel-metacog.sh" ] && [ "${ANGEL_METACOG_ENABLED:-true}" = "true" ]; then
        angel_print "call" "METACOG" "assessing overall results..."
        local metacog_result
        metacog_result=$(bash "$BIN_DIR/angel-metacog.sh" assess "Overall session results: $query" 2>/dev/null)
        local confidence
        confidence=$(echo "$metacog_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('confidence', '0.5'))" 2>/dev/null || echo "0.5")
        angel_info "  🧐 Confidence: $confidence"
    fi
    
    # --- Step 4b: Self-Improvement & Learning ---
    if [ -f "$BIN_DIR/angel-self-improve.sh" ] && [ "${ANGEL_EVOLUTION_ENABLED:-true}" = "true" ]; then
        # Log learning
        local learned="[unity] Session $SESSION_ID: $query | success=$success | steps=$(echo "$results" | python3 -c "import json,sys; r=json.load(sys.stdin); print(len(r))" 2>/dev/null || echo "0")"
        # --- L1 Working Memory: Recall session context ---
        local l1_context=""
        local l1_key="unity-${SESSION_ID}"
        if [ -f "$BIN_DIR/angel-cortex.sh" ]; then
            l1_context=$(bash "$BIN_DIR/angel-cortex.sh" l1-get "$l1_key" 2>/dev/null)
            if [ -n "$l1_context" ]; then
                angel_print "memory" "L1 RECALL" "session=$l1_key retrieved"
                # Store the L1 context into L2 as an episodic memory of the session
                bash "$BIN_DIR/angel-cortex.sh" store "Unity session $SESSION_ID completed: $l1_context" "unity-session" 2>/dev/null
            fi
        fi
        
        bash "$BIN_DIR/angel-self-improve.sh" --learn "unity-execution" "session" "$learned" 2>/dev/null
        
        # --- MYCELIUM INTEGRATION: Cross-pollination Analysis ---
        # Mycelium "forage" — find unexpected connections between domains
        angel_print "evolve" "MYCELIUM FORAGE" "cross-pollinating learnings across domains..."
        local mycelium_insights
        mycelium_insights=$(python3 -c "
import json, sys

# Simulate mycelium-style cross-pollination
# Analyze the learnings file for cross-domain connections
learnings_file = '$ANGEL_HOME/memory/learnings/LEARNINGS.md'
domains = set()
connections = []

try:
    with open(learnings_file) as f:
        content = f.read()
        lines = content.split('\n')
        current_pattern = ''
        for line in lines:
            if '**Pattern**:' in line:
                current_pattern = line.split('**Pattern**: ')[-1].strip()
                domains.add(current_pattern)
            if current_pattern and 'unity-' in line:
                connections.append(current_pattern)
except:
    pass

# Mycelium-style analysis: find bridge concepts
bridge_concepts = []
if len(domains) >= 2:
    dlist = list(domains)
    for i in range(len(dlist)):
        for j in range(i+1, len(dlist)):
            bridge_concepts.append(f'{dlist[i]} ↔ {dlist[j]}')

result = {
    'domains_tracked': len(domains),
    'domain_list': list(domains)[:5],
    'cross_domain_bridges': bridge_concepts[:3],
    'mycelium_insight': 'Cross-pollination available between domains' if bridge_concepts else 'Building domain knowledge',
    'evolution_suggestion': 'Consider extracting cross-domain skill' if len(bridge_concepts) >= 2 else 'Continue building patterns'
}

# Apply mycelium insight: if we have 2+ domains, suggest cross-pollination
if len(bridge_concepts) >= 2:
    result['action'] = 'cross_pollinate'
    print(json.dumps(result))
    sys.exit(0)

result['action'] = 'continue'
print(json.dumps(result))
" 2>/dev/null)
        
        local mycelium_action
        mycelium_action=$(echo "$mycelium_insights" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('action','continue'))" 2>/dev/null || echo "continue")
        local bridge_count
        bridge_count=$(echo "$mycelium_insights" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('cross_domain_bridges',[])))" 2>/dev/null || echo "0")
        
        if [ "$mycelium_action" = "cross_pollinate" ]; then
            angel_info "  🍄 Mycelium: $bridge_count cross-domain bridges found"
            angel_info "  🍄 Cross-pollination recommended"
        fi
        
        # Mycelium "track" — update domain exploration history
        local domains
        domains=$(echo "$results" | python3 -c "
import json, sys
r = json.load(sys.stdin)
agents = set(s.get('agent','') for s in r)
print(' '.join(agents))
" 2>/dev/null || echo "general")
        
        # Store in mycelium-style profile (flat file)
        local mycelium_profile="$ANGEL_HOME/memory/learnings/mycelium-profile.md"
        if [ ! -f "$mycelium_profile" ]; then
            echo "# Mycelium — Domain & Learning Profile" > "$mycelium_profile"
            echo "" >> "$mycelium_profile"
            echo "Auto-generated by AngelKernel Unity Engine" >> "$mycelium_profile"
            echo "" >> "$mycelium_profile"
            echo "## Domains Explored" >> "$mycelium_profile"
            echo "" >> "$mycelium_profile"
        fi
        echo "- [$(date +%Y-%m-%d)] Session $SESSION_ID: $domains" >> "$mycelium_profile"
        angel_info "  🍄 Mycelium profile updated"
        
        # --- Extract skills from patterns (3+ occurrences) ---
        angel_print "evolve" "EXTRACT SKILLS" "checking for patterns..."
        bash "$BIN_DIR/angel-self-improve.sh" --extract 2>/dev/null
        
        # --- Evolution DB update ---
        local evolution_db="$ANGEL_HOME/store/evolution/evolution.json"
        mkdir -p "$(dirname "$evolution_db")"
        local evol_entry
        evol_entry=$(python3 -c "
import json, sys
entry = {
    'ts': $(date +%s),
    'session': '$SESSION_ID',
    'query': '''$query''',
    'success': $success,
    'mycelium_bridges': $bridge_count,
    'mycelium_action': '$mycelium_action',
    'steps': json.loads('''$results''') if '''$results''' else []
}
print(json.dumps(entry))
" 2>/dev/null)
        
        if [ -f "$evolution_db" ]; then
            local evol_data
            evol_data=$(cat "$evolution_db" 2>/dev/null || echo '{"evolutions": []}')
            python3 -c "
import json
d = json.loads('''$evol_data''')
d['evolutions'].append(json.loads('''$evol_entry'''))
with open('$evolution_db', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null
        else
            echo "{\"evolutions\": [$evol_entry]}" > "$evolution_db"
        fi
        angel_info "  🔄 Evolution DB updated"
    fi
    
    # --- Step 4c: Log to observability ---
    [ -f "$BIN_DIR/angel-observe.sh" ] && bash "$BIN_DIR/angel-observe.sh" metric "unity.execution" 1 "{\"session\":\"$SESSION_ID\",\"success\":$success}" 2>/dev/null &
    
    # --- Step 4d: Fire evolution hooks ---
    [ -f "$BIN_DIR/angel-hooks.sh" ] && [ "${ANGEL_HOOKS_ENABLED:-true}" = "true" ] && \
        bash "$BIN_DIR/angel-hooks.sh" fire "unity:evolve-complete" "$SESSION_ID" "$success" 2>/dev/null &
    
    local elapsed=$(( $(date +%s) - start_time ))
    angel_info "  ✔ Evolve phase: ${elapsed}s"
    return 0
}

# ============================================================================
# PHASE 5: REFLECT — Recursive Post-Task Analysis + Auto-Reloop
# Analyzes workspace/codebase after execution.
# If critical findings → distill to prompt → recursive loop.
# If needs clarification → present plan to user.
# ============================================================================

unity_reflect() {
    local query="$1"
    local results="$2"
    local success="$3"
    local start_time
    start_time=$(date +%s)
    
    angel_info ""
    angel_info "╔══════════════════════════════════════════════════════════════════╗"
    angel_info "║  UNITY Phase 5: REFLECT — Recursive Workspace Analysis          ║"
    angel_info "╚══════════════════════════════════════════════════════════════════╝"
    
    local workspace="${ANGEL_WORKSPACE:-/root}"
    local reflection=""
    
    # --- Step 5a: Workspace / Codebase Scan ---
    angel_print "call" "SCAN" "analyzing workspace: $workspace"
    
    # Check if we're in a git repo or project directory
    local is_git=false
    [ -d "$workspace/.git" ] && is_git=true
    
    reflection=$(python3 -c "
import json, sys, os

workspace = '''$workspace'''
results_str = '''$results'''
query = '''$query'''
success = '''$success''' == 'true'

analysis = {
    'workspace': workspace,
    'session': '$SESSION_ID',
    'query': query,
    'execution_success': success,
}

# Check workspace health
issues = []
warnings = []
improvements = []

# Check for known issue patterns
issue_patterns = [
    ('node_modules', 'dependency_dir', 'Large node_modules directory — run npm prune'),
    ('.env', 'env_file', 'Environment file detected — ensure not committed'),
    ('target/', 'build_dir', 'Build artifacts directory found'),
    ('*.pyc', 'cache_files', 'Python cache files found — consider .gitignore'),
]

for pattern, category, msg in issue_patterns:
    if os.path.exists(os.path.join(workspace, pattern)):
        issues.append({'type': category, 'message': msg, 'severity': 'low'})

# Check git state
git_dir = os.path.join(workspace, '.git')
if os.path.isdir(git_dir):
    try:
        # Check for uncommitted changes
        import subprocess
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True, cwd=workspace, timeout=5)
        if result.stdout.strip():
            changes = result.stdout.strip().split('\n')
            issues.append({
                'type': 'uncommitted_changes',
                'message': f'{len(changes)} uncommitted change(s)',
                'severity': 'medium'
            })
            improvements.append('Commit changes or stash them')
    except:
        pass

# Check for recent error logs
log_dir = os.path.join('$ANGEL_HOME/logs')
if os.path.isdir(log_dir):
    try:
        recent_errors = []
        for fname in os.listdir(log_dir):
            fpath = os.path.join(log_dir, fname)
            if os.path.isfile(fpath) and os.path.getmtime(fpath) > (time.time() - 86400):
                with open(fpath) as f:
                    for line in f.readlines()[-50:]:
                        if 'ERROR' in line or 'FATAL' in line:
                            recent_errors.append(line.strip()[:100])
        if recent_errors:
            warnings.append(f'{len(recent_errors)} recent error(s) in logs')
    except:
        pass

# Check for uncommitted changes in evolution
evol_db = os.path.expanduser('$ANGEL_HOME/store/evolution/evolution.json')
if os.path.isfile(evol_db):
    try:
        with open(evol_db) as f:
            evol_data = json.load(f)
        evol_count = len(evol_data.get('evolutions', []))
        analysis['evolution_entries'] = evol_count
        improvements.append(f'Evolution DB has {evol_count} entries')
    except:
        pass

analysis['issues'] = issues
analysis['warnings'] = warnings
analysis['improvements'] = improvements
analysis['issue_count'] = len(issues)
analysis['critical_count'] = sum(1 for i in issues if i.get('severity') in ('high', 'critical'))
analysis['has_actionable_findings'] = len(issues) > 0 or not success

# Determine action: re-loop if critical, present if needs clarity
if analysis['critical_count'] > 0:
    analysis['recommended_action'] = 're_loop'
elif analysis['issue_count'] > 0 or not success:
    analysis['recommended_action'] = 'present_plan'
else:
    analysis['recommended_action'] = 'present_summary'

print(json.dumps(analysis, indent=2))
" 2>/dev/null)
    
    local issue_count critical_count recommended_action
    issue_count=$(echo "$reflection" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('issue_count',0))" 2>/dev/null || echo "0")
    critical_count=$(echo "$reflection" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('critical_count',0))" 2>/dev/null || echo "0")
    recommended_action=$(echo "$reflection" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('recommended_action','present_summary'))" 2>/dev/null || echo "present_summary")
    
    echo "$reflection" > "$REFLECTION_FILE"
    
    # Display findings
    angel_info "  🔍 Issues found: $issue_count ($critical_count critical)"
    echo "$reflection" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for i in d.get('issues', []):
    severity = i.get('severity', 'low')
    icon = '🔴' if severity == 'high' else ('🟡' if severity == 'medium' else '🟢')
    print(f'    {icon} [{severity}] {i[\"message\"]}')
for w in d.get('warnings', []):
    print(f'    ⚠️  {w}')
for imp in d.get('improvements', []):
    print(f'    💡 {imp}')
" 2>/dev/null
    
    # --- Step 5b: Act on Reflection ---
    case "$recommended_action" in
        re_loop)
            # Critical findings → distill into prompt → recursive loop
            angel_warn "  🔄 CRITICAL ISSUES FOUND — Initiating recursive refinement loop"
            local distill_prompt
            distill_prompt=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
issues = d.get('issues', [])
critical = [i for i in issues if i.get('severity') in ('high', 'critical')]
improvements = d.get('improvements', [])

prompt = f'[RECURSIVE REFINEMENT] Issues found after: {query}\\n'
for i in critical:
    prompt += f'\\n- CRITICAL: {i[\"message\"]}'
for i in issues:
    if i.get('severity') not in ('high', 'critical'):
        prompt += f'\\n- {i[\"message\"]}'
if improvements:
    prompt += f'\\n\\nSuggested improvements:'
    for imp in improvements:
        prompt += f'\\n- {imp}'
prompt += '\\n\\nRefine and fix all issues listed above.'
print(prompt)
" 2>/dev/null)
            
            # Recursive call with distilled prompt (if under max depth)
            if [ "$DEPTH" -lt "$MAX_DEPTH" ]; then
                angel_info "  🔄 Recursive refinement (depth $((DEPTH + 1))/$MAX_DEPTH)"
                export ANGEL_DEPTH=$((DEPTH + 1))
                unity_main "$distill_prompt"
                return $?
            else
                angel_warn "  ⚠️ Max recursion depth reached. Presenting findings."
                # Present as plan
                echo ""
                echo "╔══════════════════════════════════════════════╗"
                echo "║  Recursive Refinement — Max Depth Reached   ║"
                echo "╚══════════════════════════════════════════════╝"
                echo ""
                echo "Analysis revealed critical issues but max depth ($MAX_DEPTH) reached."
                echo ""
                echo "$reflection" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Critical Issues:')
for i in d.get('issues', []):
    if i.get('severity') in ('high', 'critical'):
        print(f'  🔴 {i[\"message\"]}')
print()
print('All Issues:')
for i in d.get('issues', []):
    print(f'  - {i[\"message\"]}')
print()
print('Suggested Improvements:')
for imp in d.get('improvements', []):
    print(f'  💡 {imp}')
" 2>/dev/null
                echo ""
                echo "Proceed? (Will continue autonomously)"
            fi
            ;;
            
        present_plan)
            # Non-critical but notable findings → present as plan to user
            angel_info "  📋 Presenting findings and improvement plan"
            echo ""
            echo "╔══════════════════════════════════════════════╗"
            echo "║  Post-Execution Analysis — Plan             ║"
            echo "╚══════════════════════════════════════════════╝"
            echo ""
            echo "$reflection" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('issues'):
    print('Issues detected:')
    for i in d['issues']:
        sev = i.get('severity', 'info')
        icon = '🔴' if sev == 'high' else ('🟡' if sev == 'medium' else '🟢')
        print(f'  {icon} [{sev}] {i[\"message\"]}')
    print()
if d.get('improvements'):
    print('Suggestions:')
    for imp in d['improvements']:
        print(f'  💡 {imp}')
    print()
print('Session overall: {\"success\": '${success}', \"issues\": '${issue_count}'}')
" 2>/dev/null
            ;;
            
        present_summary)
            # Clean run — just summarize
            angel_info "  ✅ Clean execution — no issues found"
            echo ""
            echo "╔══════════════════════════════════════════════╗"
            echo "║  Post-Execution Analysis — Summary          ║"
            echo "╚══════════════════════════════════════════════╝"
            echo ""
            echo "  No issues detected in workspace."
            echo "  Session $SESSION_ID completed successfully."
            echo ""
            ;;
    esac
    
    # --- Step 5c: Store Reflection to Memory ---
    if [ -f "$BIN_DIR/angel-cortex.sh" ] && [ "${ANGEL_CORTEX_ENABLED:-true}" = "true" ]; then
        local reflection_summary
        reflection_summary="[unity-reflect] Session $SESSION_ID: $issue_count issues, action=$recommended_action"
        bash "$BIN_DIR/angel-cortex.sh" store "$reflection_summary" "reflection" "{\"session\":\"$SESSION_ID\",\"issues\":$issue_count,\"action\":\"$recommended_action\"}" 2>/dev/null &
    fi
    
    # --- Step 5d: Fire reflection hooks ---
    [ -f "$BIN_DIR/angel-hooks.sh" ] && [ "${ANGEL_HOOKS_ENABLED:-true}" = "true" ] && \
        bash "$BIN_DIR/angel-hooks.sh" fire "unity:reflect-complete" "$SESSION_ID" "$issue_count" "$recommended_action" 2>/dev/null &
    
    local elapsed=$(( $(date +%s) - start_time ))
    angel_info "  ✔ Reflect phase: ${elapsed}s"
    
    # Return reflection
    echo "$reflection"
}

# ============================================================================
# UNITY MAIN — The single entry point for ALL queries
# Phases: NEURAL → ENHANCE → ANALYZE → PLAN → EXECUTE → EVOLVE → REFLECT
# ============================================================================

unity_main() {
    local query="$*"
    local unity_start
    unity_start=$(date +%s)
    
    # Welcome banner
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     AngelKernel Neural Execution Engine v4.0                ║"
    echo "║     Session: $SESSION_ID"
    echo "║     Depth: $DEPTH / $MAX_DEPTH"
    echo "║     Mode: NEURAL AUTONOMOUS (all subsystems active)        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    
    # Validate query
    if [ -z "$query" ]; then
        angel_error "No query provided"
        echo "Usage: angel-unity.sh <query>"
        exit 1
    fi
    
    # === PHASE 0: NEURAL — Neural Cognition (runs BEFORE enhance) ===
    local neural_enhanced_query
    neural_enhanced_query=$(unity_neural "$query")
    
    # === PHASE 1: ENHANCE ===
    local enhanced_query
    enhanced_query=$(unity_enhance "$neural_enhanced_query")
    
    # === PHASE 2: ANALYZE ===
    local analysis
    analysis=$(unity_analyze "$enhanced_query")
    
    # === PHASE 3: PLAN ===
    local plan
    plan=$(unity_plan "$enhanced_query" "$analysis")
    
    # === PHASE 4: EXECUTE ===
    local results
    results=$(unity_execute "$enhanced_query" "$plan")
    
    # Determine success
    local overall_success="false"
    if echo "$results" | python3 -c "import json,sys; r=json.load(sys.stdin); all_success=all(s.get('success',False) for s in r); print('true' if all_success else 'false')" 2>/dev/null | grep -q "true"; then
        overall_success="true"
    fi
    
    # === PHASE 5: EVOLVE ===
    unity_evolve "$enhanced_query" "$results" "$overall_success"
    
    # === PHASE 6: REFLECT ===
    local reflection
    reflection=$(unity_reflect "$enhanced_query" "$results" "$overall_success")
    
    # === COMPLETE ===
    local total_elapsed=$(( $(date +%s) - unity_start ))
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  AngelKernel Unity Complete                                 ║"
    echo "║  Session: $SESSION_ID"
    echo "║  Status:  $overall_success"
    echo "║  Elapsed: ${total_elapsed}s across 7 phases (NEURAL→ENHANCE→ANALYZE→PLAN→EXECUTE→EVOLVE→REFLECT)"
    echo "║  Depth:   $DEPTH / $MAX_DEPTH"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Final trace
    angel_trace "complete" "angel-unity.sh" "main" \
        "session=$SESSION_ID success=$overall_success elapsed=${total_elapsed}s depth=$DEPTH" \
        "$total_elapsed" "$([ "$overall_success" = "true" ] && echo ok || echo error)"
}

# ============================================================================
# MAIN ENTRY
# ============================================================================

# Check for help flag
case "${1:-}" in
    --help|-h)
        echo "AngelKernel Neural Execution Engine v4.0"
        echo ""
        echo "A SINGLE autonomous path for ALL queries that activates EVERY"
        echo "AngelKernel subsystem (Memory, Swarm, MCP, MetaCog, Evolution, etc.)"
        echo ""
        echo "Usage:"
        echo "  angel-unity.sh <natural language query>"
        echo "  angel-unity.sh --help"
        echo ""
        echo "Examples:"
        echo "  angel-unity.sh \"Build a card game with custom art\""
        echo "  angel-unity.sh \"Research AI trends and generate a report\""
        echo "  angel-unity.sh \"Fix bugs in my project and optimize it\""
        echo ""
        echo "All phases run for EVERY query — complexity scales internally."
        echo "All providers are FREE. No API keys required."
        exit 0
        ;;
esac

# Run the unified pipeline
unity_main "$@"
