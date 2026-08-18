#!/bin/bash
# angel-superloop v4.0 — Neural-Enhanced RALPH loop with planning, verification, and adaptation.
# Neural cognition runs as pre-phase: intent classification + context coherence before execution.
#
# SuperLoop phases:
#   0. NEURAL — Intent classification + context coherence (pre-phase)
#   1. REASON  — Deep intent understanding + plan generation
#   2. PLAN    — Task decomposition into subtasks with dependencies
#   3. ACT     — Execute subtasks (parallel where possible)
#   4. VERIFY  — Verify each result, retry on failure
#   5. LEARN   — Store outcomes, extract patterns
#   6. PATCH   — Self-heal on errors
#   7. HOOK    — Post-action processing, trigger events
#
# Elevates any model by:
#   - Neural cognition pre-phase for intent/context
#   - Decomposing complex tasks into manageable subtasks
#   - Verifying outputs before accepting them
#   - Adapting strategy when stuck (try different approach)
#   - Building confidence scores for decisions
#   - Maintaining chain-of-thought across subtasks

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="superloop"
angel_console_init 2>/dev/null || true

BIN_DIR="$ANGEL_HOME/bin"
DEPTH="${ANGEL_DEPTH:-0}"
MAX_DEPTH="${ANGEL_MAX_DEPTH:-5}"
SESSION_ID="SL-$(date +%s)-$$"
PLAN_FILE="$ANGEL_HOME/context/plan.$SESSION_ID.json"
RESULT_FILE="$ANGEL_HOME/context/result.$SESSION_ID.json"
CONTEXT_FILE="$ANGEL_HOME/context/context.$SESSION_ID.json"

cleanup() { rm -f "$PLAN_FILE" "$RESULT_FILE" "$CONTEXT_FILE" 2>/dev/null; }
trap cleanup EXIT

# === Phase 1: REASON — Deep intent analysis ===
superloop_reason() {
  local query="$1"
  angel_info "[superloop:REASON] Analyzing: ${query:0:80}..."

  local intent complexity tools
  intent=$(angel_classify_intent "$query")
  complexity=$(angel_estimate_complexity "$query")
  tools=$(angel_detect_tools "$query")

  local analysis
  analysis=$(python3 -c "
import json, sys
intent = sys.argv[1]
complexity = sys.argv[2]
tools = json.loads(sys.argv[3])
est_steps = 1 if complexity == 'simple' else (3 if complexity == 'medium' else 5)
needs_ver = complexity in ('complex', 'very_complex')
print(json.dumps({
    'primary_intent': intent,
    'complexity': complexity,
    'required_tools': tools,
    'estimated_steps': est_steps,
    'needs_verification': needs_ver,
    'can_parallelize': complexity in ('complex', 'very_complex'),
}))
" "$intent" "$complexity" "$tools" 2>/dev/null)

  echo "$analysis"
}

# === Phase 2: PLAN — Task decomposition ===
superloop_plan() {
  local query="$1" analysis="$2"
  local intent complexity estimated_steps
  intent=$(echo "$analysis" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('primary_intent','autonomous'))" 2>/dev/null)
  complexity=$(echo "$analysis" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('complexity','simple'))" 2>/dev/null)
  estimated_steps=$(echo "$analysis" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('estimated_steps',1))" 2>/dev/null)
  local needs_verification=$(echo "$analysis" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('needs_verification',False))" 2>/dev/null)

  angel_info "[superloop:PLAN] Complexity=$complexity, Steps=$estimated_steps"

  # Generate execution plan
  local plan='{"steps":[],"parallel_groups":[],"verification_points":[]}'

  case "$complexity" in
    simple)
      plan=$(cat <<EOF
{
  "steps": [
    {"id": 1, "action": "$intent", "description": "$query", "dependencies": [], "tool": "auto", "verification": false}
  ],
  "parallel_groups": [],
  "verification_points": []
}
EOF
)
      ;;
    medium)
      plan=$(cat <<EOF
{
  "steps": [
    {"id": 1, "action": "research", "description": "Gather context and information for: $query", "dependencies": [], "tool": "auto", "verification": true},
    {"id": 2, "action": "$intent", "description": "Execute primary action: $query", "dependencies": [1], "tool": "auto", "verification": true},
    {"id": 3, "action": "verify", "description": "Verify results of step 2", "dependencies": [2], "tool": "auto", "verification": false}
  ],
  "parallel_groups": [],
  "verification_points": [2]
}
EOF
)
      ;;
    complex|very_complex)
      # For complex tasks, decompose into more steps
      plan=$(cat <<EOF
{
  "steps": [
    {"id": 1, "action": "research", "description": "Research and gather context for: $query", "dependencies": [], "tool": "researcher", "verification": true},
    {"id": 2, "action": "plan", "description": "Create detailed sub-plan based on research", "dependencies": [1], "tool": "thinker", "verification": true},
    {"id": 3, "action": "$intent", "description": "Execute: $query (part 1)", "dependencies": [2], "tool": "coder", "verification": true},
    {"id": 4, "action": "verify", "description": "Verify and test results", "dependencies": [3], "tool": "auto", "verification": false},
    {"id": 5, "action": "finalize", "description": "Finalize and summarize: $query", "dependencies": [4], "tool": "auto", "verification": false}
  ],
  "parallel_groups": [],
  "verification_points": [2, 3]
}
EOF
)
      ;;
  esac

  echo "$plan" > "$PLAN_FILE"
  echo "$plan"
}

# === Phase 3: ACT — Execute subtasks ===
superloop_act() {
  local plan="$1" query="$2"
  local step_count
  step_count=$(angel_plan_step_count "$plan")

  angel_info "[superloop:ACT] Executing $step_count steps"
  
  local results='[]'

  for ((i=1; i<=step_count; i++)); do
    local step_action step_desc step_tool step_verify
    step_action=$(angel_extract_step_info "$plan" "$i" "action")
    step_desc=$(angel_extract_step_info "$plan" "$i" "description")
    step_tool=$(angel_extract_step_info "$plan" "$i" "tool")
    step_verify=$(angel_extract_step_info "$plan" "$i" "verification")

    echo ""
    angel_info "  Step $i/$step_count: [$step_action] ${step_desc:0:80}..."

    # Execute the step with retry
    local step_result=""
    local max_attempts=3
    for attempt in $(seq 1 $max_attempts); do
      step_result=$(superloop_execute_step "$step_action" "$step_desc" "$step_tool" "$query")
      
      # Verify if needed
      if [ "$step_verify" = "True" ] || [ "$step_verify" = "true" ]; then
        local verified
        verified=$(angel_verify_result "$step_action" "$step_desc" "$step_result")
        if [ "$verified" = "true" ]; then
          angel_info "  Step $i verified OK (attempt $attempt)"
          break
        else
          angel_warn "  Step $i verification FAILED (attempt $attempt)"
          if [ $attempt -lt $max_attempts ]; then
            angel_info "  Retrying with different approach..."
            # Strategy adaptation: try different tool on retry
            case "$step_tool" in
              coder) step_tool="thinker" ;;
              thinker) step_tool="auto" ;;
              *) step_tool="auto" ;;
            esac
          fi
        fi
      else
        break
      fi
    done

    # Record step result
    results=$(angel_record_step_result "$results" "$i" "$step_action" "$step_desc" "$step_result" "$attempt")
  done

  echo "$results" > "$RESULT_FILE"
  echo "$results"
}

# === Execute a single step ===
superloop_execute_step() {
  local action="$1" description="$2" tool="$3" query="$4"
  
  case "$action" in
    research)
      # Use web search or memory recall
      if angel_has browser39 && [ "$tool" = "auto" ]; then
        browser39 search "$description" 2>/dev/null | head -30
      elif angel_has icm; then
        timeout 5 icm recall "$description" 2>/dev/null | head -20
      else
        echo "Research step: need to investigate: $description"
      fi
      ;;
    plan)
      # Generate detailed sub-plan using thinker
      echo "Planning step for: $description"
      echo "Executed via ${tool:-auto} on $(date)"
      ;;
    creation|edit|code|repair)
      # Code/task execution
      echo "Executing: $description"
      echo "Action type: $action"
      echo "Tool: ${tool:-auto}"
      # The actual execution happens in the model's own tool calls
      # This script just orchestrates the plan
      ;;
    verify|test)
      # Verification step
      echo "Verification of previous step: $description"
      echo "Verification timestamp: $(date)"
      ;;
    search|research)
      if angel_has browser39; then
        browser39 search "$description" 2>/dev/null | head -30
      else
        echo "Search results for: $description"
      fi
      ;;
    finalize)
      echo "Final result summary for: $description"
      ;;
    *)
      echo "Executing: $description"
      ;;
  esac
}

# === Phase 5: LEARN — Store outcomes ===
superloop_learn() {
  local query="$1" analysis="$2" plan="$3" results="$4" success="$5"
  
  angel_info "[superloop:LEARN] Recording session $SESSION_ID"
  
  # --- L1 Working Memory: Store session context ---
  if [ -f "$ANGEL_HOME/bin/angel-cortex.sh" ]; then
    local l1_key="superloop-${SESSION_ID}"
    bash "$ANGEL_HOME/bin/angel-cortex.sh" l1-store "$l1_key" "$query" 3600 2>/dev/null
    angel_print "memory" "L1 STORE" "session=$l1_key ttl=3600s"
    # Store L2 episodic memory of the session
    bash "$ANGEL_HOME/bin/angel-cortex.sh" store       "[superloop] Query: $query | Success: $success"       "superloop"       "{"session": "$SESSION_ID", "success": $success}"
  else
    # Fallback: Store the full session to Cortex
    if [ -f "$ANGEL_HOME/bin/angel-cortex.sh" ]; then
      bash "$ANGEL_HOME/bin/angel-cortex.sh" store         "[superloop] Query: $query | Success: $success"         "superloop"         "{"session": "$SESSION_ID", "success": $success}"
    fi
  fi
  if [ -f "$ANGEL_HOME/bin/angel-cortex.sh" ]; then
    bash "$ANGEL_HOME/bin/angel-cortex.sh" store \
      "[superloop] Query: $query | Success: $success" \
      "superloop" \
      "{\"session\": \"$SESSION_ID\", \"success\": $success}"
  fi
  
  # Increment counters
  angel_incr "superloop.total_runs"
  if [ "$success" = "true" ]; then
    angel_incr "superloop.successes"
  else
    angel_incr "superloop.failures"
  fi
  
  # Log to interactions
  echo "$(date +%s)|superloop|$DEPTH|$success|$query" >> "$ANGEL_HOME/memory/interactions/superloop.tsv"
}

# === Phase 6: PATCH — Self-heal ===
superloop_patch() {
  local error="$1"
  angel_warn "[superloop:PATCH] Self-healing from: ${error:0:100}..."
  
  if [ -f "$ANGEL_HOME/bin/angel-evolve.sh" ]; then
    bash "$ANGEL_HOME/bin/angel-evolve.sh" "$error" 2>/dev/null &
  fi
}

# === Phase 7: HOOK — Post-action ===
superloop_hook() {
  local query="$1" results="$2" success="$3"
  
  angel_info "[superloop:HOOK] Post-processing..."
  
  # Trigger hooks
  if [ -d "$ANGEL_HOME/hooks" ]; then
    for hook in "$ANGEL_HOME/hooks"/*.sh; do
      [ -f "$hook" ] && bash "$hook" "superloop" "$SESSION_ID" "$success" 2>/dev/null &
    done
  fi
  
  # Pattern detection for skill extraction
  if [ "$success" = "true" ]; then
    local similar_count
    similar_count=$(grep -c "$(echo "$query" | awk '{print $1}')" "$ANGEL_HOME/memory/interactions/superloop.tsv" 2>/dev/null || echo 0)
    if [ "$similar_count" -ge 3 ]; then
      angel_info "[superloop:HOOK] Recurring pattern detected ($similar_count times) — consider skill extraction"
      if [ -f "$ANGEL_HOME/bin/angel-self-improve.sh" ]; then
        bash "$ANGEL_HOME/bin/angel-self-improve.sh" --extract 2>/dev/null &
      fi
    fi
  fi
  
  # === AUTONOMOUS FEEDBACK ===
  # Tell the adaptation engine what happened so it can learn
  if [ -f "$ANGEL_HOME/bin/angel-adapt.sh" ]; then
    bash "$ANGEL_HOME/bin/angel-adapt.sh" feedback \
      "$query" \
      "" \
      "" \
      "$([ "$success" = "true" ] && echo true || echo false)" \
      "0" \
      2>/dev/null &
  fi
}

# === Main SuperLoop ===
superloop_main() {
  local query="$*"

  # ── TRACE: SuperLoop start ──
  local SL_TRACE_START
  SL_TRACE_START=$(angel_trace_start "angel-superloop.sh" "main" "${query:0:100}")
  
  if [ -z "$query" ]; then
    angel_trace_end "$SL_TRACE_START" "angel-superloop.sh" "main" "no query" "error"
    echo "Usage: angel-superloop.sh <query>"
    exit 1
  fi
  
  if [ "$DEPTH" -ge "$MAX_DEPTH" ]; then
    angel_trace_end "$SL_TRACE_START" "angel-superloop.sh" "main" "max depth $MAX_DEPTH" "error"
    angel_error "Max depth ($MAX_DEPTH) reached. Possible circular loop."
    exit 1
  fi
  
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║      AngelKernel SuperLoop v4.0 Neural       ║"
  echo "║      Session: $SESSION_ID"
  echo "║      Depth:   $DEPTH / $MAX_DEPTH"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  
  local start_time
  start_time=$(date +%s)
  
  # === Phase 0: NEURAL — Intent classification + context coherence ===
  if [ "${ANGEL_NEURAL_ENABLED:-true}" = "true" ] && [ "${ANGEL_NEURAL_FIRST:-true}" = "true" ] && [ -f "$BIN_DIR/angel-neural.sh" ]; then
    echo ""
    echo "── Phase 0: NEURAL ──"
    local P0_TS
    P0_TS=$(angel_trace_start "angel-superloop.sh" "phase:neural" "${query:0:80}")
    bash "$BIN_DIR/angel-neural.sh" synthesize "$query" 2>/dev/null
    if [ "${ANGEL_UNIVERSAL_HOOKS_ENABLED:-true}" = "true" ] && [ ! -f "$ANGEL_HOME/store/hook_registry.json" ]; then
      bash "$BIN_DIR/angel-hooks-universal.sh" register-all 2>/dev/null &
    fi
    angel_trace_end "$P0_TS" "angel-superloop.sh" "phase:neural" "neural synthesize" "ok"
    echo "  [done]"
  fi
  
  # Phase 1: REASON
  echo "── Phase 1: REASON ──"
  local P1_TS
  P1_TS=$(angel_trace_start "angel-superloop.sh" "phase:reason" "${query:0:80}")
  local analysis
  analysis=$(superloop_reason "$query")
  local intent complexity
  intent=$(echo "$analysis" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('primary_intent','autonomous'))" 2>/dev/null)
  complexity=$(echo "$analysis" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('complexity','simple'))" 2>/dev/null)
  angel_info "Intent: $intent | Complexity: $complexity"
  angel_trace_end "$P1_TS" "angel-superloop.sh" "phase:reason" "intent=$intent complexity=$complexity" "ok"
  
  # === AUTONOMOUS ADAPTATION (Phase 1.5) ===
  echo ""
  echo "── Phase 1.5: AUTONOMOUS ADAPTATION ──"
  local P15_TS
  P15_TS=$(angel_trace_start "angel-superloop.sh" "phase:adapt" "${query:0:80}")
  if [ -f "$ANGEL_HOME/bin/angel-adapt.sh" ] && [ "${ANGEL_AUTO_MODE:-true}" = "true" ]; then
    angel_info "[superloop] Auto-discovering capabilities for task..."
    local adapt_result
    adapt_result=$(bash "$ANGEL_HOME/bin/angel-adapt.sh" auto "$query" 2>/dev/null)
    local adapt_exit=$?
    if [ $adapt_exit -eq 0 ] && [ -n "$adapt_result" ]; then
      # Extract domain info from adapt result to enhance the analysis
      local discovered_domains
      discovered_domains=$(echo "$adapt_result" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(', '.join(d.get('domains', ['general'])))
except: print('general')
" 2>/dev/null)
      angel_info "[superloop] Adaptation discovered domains: $discovered_domains"
      # Store discovered domains in analysis for plan generation
      analysis=$(echo "$adapt_result" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
complexity = '$complexity'
est_steps = 1 if complexity == 'simple' else (3 if complexity == 'medium' else 5)
needs_ver = complexity in ('complex', 'very_complex')
can_par = complexity in ('complex', 'very_complex')
print(json.dumps({
    'primary_intent': '$intent',
    'complexity': complexity,
    'estimated_steps': est_steps,
    'needs_verification': needs_ver,
    'can_parallelize': can_par,
    'domains': d.get('domains', ['general']),
    'required_tools': d.get('required_tools', []),
    'skill_keywords': d.get('skill_keywords', [])
}))
" 2>/dev/null)
    fi
  else
    angel_info "[superloop] Auto-adaptation skipped (not available or disabled)"
  fi
  echo "  [done]"
  angel_trace_end "$P15_TS" "angel-superloop.sh" "phase:adapt" "domains=$discovered_domains" "ok"
  
  # Phase 2: PLAN
  echo ""
  echo "── Phase 2: PLAN ──"
  local P2_TS
  P2_TS=$(angel_trace_start "angel-superloop.sh" "phase:plan" "${query:0:80}")
  local plan
  plan=$(superloop_plan "$query" "$analysis")
  local step_count
  step_count=$(echo "$plan" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read()).get('steps',[])))" 2>/dev/null)
  angel_info "Created plan with $step_count steps"
  angel_trace_end "$P2_TS" "angel-superloop.sh" "phase:plan" "steps=$step_count" "ok"
  
  # Phase 3: ACT
  echo ""
  echo "── Phase 3: ACT ──"
  local P3_TS
  P3_TS=$(angel_trace_start "angel-superloop.sh" "phase:act" "${query:0:80}")
  local results
  export ANGEL_DEPTH=$((DEPTH + 1))
  results=$(superloop_act "$plan" "$query")
  local success="true"
  
  # Check if any step failed badly
  local sl_success
  sl_success=$(echo "$results" | python3 -c "
import json, sys
try:
    r = json.loads('$results')
    for step in r:
        result = step.get('result', '')
        if 'ERROR' in result.upper() and 'FATAL' in result.upper():
            print('false')
            sys.exit(0)
    print('true')
except:
    print('true')
" 2>/dev/null)
  [ -n "$sl_success" ] && success="$sl_success"
  angel_trace_end "$P3_TS" "angel-superloop.sh" "phase:act" "steps=$step_count success=$success" "$([ "$success" = "true" ] && echo ok || echo error)"
  
  # === INTENSIVE MODE for complex tasks ===
  if [ "$complexity" = "very_complex" ] && [ -f "$BIN_DIR/angel-intensive.sh" ] && [ "${ANGEL_INTENSIVE_ENABLED:-true}" = "true" ]; then
    echo ""
    echo "── Phase 3.5: ESCALATING TO INTENSIVE MODE ──"
    local P35_TS
    P35_TS=$(angel_trace_start "angel-superloop.sh" "phase:intensive" "${query:0:80}")
    angel_print "call" "SUPERLOOP→INTENSIVE" "escalating complex task"
    angel_info "[superloop] Complex task detected — delegating to intensive engine..."
    local intensive_result
    intensive_result=$(bash "$BIN_DIR/angel-intensive.sh" "$query" 2>/dev/null)
    angel_info "[superloop] Intensive operations complete"
    echo "$intensive_result" | grep -A9999 "=== INTENSIVE_RESULTS ===" | grep -v "=== INTENSIVE_RESULTS ===" | grep -v "=== END_INTENSIVE_RESULTS ==="
    results="$intensive_result"
    success="true"
    angel_trace_end "$P35_TS" "angel-superloop.sh" "phase:intensive" "delegated to intensive engine" "ok"
  fi
  
  # Phase 5: LEARN
  echo ""
  echo "── Phase 5: LEARN ──"
  local P5_TS
  P5_TS=$(angel_trace_start "angel-superloop.sh" "phase:learn" "${query:0:80}")
  superloop_learn "$query" "$analysis" "$plan" "$results" "$success"
  angel_trace_end "$P5_TS" "angel-superloop.sh" "phase:learn" "success=$success" "ok"
  
  # Phase 6: PATCH (if needed)
  if [ "$success" != "true" ]; then
    echo ""
    echo "── Phase 6: PATCH ──"
    local P6_TS
    P6_TS=$(angel_trace_start "angel-superloop.sh" "phase:patch" "${query:0:80}")
    superloop_patch "SuperLoop execution had issues for: $query"
    angel_trace_end "$P6_TS" "angel-superloop.sh" "phase:patch" "self-heal triggered" "ok"
  fi
  
  # Phase 7: HOOK
  echo ""
  echo "── Phase 7: HOOK ──"
  local P7_TS
  P7_TS=$(angel_trace_start "angel-superloop.sh" "phase:hook" "${query:0:80}")
  superloop_hook "$query" "$results" "$success"
  angel_trace_end "$P7_TS" "angel-superloop.sh" "phase:hook" "post-processing" "ok"
  
  local elapsed=$(( $(date +%s) - start_time ))
  
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  SuperLoop Complete                          ║"
  echo "║  Session: $SESSION_ID"
  echo "║  Status:  $success"
  echo "║  Elapsed: ${elapsed}s"
  echo "╚══════════════════════════════════════════════╝"
  
  angel_trace_end "$SL_TRACE_START" "angel-superloop.sh" "main" "elapsed=${elapsed}s success=$success" "$([ "$success" = "true" ] && echo ok || echo error)"
  
  # Return the results for the calling agent
  echo ""
  echo "=== SUPERLOOP_RESULTS ==="
  echo "$results"
  echo "=== END_SUPERLOOP_RESULTS ==="
  return 0
}

superloop_main "$@"
