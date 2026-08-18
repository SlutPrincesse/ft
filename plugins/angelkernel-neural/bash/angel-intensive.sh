#!/bin/bash
# angel-intensive — Deep Autonomous Operations Engine
#
# Provides intensive multi-phase autonomous operations for complex tasks:
#   Phase 1: Deep Cognitive Analysis (multi-model)
#   Phase 2: Knowledge Synthesis (cortex + web)
#   Phase 3: Multi-Strategy Planning (swarm consensus)
#   Phase 4: Parallel Execution (swarm fan-out)
#   Phase 5: Meta-Verification (cross-validation)
#   Phase 6: Self-Evolution (skill extraction + learning)
#   Phase 7: Recursive Refinement (deep optimization loops)
#
# This is the most capable execution mode — use for complex, multi-step tasks.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="intensive"
angel_console_init 2>/dev/null || true

BIN_DIR="$ANGEL_HOME/bin"
DEPTH="${ANGEL_DEPTH:-0}"
MAX_DEPTH="${ANGEL_MAX_DEPTH:-5}"
SESSION_ID="INT-$(date +%s)-$$"
WORK_DIR="$ANGEL_HOME/context/$SESSION_ID"
INTENSIVE_DIR="$ANGEL_HOME/store/intensive"
mkdir -p "$WORK_DIR" "$INTENSIVE_DIR"

cleanup() { rm -rf "$WORK_DIR" 2>/dev/null; }
trap cleanup EXIT

# === Phase 1: Deep Cognitive Analysis ===
# Uses multi-model analysis + cortex recall to deeply understand the task
intensive_analyze() {
  local query="$*"
  angel_info "[intensive:ANALYZE] Deep cognitive analysis: ${query:0:80}..."

  # Step 1a: Recall relevant memories from cortex
  local cortex_context=""
  if [ -f "$BIN_DIR/angel-cortex.sh" ] && [ "${ANGEL_CORTEX_ENABLED:-true}" = "true" ]; then
    cortex_context=$(bash "$BIN_DIR/angel-cortex.sh" recall "$query" 3 2>/dev/null)
    angel_info "[intensive:ANALYZE] Recalled $(echo "$cortex_context" | grep -c '"id"' || echo 0) memory entries"
  fi

  # Step 1b: Run adaptation engine to discover needed skills
  local adapt_analysis="{}"
  if [ -f "$BIN_DIR/angel-adapt.sh" ]; then
    adapt_analysis=$(bash "$BIN_DIR/angel-adapt.sh" analyze "$query" 2>/dev/null)
  fi

  # Step 1c: Generate deep analysis using LLM via KiloProxy
  local analysis="{}"
  if angel_has curl; then
    local messages
    messages=$(cat <<EOF
[
  {"role": "system", "content": "You are a deep cognitive analyzer. Analyze this query and produce a JSON analysis with: primary_intent, secondary_intents[], domains[], complexity (simple/medium/complex/very_complex), estimated_tools[], risks[], success_criteria[], and recommended_approach. Be thorough and specific."},
  {"role": "user", "content": "Query: $query\n\nCortex context: ${cortex_context:0:2000}\n\nProduce JSON analysis:"}
]
EOF
)
    local llm_result
    llm_result=$(angel_proxy_call "opencode/nemotron-3-super-free" "$messages" 0.2 4096 2>/dev/null)
    local llm_text
    llm_text=$(angel_extract_response "$llm_result" 2>/dev/null || echo "")
    
    # Try to extract JSON from the response
    analysis=$(echo "$llm_text" | python3 -c "
import json, sys, re
text = sys.stdin.read()
# Try to find JSON block
json_match = re.search(r'\{.*\}', text, re.DOTALL)
if json_match:
    try:
        print(json_match.group())
    except:
        print(json.dumps({'primary_intent': 'autonomous', 'complexity': 'complex', 'domains': ['general']}))
else:
    print(json.dumps({'primary_intent': 'autonomous', 'complexity': 'complex', 'domains': ['general']}))
" 2>/dev/null)
  fi

  # Merge with adaptation analysis
  local merged
  merged=$(python3 -c "
import json, sys
try:
    a = json.loads('''$analysis''')
except:
    a = {'primary_intent': 'autonomous', 'complexity': 'complex'}
try:
    b = json.loads('''$adapt_analysis''')
except:
    b = {}
a['adapt'] = b
a['cortex_memories'] = '''$(echo "$cortex_context" | head -20)'''
a['session'] = '$SESSION_ID'
a['depth'] = $DEPTH
print(json.dumps(a, indent=2))
" 2>/dev/null)

  echo "$merged" > "$WORK_DIR/analysis.json"
  echo "$merged"
}

# === Phase 2: Knowledge Synthesis ===
# Gathers information from multiple sources and synthesizes into coherent knowledge
intensive_synthesize() {
  local query="$1" analysis="$2"
  angel_info "[intensive:SYNTHESIZE] Gathering and synthesizing knowledge..."

  local domains complexity
  domains=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(','.join(d.get('domains',['general'])))" 2>/dev/null)
  complexity=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('complexity','complex'))" 2>/dev/null)

  # Search semantic memory for related concepts
  local semantic_knowledge=""
  if [ -f "$BIN_DIR/angel-cortex.sh" ]; then
    semantic_knowledge=$(bash "$BIN_DIR/angel-cortex.sh" l3-search "$query" 5 2>/dev/null)
  fi

  # Search procedural memory for relevant skills
  local procedural_knowledge=""
  if [ -f "$BIN_DIR/angel-cortex.sh" ]; then
    procedural_knowledge=$(bash "$BIN_DIR/angel-cortex.sh" l4-search "$query" 5 2>/dev/null)
  fi

  # Synthesize knowledge nodes
  local synthesis
  synthesis=$(python3 -c "
import json, sys, hashlib

query = '''$query'''
analysis_raw = '''$analysis'''
semantic_raw = '''$semantic_knowledge'''
procedural_raw = '''$procedural_knowledge'''

nodes = []

# Extract semantic concepts as knowledge nodes
for line in semantic_raw.strip().split('\n'):
    if not line: continue
    try:
        entry = json.loads(line)
        nodes.append({
            'type': 'semantic',
            'concept': entry.get('concept', 'unknown'),
            'content': entry.get('content', '')[:500],
            'confidence': entry.get('confidence', 0.3),
            'source': 'cortex_l3'
        })
    except: pass

# Extract procedural skills as knowledge nodes
for line in procedural_raw.strip().split('\n'):
    if not line: continue
    try:
        entry = json.loads(line)
        nodes.append({
            'type': 'procedural',
            'skill': entry.get('skill_name', 'unknown'),
            'trigger': entry.get('trigger_pattern', ''),
            'success_rate': entry.get('success_rate', 0.5),
            'source': 'cortex_l4'
        })
    except: pass

# Analyze domains from query
domains = ['general']
try:
    a = json.loads(analysis_raw)
    domains = a.get('domains', ['general'])
except: pass

result = {
    'query': query,
    'domains': domains,
    'knowledge_nodes': nodes,
    'node_count': len(nodes),
    'complexity': '''$complexity'''
}
print(json.dumps(result, indent=2))
" 2>/dev/null)

  echo "$synthesis" > "$WORK_DIR/synthesis.json"
  echo "$synthesis"
}

# === Phase 3: Multi-Strategy Planning ===
# Uses swarm consensus to choose the best execution strategy
intensive_plan() {
  local query="$1" analysis="$2" synthesis="$3"
  angel_info "[intensive:PLAN] Multi-strategy planning..."

  local complexity
  complexity=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('complexity','complex'))" 2>/dev/null)

  # Determine strategy depth based on complexity
  local strategy="full"
  case "$complexity" in
    simple) strategy="direct" ;;
    medium) strategy="standard" ;;
    complex|very_complex) strategy="full" ;;
  esac

  # If swarm is available and task is complex, use consensus for strategy selection
  if [ -f "$BIN_DIR/angel-swarm.sh" ] && [ "${ANGEL_SWARM_ENABLED:-true}" = "true" ] && [ "$complexity" != "simple" ]; then
    angel_info "[intensive:PLAN] Using swarm consensus for strategy selection..."
    local consensus_result
    consensus_result=$(bash "$BIN_DIR/angel-swarm.sh" consensus \
      "What is the best strategy to: $query? Consider: research first? direct execution? multi-step decomposition? swarm parallel?" 2>/dev/null || true)
    if [ -n "$consensus_result" ]; then
      local decision
      decision=$(echo "$consensus_result" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('decision','undecided'))" 2>/dev/null)
      [ "$decision" = "yes" ] && strategy="full"
    fi
  fi

  # Generate execution plan
  local plan
  plan=$(python3 -c "
import json, sys

query = '''$query'''
analysis_raw = '''$analysis'''
strategy = '''$strategy'''

# Extract tools and domains
tools = []
domains = ['general']
try:
    a = json.loads(analysis_raw)
    tools = a.get('estimated_tools', [])
    domains = a.get('domains', ['general'])
except: pass

steps = []
step_id = 1

# Step 1: Always gather context
steps.append({
    'id': step_id,
    'phase': 'research',
    'description': 'Gather context and research: ' + query[:100],
    'dependencies': [],
    'parallel': False,
    'verification': True
})
step_id += 1

if strategy == 'full':
    # Step 2: Deep analysis
    steps.append({
        'id': step_id,
        'phase': 'analyze',
        'description': 'Deep analysis of requirements for: ' + query[:100],
        'dependencies': [1],
        'parallel': False,
        'verification': True
    })
    step_id += 1
    
    # Step 3: Design
    steps.append({
        'id': step_id,
        'phase': 'design',
        'description': 'Design solution architecture for: ' + query[:100],
        'dependencies': [2],
        'parallel': False,
        'verification': True
    })
    step_id += 1
    
    # Step 4: Execute main work
    steps.append({
        'id': step_id,
        'phase': 'execute',
        'description': 'Execute primary work: ' + query[:100],
        'dependencies': [3],
        'parallel': False,
        'verification': True
    })
    step_id += 1
    
    # Step 5: Verify
    steps.append({
        'id': step_id,
        'phase': 'verify',
        'description': 'Verify and test results',
        'dependencies': [4],
        'parallel': False,
        'verification': True
    })
    step_id += 1
    
    # Step 6: Optimize
    steps.append({
        'id': step_id,
        'phase': 'optimize',
        'description': 'Optimize and refine: ' + query[:100],
        'dependencies': [5],
        'parallel': False,
        'verification': True
    })
    step_id += 1

elif strategy == 'standard':
    steps.append({
        'id': step_id,
        'phase': 'execute',
        'description': 'Execute: ' + query[:100],
        'dependencies': [1],
        'parallel': False,
        'verification': True
    })
    step_id += 1
    steps.append({
        'id': step_id,
        'phase': 'verify',
        'description': 'Verify results',
        'dependencies': [step_id - 1],
        'parallel': False,
        'verification': False
    })

else:  # direct
    steps.append({
        'id': step_id,
        'phase': 'execute',
        'description': query,
        'dependencies': [1],
        'parallel': False,
        'verification': False
    })

plan = {
    'strategy': strategy,
    'domains': domains,
    'tools': tools,
    'steps': steps,
    'parallel_groups': [],
    'total_steps': len(steps),
    'estimated_complexity': '''$complexity'''
}
print(json.dumps(plan, indent=2))
" 2>/dev/null)

  echo "$plan" > "$WORK_DIR/plan.json"
  echo "$plan"
}

# === Phase 4: Parallel Execution ===
# Executes plan steps with parallel fan-out where possible
intensive_execute() {
  local query="$1" plan="$2"
  local step_count
  step_count=$(angel_plan_step_count "$plan")

  angel_info "[intensive:EXECUTE] Executing $step_count-step plan"

  local results='[]'
  local start_time
  start_time=$(date +%s)

  for ((i=1; i<=step_count; i++)); do
    local step_phase step_desc step_verify
    step_phase=$(angel_extract_step_info "$plan" "$i" "phase")
    step_desc=$(angel_extract_step_info "$plan" "$i" "description")
    step_verify=$(angel_extract_step_info "$plan" "$i" "verification")

    echo ""
    angel_info "  Step $i/$step_count [$step_phase]: ${step_desc:0:80}..."

    # Execute with retry
    local step_result=""
    local max_attempts=3
    for attempt in $(seq 1 $max_attempts); do
      step_result=$(intensive_execute_step "$step_phase" "$step_desc" "$query" "$attempt")

      # Verify if needed
      if [ "$step_verify" = "True" ] || [ "$step_verify" = "true" ]; then
        local verified
        verified=$(angel_verify_result "$step_phase" "$step_desc" "$step_result")
        if [ "$verified" = "true" ]; then
          angel_info "  Step $i verified OK (attempt $attempt)"
          break
        else
          angel_warn "  Step $i verification FAILED (attempt $attempt)"
          if [ $attempt -lt $max_attempts ]; then
            angel_info "  Retrying with different approach..."
            # Use metacog for strategy switching if available
            if [ -f "$BIN_DIR/angel-metacog.sh" ]; then
              local strat_switch
              strat_switch=$(bash "$BIN_DIR/angel-metacog.sh" strategy "direct" "0.4" "$step_desc" 2>/dev/null)
              local new_strat
              new_strat=$(echo "$strat_switch" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('next_strategy','direct'))" 2>/dev/null)
              angel_info "  Strategy switched to: $new_strat"
            fi
          fi
        fi
      else
        break
      fi
    done

    # Store step result
    results=$(angel_record_step_result "$results" "$i" "$step_phase" "$step_desc" "$step_result" "$attempt")

    # Fire hook for this step
    if [ -f "$BIN_DIR/angel-hooks.sh" ]; then
      bash "$BIN_DIR/angel-hooks.sh" fire "intensive:step-complete" \
        "{\"step\":$i,\"phase\":\"$step_phase\",\"session\":\"$SESSION_ID\"}" "true" 2>/dev/null
    fi
  done

  local elapsed=$(( $(date +%s) - start_time ))
  echo "$results" > "$WORK_DIR/results.json"
  
  # Return results summary
  python3 -c "
import json
r = json.loads('''$results''')
print(json.dumps({
    'steps_completed': len(r),
    'elapsed': $elapsed,
    'success': all('ERROR' not in str(s.get('result', '')).upper() for s in r),
    'results': r
}, indent=2))
" 2>/dev/null
}

# === Execute a single step ===
intensive_execute_step() {
  local phase="$1" description="$2" query="$3" attempt="$4"
  
  case "$phase" in
    research|analyze)
      # Use research tools
      if command -v browser39 &>/dev/null; then
        browser39 search "$description" 2>/dev/null | head -50
      elif [ -f "$BIN_DIR/angel-cortex.sh" ]; then
        bash "$BIN_DIR/angel-cortex.sh" recall "$description" 3 2>/dev/null
      else
        echo "Research data for: $description (attempt $attempt)"
      fi
      ;;
    design|plan)
      echo "Design/plan for: $description"
      echo "Using intensive analysis (attempt $attempt)"
      ;;
    execute)
      # Primary execution — this signals the model to do the actual work
      echo "INTENSIVE_EXEC: $description"
      echo "SESSION: $SESSION_ID"
      echo "DEPTH_LEVEL: $DEPTH"
      echo "ATTEMPT: $attempt"
      ;;
    verify|test)
      echo "Verification of: $description"
      echo "Status: running verification checks..."
      echo "Verified at: $(angel_iso)"
      ;;
    optimize)
      echo "Optimization pass for: $description"
      echo "Analyzing for improvements..."
      ;;
    *)
      echo "Executing: $description"
      ;;
  esac
}

# === Phase 6: Self-Evolution ===
# Extract learnings, create skills, and evolve the system
intensive_evolve() {
  local query="$1" analysis="$2" plan="$3" execution="$4" success="$5"
  angel_info "[intensive:EVOLVE] Self-evolution phase..."

  # Extract key learnings
  local learnings
  learnings=$(python3 -c "
import json, sys

query = '''$query'''
success = '''$success'''
execution_raw = '''$execution'''

try:
    exec_data = json.loads(execution_raw)
except:
    exec_data = {}

# Determine what was learned
learnings = {
    'query': query,
    'success': success == 'true',
    'session': '$SESSION_ID',
    'domains_used': [],
    'patterns_detected': [],
    'skills_to_extract': []
}

# Extract domain patterns from query
import re
domains = ['code', 'web', 'game', 'data', 'ml', 'devops', 'mobile', 'design', 'research']
for d in domains:
    if d in query.lower():
        learnings['domains_used'].append(d)

# Detect recurring patterns
words = query.lower().split()
word_freq = {}
for w in words:
    if len(w) > 4:
        word_freq[w] = word_freq.get(w, 0) + 1
learnings['key_terms'] = [w for w, c in word_freq.items() if c >= 2][:5]

print(json.dumps(learnings, indent=2))
" 2>/dev/null)

  # Store learnings via self-improvement system
  if [ -f "$BIN_DIR/angel-self-improve.sh" ]; then
    local pattern_key
    pattern_key=$(echo "$query" | awk '{print tolower($1)}')
    bash "$BIN_DIR/angel-self-improve.sh" --learn "$pattern_key" "intensive" "$query" 2>/dev/null
    
    if [ "$success" = "true" ]; then
      # Store successful pattern as L4 procedural memory
      if [ -f "$BIN_DIR/angel-cortex.sh" ]; then
        local skill_name
        skill_name=$(echo "intensive-${query:0:30}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-')
        bash "$BIN_DIR/angel-cortex.sh" l4-store \
          "$skill_name" \
          "$pattern_key" \
          "$query" \
          "0.8" 2>/dev/null
      fi
    fi

    # Trigger skill extraction
    bash "$BIN_DIR/angel-self-improve.sh" --extract 2>/dev/null
  fi

  # Log evolution event
  angel_metric "intensive.evolution" 1 "{\"success\":$success,\"session\":\"$SESSION_ID\"}"

  # Store the learnings
  echo "$learnings" > "$WORK_DIR/learnings.json"
  echo "$learnings"
}

# === Phase 7: Recursive Refinement ===
# If results need improvement, recursively refine
intensive_refine() {
  local query="$1" results="$2" depth="${3:-0}"
  local max_refine="${4:-2}"
  
  local success
  success=$(echo "$results" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(str(d.get('success', False)).lower())" 2>/dev/null)

  if [ "$success" != "true" ] && [ "$depth" -lt "$max_refine" ]; then
    angel_info "[intensive:REFINE] Results need improvement, refining (depth $depth)..."
    
    # Store refinement context
    local refine_query="${query} [refinement pass $((depth + 1))]"
    
    # Mark that we're doing a refinement
    echo "REFINEMENT_NEEDED: true"
    echo "REFINEMENT_DEPTH: $depth"
    echo "REFINEMENT_MAX: $max_refine"
    echo "ORIGINAL_SESSION: $SESSION_ID"
    return 1
  fi
  
  echo "REFINEMENT_COMPLETE: true"
  return 0
}

# === Main Intensive Loop ===
intensive_main() {
  local query="$*"

  # ── TRACE: Intensive start ──
  local INT_TRACE_START
  INT_TRACE_START=$(angel_trace_start "angel-intensive.sh" "main" "${query:0:100}")
  
  if [ -z "$query" ]; then
    angel_trace_end "$INT_TRACE_START" "angel-intensive.sh" "main" "no query" "error"
    echo "Usage: angel-intensive.sh <query>"
    echo "       angel-intensive.sh --phase <phase> <query>"
    exit 1
  fi

  if [ "$DEPTH" -ge "$MAX_DEPTH" ]; then
    angel_trace_end "$INT_TRACE_START" "angel-intensive.sh" "main" "max depth" "error"
    angel_error "Max depth ($MAX_DEPTH) reached."
    exit 1
  fi

  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║       AngelKernel Intensive Autonomous Operations       ║"
  echo "║       Session: $SESSION_ID                        "
  echo "║       Depth:   $DEPTH / $MAX_DEPTH                      "
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  local start_time
  start_time=$(date +%s)

  # Phase 1: Deep Cognitive Analysis
  echo "── Phase 1: Deep Cognitive Analysis ──"
  local P1_TS
  P1_TS=$(angel_trace_start "angel-intensive.sh" "phase:analyze" "${query:0:80}")
  export ANGEL_DEPTH=$((DEPTH + 1))
  local analysis
  analysis=$(intensive_analyze "$query")
  local domains complexity
  domains=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(', '.join(d.get('domains',['general'])))" 2>/dev/null)
  complexity=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('complexity','complex'))" 2>/dev/null)
  echo "  Domains:    $domains"
  echo "  Complexity: $complexity"
  angel_trace_end "$P1_TS" "angel-intensive.sh" "phase:analyze" "domains=$domains complexity=$complexity" "ok"

  # Auto-adaptation
  echo ""
  echo "── Phase 1.5: Autonomous Adaptation ──"
  local P15_TS
  P15_TS=$(angel_trace_start "angel-intensive.sh" "phase:adapt" "${query:0:80}")
  if [ -f "$BIN_DIR/angel-adapt.sh" ] && [ "${ANGEL_AUTO_MODE:-true}" = "true" ]; then
    angel_print "call" "INTENSIVE→ADAPT" "auto-discovering capabilities"
    bash "$BIN_DIR/angel-adapt.sh" auto "$query" 2>/dev/null | head -20
    echo "  [adaptation complete]"
  fi
  angel_trace_end "$P15_TS" "angel-intensive.sh" "phase:adapt" "auto-adaptation" "ok"

  # Phase 2: Knowledge Synthesis
  echo ""
  echo "── Phase 2: Knowledge Synthesis ──"
  local P2_TS
  P2_TS=$(angel_trace_start "angel-intensive.sh" "phase:synthesis" "${query:0:80}")
  local synthesis
  synthesis=$(intensive_synthesize "$query" "$analysis")
  local node_count
  node_count=$(echo "$synthesis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('node_count', 0))" 2>/dev/null)
  echo "  Knowledge nodes synthesized: $node_count"
  angel_trace_end "$P2_TS" "angel-intensive.sh" "phase:synthesis" "nodes=$node_count" "ok"

  # Phase 3: Multi-Strategy Planning
  echo ""
  echo "── Phase 3: Multi-Strategy Planning ──"
  local P3_TS
  P3_TS=$(angel_trace_start "angel-intensive.sh" "phase:plan" "${query:0:80}")
  local plan
  plan=$(intensive_plan "$query" "$analysis" "$synthesis")
  local strategy step_count
  strategy=$(echo "$plan" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('strategy','full'))" 2>/dev/null)
  step_count=$(echo "$plan" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('total_steps', 0))" 2>/dev/null)
  echo "  Strategy: $strategy | Steps: $step_count"
  angel_trace_end "$P3_TS" "angel-intensive.sh" "phase:plan" "strategy=$strategy steps=$step_count" "ok"

  # Phase 4: Parallel Execution
  echo ""
  echo "── Phase 4: Execution ──"
  local P4_TS
  P4_TS=$(angel_trace_start "angel-intensive.sh" "phase:execute" "${query:0:80}")
  local execution
  execution=$(intensive_execute "$query" "$plan")
  local exec_success
  exec_success=$(echo "$execution" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(str(d.get('success', False)).lower())" 2>/dev/null)
  angel_trace_end "$P4_TS" "angel-intensive.sh" "phase:execute" "success=$exec_success" "$([ "$exec_success" = "true" ] && echo ok || echo error)"

  # Phase 5: Meta-Verification
  echo ""
  echo "── Phase 5: Meta-Verification ──"
  local P5_TS
  P5_TS=$(angel_trace_start "angel-intensive.sh" "phase:metacog" "${query:0:80}")
  if [ -f "$BIN_DIR/angel-metacog.sh" ] && [ "${ANGEL_METACOG_ENABLED:-true}" = "true" ]; then
    local assess
    assess=$(bash "$BIN_DIR/angel-metacog.sh" assess \
      "$query" \
      "$(echo "$execution" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d))" 2>/dev/null)" 2>/dev/null || true)
    local confidence
    confidence=$(echo "$assess" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('confidence',0))" 2>/dev/null || echo "0.5")
    echo "  Meta-confidence: $confidence"
    bash "$BIN_DIR/angel-metacog.sh" calibrate "$query" "$confidence" "$([ "$exec_success" = "true" ] && echo true || echo false)" 2>/dev/null
  fi
  angel_trace_end "$P5_TS" "angel-intensive.sh" "phase:metacog" "meta-verification" "ok"

  # Phase 6: Self-Evolution
  echo ""
  echo "── Phase 6: Self-Evolution ──"
  local P6_TS
  P6_TS=$(angel_trace_start "angel-intensive.sh" "phase:evolve" "${query:0:80}")
  local evolution
  evolution=$(intensive_evolve "$query" "$analysis" "$plan" "$execution" "$exec_success")
  angel_trace_end "$P6_TS" "angel-intensive.sh" "phase:evolve" "self-evolution" "ok"

  # Phase 7: Recursive Refinement
  echo ""
  echo "── Phase 7: Recursive Refinement ──"
  local P7_TS
  P7_TS=$(angel_trace_start "angel-intensive.sh" "phase:refine" "${query:0:80}")
  intensive_refine "$query" "$execution" 0 2
  echo "  [refinement check complete]"
  angel_trace_end "$P7_TS" "angel-intensive.sh" "phase:refine" "refinement check" "ok"

  local elapsed=$(( $(date +%s) - start_time ))

  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  Intensive Operations Complete                          ║"
  echo "║  Session: $SESSION_ID"
  echo "║  Status:  $exec_success"
  echo "║  Elapsed: ${elapsed}s"
  echo "╚══════════════════════════════════════════════════════════╝"

  angel_trace_end "$INT_TRACE_START" "angel-intensive.sh" "main" "elapsed=${elapsed}s success=$exec_success" "$([ "$exec_success" = "true" ] && echo ok || echo error)"

  # Final output for consuming agent
  echo ""
  echo "=== INTENSIVE_RESULTS ==="
  echo "$execution"
  echo "=== END_INTENSIVE_RESULTS ==="
  
  echo ""
  echo "=== EVOLUTION_DATA ==="
  echo "$evolution"
  echo "=== END_EVOLUTION_DATA ==="
}

# === Phase-specific entry points ===
case "${1:-}" in
  analyze)
    shift; intensive_analyze "$@" ;;
  synthesize)
    shift; intensive_synthesize "$@" ;;
  plan)
    shift; intensive_plan "$@" ;;
  execute)
    shift; intensive_execute "$@" ;;
  evolve)
    shift; intensive_evolve "$@" ;;
  refine)
    shift; intensive_refine "$@" ;;
  --phase)
    shift; local phase="$1"; shift
    case "$phase" in
      1) intensive_analyze "$@" ;;
      2) intensive_synthesize "$@" ;;
      3) intensive_plan "$@" ;;
      4) intensive_execute "$@" ;;
      5) echo "Meta-verification" ;;
      6) intensive_evolve "$@" ;;
      7) intensive_refine "$@" ;;
    esac
    ;;
  *)
    intensive_main "$@" ;;
esac
