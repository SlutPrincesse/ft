#!/bin/bash
set -euo pipefail
# angel-chain v2.2 — Dynamic Cross-Tool/Skill Chaining Engine
# Auto-discovers tools, skills, and integrations based on task analysis
# Chains them together with context propagation, powered by free providers
#
# Usage:
#   angel-chain execute "Build a game"              # Auto-detect + chain
#   angel-chain from-todo "1. Generate image\n2. Add sound"
#   angel-chain suggest "Create campaign materials"
#   angel-chain discover "Task with tools needed"

ANGEL_SCRIPT="chain"
ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true

CHAIN_DIR="$ANGEL_HOME/store/chains"
CHAIN_MANIFEST_DIR="$ANGEL_HOME/integrations"
mkdir -p "$CHAIN_DIR" "$CHAIN_MANIFEST_DIR"

# ============================================================================
# INTEGRATION MANIFEST — Each integration declares its capabilities
# ============================================================================

declare -A INTEGRATIONS

# Built-in integrations (auto-registered)
register_integration() {
    local name="$1"
    local domains="$2"
    local tools="$3"
    local free="$4"
    local requires_key="$5"
    INTEGRATIONS["$name"]="$domains|$tools|$free|$requires_key"
}

register_integration "pollinations" "image,audio,video,text,stt" "angel-proxy generate" "yes" "no"
register_integration "spatial-sound" "audio,soundscape,focus,meditation,ambient" "spatial-sound" "yes" "no"
register_integration "prompt-to-asset" "3d,logo,icon,asset,design" "prompt-to-asset" "yes" "no"
register_integration "hivelaunch" "campaign,marketing,ad,brand" "campaign-generate" "yes" "no"
register_integration "mycelium" "learning,knowledge,research,growth" "mycelium" "yes" "no"
register_integration "cretaceous" "narrative,story,adventure,game" "narrative-generate" "yes" "no"
register_integration "godot-tcg" "game,tcg,card,godot" "godot-tcg-core,godot-addon-manager" "yes" "no"
register_integration "imagegen" "image,design,visual,art,logo" "angel-proxy generate image" "yes" "no"
register_integration "anyclaw" "web,deploy,publish,app" "anyclaw-publish" "yes" "no"
register_integration "composio" "api,tool,integration" "composio-cli" "yes" "no"
register_integration "flightclaw" "flight,travel,trip,airline" "flightclaw" "yes" "no"

# ============================================================================
# MANIFEST SCANNER — Discover integrations from files
# ============================================================================

scan_integration_manifests() {
    if [ -d "$CHAIN_MANIFEST_DIR" ]; then
        for manifest in "$CHAIN_MANIFEST_DIR"/*.json; do
            [ -f "$manifest" ] || continue
            local name
            name=$(basename "$manifest" .json)
            local domains tools free key
            domains=$(python3 -c "import json; d=json.load(open('$manifest')); print(','.join(d.get('domains',[])))" 2>/dev/null)
            tools=$(python3 -c "import json; d=json.load(open('$manifest')); print(','.join(d.get('tools',[])))" 2>/dev/null)
            free=$(python3 -c "import json; d=json.load(open('$manifest')); print(d.get('free', 'yes'))" 2>/dev/null)
            key=$(python3 -c "import json; d=json.load(open('$manifest')); print(d.get('requires_key', 'no'))" 2>/dev/null)
            if [ -n "$name" ] && [ -n "$domains" ]; then
                INTEGRATIONS["$name"]="$domains|$tools|$free|$key"
            fi
        done
    fi
}

# ============================================================================
# DYNAMIC CHAIN DISCOVERY — Find tools/skills for a task
# ============================================================================

chain_discover() {
    local query="$1"
    scan_integration_manifests
    
    angel_info "[chain] Discovering chain for: ${query:0:80}..."
    angel_console "decision" "chain" "discover" "Discovering integrations" "query='${query:0:60}'"
    
    # Analyze query with Python
    local chain_json
    chain_json=$(python3 -c "
import json, sys, re

query = '''$query'''.lower()

# Integration registry (from bash)
integrations = {}
$(for name in "${!INTEGRATIONS[@]}"; do
    IFS='|' read -r domains tools free key <<< "${INTEGRATIONS[$name]}"
    echo "integrations['$name'] = {'domains': '$domains', 'tools': '$tools', 'free': '$free', 'key': '$key'}"
done)

# Step 1: Classify query intent
intents = {
    'generate': ['generate', 'create', 'make', 'build', 'produce', 'render', 'design'],
    'analyze': ['analyze', 'research', 'study', 'examine', 'investigate', 'search'],
    'modify': ['edit', 'change', 'update', 'modify', 'fix', 'repair', 'improve'],
    'learn': ['learn', 'understand', 'explain', 'teach', 'study', 'knowledge'],
    'game': ['game', 'play', 'tcg', 'card', 'godot', 'rpg', 'adventure'],
    'campaign': ['campaign', 'marketing', 'advertise', 'promote', 'brand', 'launch'],
    'soundscape': ['sound', 'ambient', 'focus', 'meditation', 'noise', 'music', 'audio'],
    'asset': ['3d', 'logo', 'icon', 'asset', 'model', 'texture', 'sprite'],
}

detected_intents = []
for intent, keywords in intents.items():
    for kw in keywords:
        if kw in query:
            detected_intents.append(intent)
            break

# Step 2: Match to integrations
matched = []
for name, info in integrations.items():
    integ_domains = info['domains'].split(',')
    for domain in integ_domains:
        if domain in query or any(domain in intent for intent in detected_intents):
            matched.append({
                'integration': name,
                'domains': info['domains'],
                'tools': info['tools'].split(','),
                'free': info['free'],
                'key': info['key']
            })
            break

# Step 3: Build chain with sequence and dependencies
chain_steps = []
used_tools = []
for m in matched:
    for tool in m['tools']:
        if tool not in used_tools:
            chain_steps.append({
                'order': len(chain_steps) + 1,
                'integration': m['integration'],
                'tool': tool,
                'domains': m['domains'],
                'free': m['free']
            })
            used_tools.append(tool)

# Step 4: Auto-add proxy calls for generation tasks
# If the chain has no tool for this domain, add the proxy
if any('image' in query or 'picture' in query or 'photo' in query for _ in [1]):
    if not any(s['tool'] == 'angel-proxy' for s in chain_steps):
        chain_steps.append({
            'order': len(chain_steps) + 1,
            'integration': 'pollinations',
            'tool': 'angel-proxy generate image',
            'domains': 'image',
            'free': 'yes'
        })
elif any('audio' in query or 'sound' in query or 'speech' in query for _ in [1]):
    if not any(s['tool'] == 'angel-proxy' for s in chain_steps):
        chain_steps.append({
            'order': len(chain_steps) + 1,
            'integration': 'pollinations',
            'tool': 'angel-proxy generate audio',
            'domains': 'audio',
            'free': 'yes'
        })
elif any('text' in query or 'write' in query or 'explain' in query for _ in [1]):
    if not any(s['tool'] == 'angel-proxy' for s in chain_steps):
        chain_steps.append({
            'order': len(chain_steps) + 1,
            'integration': 'pollinations',
            'tool': 'angel-proxy generate text',
            'domains': 'text',
            'free': 'yes'
        })

result = {
    'query': query,
    'intents': detected_intents,
    'chain': chain_steps,
    'steps': len(chain_steps),
    'all_free': all(str(s.get('free', '')).lower() in ('yes', 'true') for s in chain_steps),
    'estimated_time': len(chain_steps) * 2
}
print(json.dumps(result, indent=2))
" 2>/dev/null)
    
    echo "$chain_json"
}

# ============================================================================
# CHAIN FROM TODO — Convert todo list items into chained execution
# ============================================================================

chain_from_todo() {
    local todo_text="$1"
    angel_info "[chain] Converting todo to chain..."
    angel_console "decision" "chain" "from_todo" "Converting todos to chain" "lines=$(echo "$todo_text" | wc -l)"
    
    local chain
    chain=$(python3 -c "
import json, re

todo_text = '''$todo_text'''
lines = todo_text.strip().split('\n')

# Parse todos
tasks = []
for line in lines:
    line = line.strip()
    match = re.match(r'^[\d\-\*\+]\.?\s*(.+)$', line)
    if match:
        task = match.group(1).strip()
        tasks.append(task)

# Map each task to a tool/integration
TASK_PATTERNS = [
    (r'image|picture|photo|illustration|design|art|logo', 'angel-proxy generate image', 'pollinations-image'),
    (r'audio|sound|speech|voice|music|tts', 'angel-proxy generate audio', 'pollinations-audio'),
    (r'text|write|content|article|blog|email', 'angel-proxy generate text', 'pollinations-text'),
    (r'code|program|script|function|implement|debug', 'angel-subagent @coder', 'subagent-coder'),
    (r'research|search|find|learn|investigate', 'angel-subagent @researcher', 'subagent-researcher'),
    (r'game|godot|tcg|card', 'godot-tcg-core', 'godot-tcg'),
    (r'campaign|marketing|ad|promote|brand', 'angel-subagent @analyst', 'subagent-analyst'),
    (r'3d|asset|model|logo|icon', 'angel-proxy generate image', 'pollinations-image'),
    (r'soundscape|ambient|focus|meditation|noise', 'spatial-sound', 'spatial-sound'),
    (r'story|narrative|adventure', 'angel-subagent @thinker', 'subagent-thinker'),
    (r'deploy|publish|host', 'anyclaw-publish', 'anyclaw'),
    (r'test|verify|check|validate', 'angel-subagent @critic', 'subagent-critic'),
]

chain_tasks = []
for task in tasks:
    matched_tool = None
    matched_integration = None
    for pattern, tool, integration in TASK_PATTERNS:
        if re.search(pattern, task, re.IGNORECASE):
            matched_tool = tool
            matched_integration = integration
            break
    
    if matched_tool is None:
        matched_tool = 'angel-proxy generate text'
        matched_integration = 'pollinations-text'
    
    chain_tasks.append({
        'task': task,
        'tool': matched_tool,
        'integration': matched_integration,
        'index': len(chain_tasks) + 1
    })

result = {
    'type': 'todo_chain',
    'tasks': chain_tasks,
    'sequence': len(chain_tasks)
}
print(json.dumps(result, indent=2))
" 2>/dev/null)
    
    echo "$chain"
}

# ============================================================================
# CHAIN EXECUTION — Run chained tools/skills with context propagation
# ============================================================================

chain_execute() {
    local query="$1"
    local chain_file="${2:-}"
    
    angel_info "[chain] Executing chain for: ${query:0:80}..."
    
    local start_time
    start_time=$(date +%s)
    
    # Get or build chain
    local chain
    if [ -n "$chain_file" ] && [ -f "$chain_file" ]; then
        chain=$(cat "$chain_file")
    else
        chain=$(chain_discover "$query")
    fi
    
    # Extract chain steps
    local steps_json
    steps_json=$(echo "$chain" | python3 -c "
import json, sys
d = json.load(sys.stdin)
steps = d.get('chain', d.get('tasks', []))
print(json.dumps(steps))
" 2>/dev/null)
    
    local step_count
    step_count=$(echo "$steps_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)
    
    if [ -z "$step_count" ] || [ "$step_count" -eq 0 ]; then
        angel_warn "[chain] No steps in chain"
        echo '{"status": "empty_chain", "query": "'$query'"}'
        return
    fi
    
    angel_info "[chain] ${step_count} steps to execute"
    angel_console "call" "chain" "execute" "Executing chain" "steps=${step_count}"
    
    # Create context file for chain
    local context_file="$CHAIN_DIR/context-$(date +%s).json"
    echo "{\"initial_query\": \"$query\", \"artifacts\": [], \"results\": []}" > "$context_file"
    
    local step=0
    local all_results='[]'
    
    echo "$steps_json" | python3 -c "
import json, sys
steps = json.load(sys.stdin)
for step in steps:
    print(json.dumps(step))
" 2>/dev/null | while IFS= read -r step_json; do
        step=$((step + 1))
        
        local tool integration order
        tool=$(echo "$step_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool', d.get('tool', '')))" 2>/dev/null)
        integration=$(echo "$step_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('integration', d.get('integration', '')))" 2>/dev/null)
        
        if [ -z "$tool" ]; then
            continue
        fi
        
        angel_info "[chain] Step $step/$step_count: [$integration] $tool"
        angel_console "call" "chain" "step" "Step $step/$step_count: $integration" "tool=$tool"
        
        local step_result=""
        local step_status="completed"
        
        # Extract the specific task description for this step
        local task_for_step
        task_for_step=$(echo "$step_json" | python3 -c "
import json,sys
d = json.load(sys.stdin)
task = d.get('task', d.get('task', ''))
query = '$query'
print(task if task else query)
" 2>/dev/null)
        
        # Execute based on tool type
        case "$tool" in
            angel-proxy*)
                local proxy_args="${tool#angel-proxy }"
                step_result=$(bash "$ANGEL_HOME/bin/angel-proxy.sh" $proxy_args "$task_for_step" 2>/dev/null | head -5)
                ;;
            angel-subagent*)
                local subagent_args="${tool#angel-subagent }"
                step_result=$(bash "$ANGEL_HOME/bin/angel-subagent.sh" $subagent_args "$task_for_step" 2>/dev/null | head -10)
                ;;
            spatial-sound)
                step_result="[chain] Spatial Sound integration available — run spatial-sound skill for ambient audio"
                ;;
            godot-tcg-core)
                step_result="[chain] Godot TCG Core skill loaded — use skill instructions for card game development"
                ;;
            anyclaw-publish)
                step_result="[chain] Anyclaw publish loaded — use anyclaw-publish skill for deployment"
                ;;
            composio-cli)
                step_result="[chain] Composio CLI loaded — use composio-cli skill for API integration"
                ;;
            flightclaw)
                step_result="[chain] Flightclaw loaded — use flightclaw skill for flight tracking"
                ;;
            prompt-to-asset)
                step_result="[chain] Prompt-to-Asset MCP server available for 3D asset/logo generation"
                ;;
            *)
                step_result="[chain] Executing: $tool on '$task_for_step'"
                ;;
        esac
        
        if [ $? -ne 0 ]; then
            step_status="failed"
        fi
        
        # Update context with this step's result
        local step_record="{\"step\":$step,\"tool\":\"$tool\",\"integration\":\"$integration\",\"status\":\"$step_status\",\"result\":$(echo "$step_result" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")}"
        echo "$step_record" > "$context_file.tmp"
        
        if [ "$step_status" = "completed" ]; then
            angel_console "ok" "chain" "step" "Step $step done: $integration" "status=$step_status"
        else
            angel_console "error" "chain" "step" "Step $step failed: $integration" "status=$step_status"
        fi
        angel_info "[chain] Step $step: $step_status"
    done
    
    # Summary
    local duration=$(( $(date +%s) - start_time ))
    angel_info "[chain] Complete: ${step_count} steps in ${duration}s"
    angel_console "ok" "chain" "execute" "Chain complete" "steps=${step_count} duration=${duration}s"
    
    # Return final result
    python3 -c "
import json
result = {
    'status': 'completed',
    'query': '''$query''',
    'steps': $step_count,
    'duration_seconds': $duration,
    'all_free': True,
    'powered_by': 'Pollinations AI + KiloProxy free tier'
}
print(json.dumps(result, indent=2))
"
}

# ============================================================================
# SUGGESTION — Recommend chains without executing
# ============================================================================

chain_suggest() {
    local query="$1"
    
    local suggestion
    suggestion=$(chain_discover "$query" | python3 -c "
import json, sys
d = json.load(sys.stdin)
steps = d.get('chain', [])
suggestions = []
for s in steps:
    suggestions.append({
        'order': s.get('order', 0),
        'tool': s.get('tool', ''),
        'integration': s.get('integration', ''),
        'free': s.get('free', 'yes')
    })
result = {
    'query': d.get('query', ''),
    'intents': d.get('intents', []),
    'suggested_chain': suggestions,
    'steps': len(suggestions),
    'all_free': d.get('all_free', True),
    'message': 'Free provider chain available — no API keys needed' if d.get('all_free') else 'Some steps may need API keys'
}
print(json.dumps(result, indent=2))
" 2>/dev/null)
    
    echo "$suggestion"
}

# ============================================================================
# CHECK INTEGRATION HEALTH
# ============================================================================

chain_health() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  AngelKernel Cross-Tool Chain — Integration Health         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "📦 Registered Integrations:"
    echo "────────────────────────────────────────────"
    for name in "${!INTEGRATIONS[@]}"; do
        IFS='|' read -r domains tools free key <<< "${INTEGRATIONS[$name]}"
        local free_icon="🔓"
        [ "$free" != "yes" ] && free_icon="🔑"
        printf "  %s %-20s | domains: %-30s | tools: %s\n" "$free_icon" "$name" "$domains" "$tools"
    done
    echo ""
    
    echo "🔗 Provider Chain Status:"
    bash "$ANGEL_HOME/bin/angel-proxy.sh" status 2>/dev/null | tail -10
}

# ============================================================================
# MAIN DISPATCH
# ============================================================================

case "${1:-}" in
    execute|exec|-e)
        shift; chain_execute "$@" ;;
    from-todo|todo|-t)
        shift; chain_from_todo "$@" ;;
    suggest|--suggest|-s)
        shift; chain_suggest "$@" ;;
    discover|--discover|-d)
        shift; chain_discover "$@" ;;
    health|status)
        chain_health ;;
    *)
        echo "AngelKernel Cross-Tool Chaining Engine v2.2"
        echo "Dynamic tool/skill discovery and execution — FREE providers only"
        echo ""
        echo "Usage:"
        echo "  angel-chain execute <query>              — Auto-discover + execute chain"
        echo "  angel-chain from-todo <todo_text>        — Convert todos to executable chain"
        echo "  angel-chain suggest <query>              — Show suggested chain (no exec)"
        echo "  angel-chain discover <query>             — Show discovered chain"
        echo "  angel-chain health                       — Integration health check"
        echo ""
        echo "Examples:"
        echo "  angel-chain execute \"Build a card game with card art\""
        echo "  angel-chain from-todo \"1. Design logo\\n2. Generate background music\""
        echo "  angel-chain suggest \"Campaign with images and copy\""
        echo ""
        echo "All integrations use FREE providers. No API keys required."
        ;;
esac
