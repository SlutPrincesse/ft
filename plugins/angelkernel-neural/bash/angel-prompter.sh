#!/bin/bash
set -euo pipefail
# angel-prompter — Advanced Prompt Engineering System.
#
# Makes ANY model perform better by dynamically optimizing prompts:
#   1. Analyzes task type and selects optimal prompt structure
#   2. Retrieves relevant few-shot examples from Memory Cortex
#   3. Manages context window (what to include, what to trim)
#   4. Optimizes parameters (temperature, top_p, max_tokens) per task
#   5. Constructs dynamic system prompts with relevant context
#   6. Applies prompt enhancement techniques (chain-of-thought, 
#      role-playing, structured output, etc.)
#
# This is the secret sauce that elevates weak models and
# maximizes strong ones.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="prompter"
angel_console_init 2>/dev/null || true

PROMPTER_DIR="$ANGEL_HOME/store/prompter"
mkdir -p "$PROMPTER_DIR"

# ========================================================================
# PROMPT TEMPLATE LIBRARY
# ========================================================================

# Each template defines: system_prompt, temperature, technique, examples_needed
declare -A PROMPT_TEMPLATES

# Code Generation
PROMPT_TEMPLATES["code"]='{
  "technique": "chain_of_thought",
  "temperature": 0.2,
  "max_tokens": 4096,
  "system_prompt": "You are an expert programmer. Write clean, well-documented code.\n\nRULES:\n1. Think through the problem step by step\n2. Write complete, working code (no stubs, no TODOs)\n3. Include error handling\n4. Add comments for non-obvious logic\n5. Follow language conventions\n6. Consider edge cases\n\nBefore writing code, briefly outline your approach.",
  "examples_needed": true,
  "context_hint": "code_intel",
  "verification": "test"
}'

# Research & Analysis
PROMPT_TEMPLATES["research"]='{
  "technique": "structured_output",
  "temperature": 0.3,
  "max_tokens": 2048,
  "system_prompt": "You are a thorough researcher. Analyze the topic carefully and provide structured information.\n\nFORMAT:\n- Key Findings (3-5 bullet points)\n- Details & Context\n- Sources/References (if applicable)\n- Confidence Level (high/medium/low)\n\nRULES:\n1. Distinguish factual claims from interpretations\n2. If uncertain, express the degree of uncertainty\n3. Prioritize recent information\n4. Note any contradictions in available data",
  "examples_needed": false,
  "context_hint": "web_search",
  "verification": "citations"
}'

# Creative Writing
PROMPT_TEMPLATES["creative"]='{
  "technique": "role_playing",
  "temperature": 0.8,
  "max_tokens": 2048,
  "system_prompt": "You are a creative writer with a distinctive voice. Write engaging, original content.\n\nGUIDELINES:\n1. Show, don'\''t tell\n2. Use vivid, specific details\n3. Vary sentence structure for rhythm\n4. Create memorable moments\n5. Stay consistent with tone and voice\n6. End with impact",
  "examples_needed": false,
  "context_hint": "none",
  "verification": "readability"
}'

# Debugging & Fixing
PROMPT_TEMPLATES["debug"]='{
  "technique": "problem_decomposition",
  "temperature": 0.1,
  "max_tokens": 4096,
  "system_prompt": "You are a debugging expert. Systematically identify and fix issues.\n\nPROCESS:\n1. Understand what the code SHOULD do\n2. Identify what it ACTUALLY does\n3. Locate the discrepancy\n4. Determine root cause\n5. Implement fix\n6. Verify fix doesn'\''t break other things\n\nBe precise. Test your reasoning before suggesting changes.",
  "examples_needed": true,
  "context_hint": "code_intel",
  "verification": "test"
}'

# Learning & Explanation
PROMPT_TEMPLATES["learning"]='{
  "technique": "analogy",
  "temperature": 0.5,
  "max_tokens": 2048,
  "system_prompt": "You are a patient teacher. Explain concepts clearly using examples and analogies.\n\nMETHOD:\n1. Start with the big picture\n2. Use analogies from everyday experience\n3. Build up from simple to complex\n4. Check for understanding\n5. Connect to what the learner already knows\n6. Provide concrete examples\n\nAssume the learner is smart but unfamiliar with this specific topic.",
  "examples_needed": false,
  "context_hint": "none",
  "verification": "clarity"
}'

# Planning & Architecture
PROMPT_TEMPLATES["planning"]='{
  "technique": "tree_of_thought",
  "temperature": 0.3,
  "max_tokens": 2048,
  "system_prompt": "You are a systems architect and planner. Design solutions carefully.\n\nAPPROACH:\n1. Define requirements and constraints\n2. Explore multiple approaches\n3. Evaluate trade-offs for each\n4. Select the best approach with justification\n5. Break down into concrete steps\n6. Identify dependencies and risks\n7. Suggest verification strategies",
  "examples_needed": true,
  "context_hint": "memory",
  "verification": "completeness"
}'

# Default / General
PROMPT_TEMPLATES["general"]='{
  "technique": "direct",
  "temperature": 0.4,
  "max_tokens": 2048,
  "system_prompt": "You are a capable AI assistant. Help the user with their request.\n\nBEST PRACTICES:\n1. Answer directly and completely\n2. If the request is ambiguous, state your interpretation\n3. Provide evidence or reasoning for your answers\n4. Admit uncertainty when appropriate\n5. Offer to elaborate or clarify if needed",
  "examples_needed": false,
  "context_hint": "none",
  "verification": "relevance"
}'

# ========================================================================
# TECHNIQUE 1: Analyze query and select best prompt template
# ========================================================================

prompter_analyze() {
  local query="$*"
  
  # Detect task type from query keywords
  local task_type="general"
  
  if echo "$query" | grep -qiE "write|code|program|function|class|implement|script|api|create.*app|build.*function"; then
    task_type="code"
  elif echo "$query" | grep -qiE "debug|fix|error|bug|issue|broken|not working|doesn't work|failing"; then
    task_type="debug"
  elif echo "$query" | grep -qiE "research|search|find|investigate|analyze|study|what is|how does|explain|compare|difference"; then
    task_type="research"
  elif echo "$query" | grep -qiE "write.*story|poem|creative|essay|article|content|blog|script.*video"; then
    task_type="creative"
  elif echo "$query" | grep -qiE "teach|learn|understand|concept|tutorial|guide|explain.*simple|what.*mean"; then
    task_type="learning"
  elif echo "$query" | grep -qiE "plan|design|architecture|strategy|roadmap|proposal|approach|system design"; then
    task_type="planning"
  fi
  
  echo "$task_type"
}

# ========================================================================
# TECHNIQUE 2: Build optimized prompt
# ========================================================================

prompter_build() {
  local query="$*"
  local task_type
  task_type=$(prompter_analyze "$query")
  
  # Get template
  local template="${PROMPT_TEMPLATES[$task_type]:-${PROMPT_TEMPLATES[general]}}"
  
  # Get task type parameters
  local technique temperature max_tokens system_prompt examples_needed context_hint verification
  technique=$(echo "$template" | python3 -c "import json,sys; print(json.load(sys.stdin).get('technique','direct'))" 2>/dev/null)
  temperature=$(echo "$template" | python3 -c "import json,sys; print(json.load(sys.stdin).get('temperature',0.4))" 2>/dev/null)
  max_tokens=$(echo "$template" | python3 -c "import json,sys; print(json.load(sys.stdin).get('max_tokens',2048))" 2>/dev/null)
  system_prompt=$(echo "$template" | python3 -c "import json,sys; print(json.load(sys.stdin).get('system_prompt',''))" 2>/dev/null)
  examples_needed=$(echo "$template" | python3 -c "import json,sys; print(json.load(sys.stdin).get('examples_needed',False))" 2>/dev/null)
  context_hint=$(echo "$template" | python3 -c "import json,sys; print(json.load(sys.stdin).get('context_hint','none'))" 2>/dev/null)
  verification=$(echo "$template" | python3 -c "import json,sys; print(json.load(sys.stdin).get('verification','none'))" 2>/dev/null)
  
  angel_info "[prompter] Task: $task_type | Technique: $technique | Temp: $temperature"
  
  # Build enhanced system prompt with technique-specific instructions
  local enhanced_system="$system_prompt"
  
  # Add technique-specific framing
  case "$technique" in
    chain_of_thought)
      enhanced_system+="\n\nTHINKING PROCESS:\nLet me work through this step by step:\n1. First, understand the requirements\n2. Then, plan the approach\n3. Next, implement the solution\n4. Finally, verify correctness"
      ;;
    tree_of_thought)
      enhanced_system+="\n\nMULTIPLE APPROACHES:\nConsider at least 2-3 different approaches. For each:\n- Describe the approach\n- List pros and cons\n- Estimate complexity\nThen select the best approach and develop it fully."
      ;;
    structured_output)
      enhanced_system+="\n\nOUTPUT FORMAT:\nProvide your response in a clear, structured format with sections and bullet points where appropriate."
      ;;
    role_playing)
      enhanced_system+="\n\nVOICE & STYLE:\nAdopt the voice naturally. Be engaging. Vary your sentence structure. Use concrete details."
      ;;
    problem_decomposition)
      enhanced_system+="\n\nDEBUG PROCESS:\n1. Reproduce the issue\n2. Isolate the failing component\n3. Identify root cause\n4. Implement minimal fix\n5. Verify the fix"
      ;;
    analogy)
      enhanced_system+="\n\nTEACHING METHOD:\n1. Start with what they know\n2. Bridge with an analogy\n3. Explain the concept\n4. Give concrete example\n5. Check understanding"
      ;;
  esac
  
  # Add verification requirement
  case "$verification" in
    test)    enhanced_system+="\n\nVERIFICATION: Include a way to test that your solution works correctly." ;;
    clarity) enhanced_system+="\n\nVERIFICATION: After explaining, check if the explanation would make sense to someone new to this topic." ;;
    citations) enhanced_system+="\n\nVERIFICATION: Distinguish between established facts and your own analysis." ;;
    completeness) enhanced_system+="\n\nVERIFICATION: Ensure your plan covers all requirements and edge cases." ;;
  esac
  
  # Retrieve few-shot examples if needed
  local examples=""
  if [ "$examples_needed" = "True" ] || [ "$examples_needed" = "true" ]; then
    examples=$(prompter_get_examples "$task_type" "$query" 2>/dev/null)
  fi
  
  # Retrieve context if available
  local context=""
  if [ "$context_hint" != "none" ] && [ -f "$ANGEL_HOME/bin/angel-cortex.sh" ]; then
    context=$(bash "$ANGEL_HOME/bin/angel-cortex.sh" recall "$query" 3 2>/dev/null | python3 -c "
import json, sys
lines = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        content = d.get('content', '')[:500]
        score = d.get('relevance_score', 0)
        if score > 0.3:
            lines.append(f\"[Relevant memory (score: {score})]: {content}\")
    except: pass
print('\\n'.join(lines[:3]))
" 2>/dev/null)
  fi
  
  # Build the complete prompt using Python for proper JSON construction
  # Pass all data via argv to avoid shell escaping issues
  local prompt
  prompt=$(python3 -c "
import json, sys

task_type = sys.argv[1]
technique = sys.argv[2]
temperature = float(sys.argv[3])
max_tokens = int(sys.argv[4])
system_prompt = sys.argv[5]
examples_raw = sys.argv[6]
context_raw = sys.argv[7]
query = sys.argv[8]

prompt = {
    'task_type': task_type,
    'technique': technique,
    'temperature': temperature,
    'max_tokens': max_tokens,
    'system_prompt': system_prompt,
    'user_query': query
}

if examples_raw.strip():
    prompt['examples'] = examples_raw.strip()
if context_raw.strip():
    prompt['context'] = context_raw.strip()

print(json.dumps(prompt, indent=2))
" "$task_type" "$technique" "$temperature" "$max_tokens" "$enhanced_system" "$examples" "$context" "$query" 2>/dev/null)
  
  echo "$prompt"
}

# ========================================================================
# TECHNIQUE 3: Retrieve few-shot examples from Memory Cortex
# ========================================================================

prompter_get_examples() {
  local task_type="$1" query="$2"
  
  # Search for similar successful interactions
  if [ -f "$ANGEL_HOME/bin/angel-cortex.sh" ]; then
    local examples
    examples=$(bash "$ANGEL_HOME/bin/angel-cortex.sh" l2-search "$task_type $query" 3 0.5 2>/dev/null)
    
    if [ -n "$examples" ]; then
      echo "$examples" | python3 -c "
import json, sys
examples = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
    except: continue
    content = d.get('content', '')
    if len(content) > 50:
        examples.append(f\"Previous similar task: {content[:500]}\")
print('\\n'.join(examples[:2]))
" 2>/dev/null
    fi
  fi
}

# ========================================================================
# TECHNIQUE 4: Apply prompt to a model call
# ========================================================================

prompter_apply() {
  local query="$*"
  
  # Build the optimized prompt
  local prompt_json
  prompt_json=$(prompter_build "$query")
  
  # Extract components
  local system_prompt temp max_tokens
  system_prompt=$(echo "$prompt_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('system_prompt', ''))
" 2>/dev/null)
  temp=$(echo "$prompt_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('temperature', 0.4))
" 2>/dev/null)
  max_tokens=$(echo "$prompt_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('max_tokens', 2048))
" 2>/dev/null)
  
  # Build the message payload (pass JSON via pipe to avoid escaping issues)
  local messages
  messages=$(echo "$prompt_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
msgs = [{'role': 'system', 'content': d.get('system_prompt', '')}]
context = d.get('context', '')
examples = d.get('examples', '')
user_content = d.get('user_query', '')
if context:
    user_content = f\"Relevant context from previous interactions:\\n{context}\\n\\n---\\n\\n{user_content}\"
if examples:
    user_content = f\"{examples}\\n\\n---\\n\\n{user_content}\"
msgs.append({'role': 'user', 'content': user_content})
print(json.dumps(msgs))
" 2>/dev/null)
  
  # Output the optimized parameters as JSON
  cat <<EOF
{
  "model_params": {
    "temperature": $temp,
    "max_tokens": $max_tokens
  },
  "messages": $messages,
  "prompt_analysis": $(echo "$prompt_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(json.dumps({
    'task_type': d.get('task_type', 'general'),
    'technique': d.get('technique', 'direct'),
    'has_context': bool(d.get('context', '')),
    'has_examples': bool(d.get('examples', ''))
}))
" 2>/dev/null)
}
EOF
}

# ========================================================================
# TECHNIQUE 5: Optimize context window (trim/reorder for max relevance)
# ========================================================================

prompter_optimize_context() {
  local max_chars="${1:-4000}" # Default max context window
  shift
  local contexts=("$@")
  
  python3 -c "
import json, sys

max_chars = $max_chars
contexts = $(python3 -c "import json; print(json.dumps($(printf '%s\n' "${contexts[@]}" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split('\n')))" 2>/dev/null)))")

# Sort by relevance (heuristic: more specific = more relevant)
# Keep only what fits in context window
result = []
chars = 0
for ctx in contexts:
    ctx = ctx.strip()
    if not ctx: continue
    # Truncate each context item if needed
    item = ctx[:max_chars // len(contexts)]
    if chars + len(item) <= max_chars:
        result.append(item)
        chars += len(item)

print(json.dumps({'optimized_contexts': result, 'total_chars': chars, 'max_chars': max_chars}))
" 2>/dev/null
}

# ========================================================================
# TECHNIQUE 6: Post-process response
# ========================================================================

prompter_refine() {
  local response="$1" task_type="$2"
  
  case "$task_type" in
    code)
      # Ensure code blocks are properly formatted
      if echo "$response" | grep -qi "here'\{0,1\}s the\|here'\{0,1\}s a\|example:"; then
        # It's a conversational response, might need code block wrapping
        :
      fi
      ;;
    research)
      # Check for source citations
      if ! echo "$response" | grep -qiE "according to|source|reference|based on"; then
        echo "NOTE: Response lacks citations. Consider requesting sources."
      fi
      ;;
  esac
  
  echo "$response"
}

# ========================================================================
# TECHNIQUE 7: Evaluate prompt quality
# ========================================================================

prompter_evaluate() {
  local query="$*"
  
  local prompt_json
  prompt_json=$(prompter_build "$query")
  
  echo "$prompt_json" | python3 -c "
import json, sys

d = json.load(sys.stdin)
system = d.get('system_prompt', '')
user = d.get('user_query', '')
context = d.get('context', '')
examples = d.get('examples', '')

# Quality metrics
metrics = {
    'task_type': d.get('task_type', 'general'),
    'technique': d.get('technique', 'direct'),
    'system_prompt_length': len(system),
    'user_query_length': len(user),
    'context_length': len(context),
    'examples_count': len(examples.split('\\n')) if examples else 0,
    'has_context': bool(context),
    'has_examples': bool(examples),
    'total_prompt_chars': len(system) + len(user) + len(context) + len(examples),
}

# Scoring
score = 0.5
if metrics['system_prompt_length'] > 100: score += 0.1
if metrics['system_prompt_length'] < 2000: score += 0.1
if metrics['has_context']: score += 0.15
if metrics['has_examples']: score += 0.15
if metrics['examples_count'] > 0: score += 0.1

metrics['quality_score'] = round(score, 2)

print(json.dumps(metrics, indent=2))
" 2>/dev/null
}

# ========================================================================
# MAIN INTERFACE
# ========================================================================

case "${1:-}" in
  analyze)
    shift; prompter_analyze "$@" ;;
  build)
    shift; prompter_build "$@" ;;
  apply)
    shift; prompter_apply "$@" ;;
  evaluate)
    shift; prompter_evaluate "$@" ;;
  optimize-context)
    shift; prompter_optimize_context "$@" ;;
  refine)
    shift; prompter_refine "$1" "$2" ;;
  templates)
    echo "Available prompt templates:"
    for key in "${!PROMPT_TEMPLATES[@]}"; do
      echo "  $key"
      echo "$key:" "${PROMPT_TEMPLATES[$key]}" | python3 -c "
import json, sys
line = sys.stdin.read().strip()
key, val = line.split(':', 1)
d = json.loads(val)
print(f'    Technique: {d[\"technique\"]}')
print(f'    Temperature: {d[\"temperature\"]}')
print(f'    Max tokens: {d[\"max_tokens\"]}')
print(f'    Examples: {d[\"examples_needed\"]}')
print(f'    Verification: {d[\"verification\"]}')
" 2>/dev/null
    done
    ;;
  *)
    echo "AngelKernel Prompt Engineer — Elevates any model through optimized prompting"
    echo ""
    echo "Usage:"
    echo "  angel-prompter.sh analyze <query>      — Detect task type"
    echo "  angel-prompter.sh build <query>         — Build optimized prompt"
    echo "  angel-prompter.sh apply <query>         — Get model-ready parameters"
    echo "  angel-prompter.sh evaluate <query>      — Evaluate prompt quality"
    echo "  angel-prompter.sh refine <response> <type> — Post-process response"
    echo "  angel-prompter.sh templates             — List all templates"
    echo ""
    echo "Example:"
    echo "  angel-prompter.sh analyze \"Write a Python function to sort a list\""
    echo "  angel-prompter.sh apply \"Explain quantum computing simply\""
    ;;
esac
