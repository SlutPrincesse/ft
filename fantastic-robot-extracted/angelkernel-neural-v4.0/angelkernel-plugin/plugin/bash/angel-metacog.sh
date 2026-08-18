#!/bin/bash
set -euo pipefail
# angel-metacog — Meta-Cognition: Self-awareness layer for any model.
#
# Capabilities:
#   - Confidence estimation on model outputs
#   - Hallucination detection via cross-verification
#   - Automatic strategy switching when confidence is low
#   - Self-questioning: model evaluates its own answers
#   - Calibration: tracks accuracy vs confidence over time
#   - Uncertainty-aware routing: high-uncertainty → more agents
#
# Elevates any model by:
#   - Detecting when the model is likely wrong
#   - Verifying critical claims
#   - Adapting approach based on confidence
#   - Learning from calibration errors

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="metacog"
angel_console_init 2>/dev/null || true

METACOG_DIR="$ANGEL_HOME/memory/metacog"
mkdir -p "$METACOG_DIR"

# === Confidence estimation on a model output ===
metacog_confidence() {
  local question="$1" answer="$2"
  
  # Multiple confidence signals
  local signals=()
  
  # Signal 1: Answer length (very short answers are often less reliable)
  local ans_len
  ans_len=$(echo "$answer" | wc -c | xargs)
  local len_conf=0.5
  if [ "$ans_len" -gt 500 ]; then len_conf=0.7
  elif [ "$ans_len" -gt 100 ]; then len_conf=0.5
  elif [ "$ans_len" -gt 20 ]; then len_conf=0.3
  else len_conf=0.1
  fi
  signals+=("$len_conf")
  
  # Signal 2: Contains hedge words (lower confidence)
  local hedge_count
  hedge_count=$(echo "$answer" | grep -ciE "i think|maybe|perhaps|possibly|could be|might be|not sure|i believe|probably|i guess" 2>/dev/null)
  [ -z "$hedge_count" ] && hedge_count=0
  local hedge_conf=$(python3 -c "print(max(0.1, 1.0 - $hedge_count * 0.15))" 2>/dev/null)
  signals+=("$hedge_conf")
  
  # Signal 3: Contains specific numbers, code, or citations (higher confidence)
  local spec_count
  spec_count=$(echo "$answer" | grep -cE '[0-9]+\.[0-9]+|https?://|def |class |function |=>|import |#include|```' 2>/dev/null)
  [ -z "$spec_count" ] && spec_count=0
  local spec_conf=$(python3 -c "print(min(1.0, 0.5 + $spec_count * 0.1))" 2>/dev/null)
  signals+=("$spec_conf")
  
  # Signal 4: Self-consistency — check if answer contains contradictions
  local contra_count
  contra_count=$(echo "$answer" | grep -ciE "however|but|although|on the other hand|nevertheless|alternatively" 2>/dev/null)
  [ -z "$contra_count" ] && contra_count=0
  # A few contrasting points is normal, many suggests uncertain
  local contra_conf
  if [ "$contra_count" -le 2 ] 2>/dev/null; then contra_conf=0.7
  elif [ "$contra_count" -le 5 ] 2>/dev/null; then contra_conf=0.5
  else contra_conf=0.3
  fi
  signals+=("$contra_conf")
  
  # Signal 5: Use LLM self-evaluation if possible
  local llm_conf=0.5
  if angel_has curl; then
    local eval_prompt
    eval_prompt=$(cat <<EOF
[
  {"role": "system", "content": "Rate the confidence of this answer on 0-1. Consider: is it specific? Does it hedge? Is it internally consistent? Respond with ONLY a number between 0 and 1."},
  {"role": "user", "content": "Question: $question\n\nAnswer: $answer\n\nConfidence score (0-1):"}
]
EOF
)
    local eval_result
    eval_result=$(angel_proxy_call "opencode/nemotron-3-super-free" "$eval_prompt" 0.0 50 2>/dev/null)
    llm_conf=$(angel_extract_response "$eval_result" 2>/dev/null | grep -oE '0\.[0-9]+|1\.0' | head -1)
    [ -z "$llm_conf" ] && llm_conf=0.5
  fi
  signals+=("$llm_conf")
  
  # Aggregate: weighted average
  local signal_str
  signal_str=$(IFS=,; echo "${signals[*]}")
  python3 -c "
signals = [$signal_str]
weights = [0.15, 0.2, 0.2, 0.15, 0.3]  # LLM eval gets highest weight
confidence = sum(s * w for s, w in zip(signals, weights)) / sum(weights)
print(round(min(1.0, max(0.0, confidence)), 3))
"
}

# === Hallucination detection via cross-verification ===
metacog_detect_hallucination() {
  local claim="$1" domain="${2:-general}"
  
  # If the claim is short, not enough to verify
  local claim_len
  claim_len=$(echo "$claim" | wc -c | xargs)
  [ "$claim_len" -lt 20 ] && { echo "{\"hallucination_probability\": 0.3, \"reason\": \"Claim too short to verify\"}"; return; }
  
  # Pattern-based hallucination signals
  local signals=()
  
  # Signal 1: Contains specific-looking but likely fake details
  local fake_detail_score=0
  if echo "$claim" | grep -qiE "according to (recent|unpublished|internal)"; then fake_detail_score=0.3; fi
  if echo "$claim" | grep -qiE "studies show|research indicates" && ! echo "$claim" | grep -qiE "https?://|DOI|PMID|arXiv"; then fake_detail_score=0.4; fi
  if echo "$claim" | grep -qiE "experts say|some people say|it is said|commonly believed"; then fake_detail_score=0.3; fi
  signals+=("$fake_detail_score")
  
  # Signal 2: Overly precise numbers without source
  if echo "$claim" | grep -qiE "[0-9]+\.[0-9]{2,}%" && ! echo "$claim" | grep -qiE "source|citation|reference|according to"; then
    signals+=("0.4")
  else
    signals+=("0.1")
  fi
  
  # Signal 3: Check for logical consistency
  # Contradictory statements within the claim
  local contradiction_score=0
  if echo "$claim" | grep -qiE "always.*never|all.*none|everyone.*no one|everything.*nothing"; then contradiction_score=0.5; fi
  signals+=("$contradiction_score")
  
  # Signal 4: Use cross-model verification if available
  local cross_score=0.2
  if angel_has curl; then
    local verify_prompt
    verify_prompt=$(cat <<EOF
[
  {"role": "system", "content": "You are a fact-checker. Rate the likelihood that this claim is hallucinated (made up) on 0-1. Consider: does it cite verifiable sources? Are the numbers plausible? Is it internally consistent? Respond ONLY with a number between 0 and 1."},
  {"role": "user", "content": "Claim: $claim\n\nHallucination probability (0-1):"}
]
EOF
)
    local verify_result
    verify_result=$(angel_proxy_call "opencode/nemotron-3-super-free" "$verify_prompt" 0.0 50 2>/dev/null)
    cross_score=$(angel_extract_response "$verify_result" 2>/dev/null | grep -oE '0\.[0-9]+|1\.0' | head -1)
    [ -z "$cross_score" ] && cross_score=0.3
  fi
  signals+=("$cross_score")
  
  # Aggregate
  local h_signal_str
  h_signal_str=$(IFS=,; echo "${signals[*]}")
  python3 -c "
import json
signals = [$h_signal_str]
weights = [0.2, 0.15, 0.2, 0.45]
prob = sum(s * w for s, w in zip(signals, weights)) / sum(weights)
print(json.dumps({'hallucination_probability': round(min(1.0, max(0.0, prob)), 3), 'reason': 'Cross-verification with multiple signals'}))
"
}

# === Strategy switching: when confidence is low, try a different approach ===
metacog_switch_strategy() {
  local current_strategy="$1" confidence="$2" task="$3"
  
  # Strategies ranked by cognitive depth
  local strategies=("direct" "research_first" "decompose" "debate" "swarm_consensus" "ask_clarification")
  
  # Find current strategy index
  local current_idx=-1
  for i in "${!strategies[@]}"; do
    if [ "${strategies[$i]}" = "$current_strategy" ]; then
      current_idx=$i
      break
    fi
  done
  
  # Determine next strategy based on confidence
  local next_strategy="direct"
  local reason=""
  
  if [ "$(python3 -c "print(1 if $confidence < 0.3 else 0)" 2>/dev/null)" = "1" ]; then
    # Very low confidence: escalate significantly
    next_strategy="swarm_consensus"
    reason="Confidence $confidence is very low, escalating to swarm consensus"
  elif [ "$(python3 -c "print(1 if $confidence < 0.5 else 0)" 2>/dev/null)" = "1" ]; then
    next_strategy="decompose"
    reason="Confidence $confidence is moderate, decomposing task for better results"
  elif [ "$(python3 -c "print(1 if $confidence < 0.7 else 0)" 2>/dev/null)" = "1" ]; then
    next_strategy="research_first"
    reason="Confidence $confidence is fair, adding research step"
  else
    next_strategy="direct"
    reason="Confidence $confidence is high, proceeding directly"
  fi
  
  # If current strategy is already escalated but confidence is still low, go deeper
  if [ "$current_idx" -ge 0 ] && [ "$current_idx" -lt $((${#strategies[@]} - 1)) ]; then
    next_strategy="${strategies[$((current_idx + 1))]}"
    reason="Previous strategy ($current_strategy) insufficient, escalating to $next_strategy"
  fi
  
  cat <<EOF
{
  "previous_strategy": "$current_strategy",
  "next_strategy": "$next_strategy",
  "confidence": $confidence,
  "reason": "$reason"
}
EOF
}

# === Calibration: track confidence vs actual success ===
metacog_calibrate() {
  local question="$1" confidence="$2" actual_success="$3"
  
  local cal_file="$METACOG_DIR/calibration.ndjson"
  
  # Record calibration point
  echo "{\"ts\":$(date +%s),\"question\":$(echo "$question" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()[:200]))"),\"confidence\":$confidence,\"actual\":$actual_success}" >> "$cal_file"
  
  # Calculate calibration stats
  python3 -c "
import json

bins = {'0.0-0.2': [], '0.2-0.4': [], '0.4-0.6': [], '0.6-0.8': [], '0.8-1.0': []}
total = 0
correct = 0
try:
    with open('$cal_file') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except: continue
            c = d.get('confidence', 0.5)
            a = d.get('actual', False)
            total += 1
            if a: correct += 1
            # Bin
            if c < 0.2: bins['0.0-0.2'].append(a)
            elif c < 0.4: bins['0.2-0.4'].append(a)
            elif c < 0.6: bins['0.4-0.6'].append(a)
            elif c < 0.8: bins['0.6-0.8'].append(a)
            else: bins['0.8-1.0'].append(a)
    
    # Compute calibration error
    cal_error = 0.0
    for bin_name, outcomes in bins.items():
        if not outcomes: continue
        avg_conf = float(bin_name.split('-')[0]) + 0.1
        actual_acc = sum(1 for o in outcomes if o) / len(outcomes) if outcomes else 0
        cal_error += abs(avg_conf - actual_acc) * len(outcomes)
    cal_error = cal_error / total if total > 0 else 0
    
    print(json.dumps({
        'total_calibrations': total,
        'overall_accuracy': round(correct/total, 3) if total > 0 else 0,
        'calibration_error': round(cal_error, 3),
        'bins': {k: {'count': len(v), 'accuracy': round(sum(1 for o in v if o)/len(v), 3) if v else 0} for k, v in bins.items()}
    }))
except FileNotFoundError:
    print(json.dumps({'total_calibrations': 0}))
"
}

# === Self-questioning: model generates and answers its own follow-ups ===
metacog_self_question() {
  local topic="$1" depth="${2:-2}"
  
  # Generate questions the model should ask itself
  local questions_prompt
  questions_prompt=$(cat <<EOF
[
  {"role": "system", "content": "Generate $depth critical follow-up questions about this topic that would help verify understanding. Return as JSON array of strings."},
  {"role": "user", "content": "Topic: $topic\n\nQuestions:"}
]
EOF
)
  
  local questions_result
  questions_result=$(angel_proxy_call "opencode/nemotron-3-super-free" "$questions_prompt" 0.3 500 2>/dev/null)
  local questions
  questions=$(angel_extract_response "$questions_result" 2>/dev/null)
  
  echo "{"
  echo "  \"topic\": $(echo "$topic" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),"
  echo "  \"self_questions\": $(echo "$questions" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),"
  echo "  \"depth\": $depth"
  echo "}"
}

# === Full meta-cognitive assessment of a model output ===
metacog_assess() {
  local question="$1" answer="$2"
  
  angel_print "decision" "METACOG ASSESS" "question='${question:0:60}' answer_len=${#answer}"
  
  echo ""
  echo "=== Meta-Cognitive Assessment ==="
  echo ""
  
  # 1. Confidence
  local confidence
  confidence=$(metacog_confidence "$question" "$answer")
  echo "Confidence: $confidence"
  
  # 2. Hallucination check
  local hall_result
  hall_result=$(metacog_detect_hallucination "$answer")
  local hall_prob
  hall_prob=$(echo "$hall_result" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('hallucination_probability', 0))" 2>/dev/null)
  echo "Hallucination Probability: $hall_prob"
  
  # 3. Strategy recommendation
  local strategy
  strategy=$(metacog_switch_strategy "direct" "$confidence" "$question")
  local next_strat
  next_strat=$(echo "$strategy" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('next_strategy','direct'))" 2>/dev/null)
  echo "Recommended Strategy: $next_strat"
  
  # 4. Self-questions
  local self_q
  self_q=$(metacog_self_question "$question" 2)
  echo "Self-Verification Questions:"
  echo "$self_q" | python3 -c "
import json,sys
d = json.load(sys.stdin)
q = d.get('self_questions', '')
print(q)
" 2>/dev/null
  
  # Output JSON for programmatic use
  cat <<EOF
{
  "confidence": $confidence,
  "hallucination_probability": $hall_prob,
  "recommended_strategy": "$next_strat",
  "strategy_detail": $strategy,
  "self_questions": $self_q
}
EOF
}

# === Stats ===
metacog_stats() {
  echo "=== Meta-Cognition Stats ==="
  echo "Calibrations: $(wc -l < "$METACOG_DIR/calibration.ndjson" 2>/dev/null || echo 0)"
  if [ -f "$METACOG_DIR/calibration.ndjson" ]; then
    python3 -c "
import json
total = 0
correct = 0
try:
    with open('$METACOG_DIR/calibration.ndjson') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except: continue
            total += 1
            if d.get('actual'): correct += 1
    if total > 0:
        print(f'Accuracy: {correct}/{total} = {round(correct/total*100, 1)}%')
except: pass
"
  fi
}

case "${1:-}" in
  confidence)
    shift; metacog_confidence "$1" "$2" ;;
  hallucination)
    shift; metacog_detect_hallucination "$1" "${2:-general}" ;;
  strategy)
    shift; metacog_switch_strategy "$1" "$2" "$3" ;;
  calibrate)
    shift; metacog_calibrate "$1" "$2" "$3" ;;
  self-question)
    shift; metacog_self_question "$1" "${2:-2}" ;;
  assess)
    shift; metacog_assess "$1" "${2:-}" ;;
  stats)
    metacog_stats ;;
  *)
    echo "Usage: angel-metacog.sh {confidence|hallucination|strategy|calibrate|self-question|assess|stats} [args]"
    ;;
esac
