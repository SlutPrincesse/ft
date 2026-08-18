#!/bin/bash
# angel-swarm — Swarm Intelligence: Inter-agent coordination and parallel execution.
#
# Capabilities:
#   - Spawn multiple subagents for parallel work
#   - Inter-agent message passing
#   - Voting/consensus mechanisms
#   - Result aggregation from multiple agents
#   - Role-based specialization
#   - Dynamic leader election
#
# Elevates any model by:
#   - Combining multiple model perspectives
#   - Parallel exploration of solutions
#   - Cross-verification between agents
#   - Democratic decision-making for critical choices

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="swarm"
angel_console_init 2>/dev/null || true

SWARM_DIR="$ANGEL_HOME/store/swarm"
mkdir -p "$SWARM_DIR"

# Available agent roles and their model mappings
declare -A SWARM_ROLES
SWARM_ROLES=(
  ["thinker"]="opencode/nemotron-3-super-free"
  ["coder"]="opencode/ring-2.6-1t-free" 
  ["researcher"]="opencode/deepseek-v4-flash-free"
  ["critic"]="opencode/nemotron-3-super-free"
  ["planner"]="opencode/nemotron-3-super-free"
  ["reviewer"]="opencode/ring-2.6-1t-free"
  ["debugger"]="opencode/ring-2.6-1t-free"
  ["architect"]="opencode/nemotron-3-super-free"
)

# === Spawn a subagent to work on a task ===
swarm_spawn() {
  local role="$1" task="$2" parent_session="${3:-root}" priority="${4:-normal}"
  local agent_id="SWARM-$(date +%s)-$$-${RANDOM}"
  
  # Map role to model
  local model="${SWARM_ROLES[$role]:-$role}"
  
  angel_print "swarm" "SPAWN" "role=$role agent=$agent_id model=$model task='${task:0:60}'"
  
  # Create agent session
  local agent_dir="$SWARM_DIR/$agent_id"
  mkdir -p "$agent_dir"
  
  # Write task definition
  cat > "$agent_dir/task.json" <<EOF
{
  "agent_id": "$agent_id",
  "role": "$role",
  "model": "$model",
  "task": $(echo "$task" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "parent_session": "$parent_session",
  "priority": "$priority",
  "status": "spawned",
  "created": $(date +%s),
  "completed": null,
  "result": null
}
EOF
  
  angel_info "[swarm] Spawned $role ($agent_id): ${task:0:60}..."
  
  # Execute the agent in background
  (
    export ANGEL_SUBAGENT_ID="$agent_id"
    export ANGEL_SUBAGENT_ROLE="$role"
    export ANGEL_DEPTH=0
    
    local start_time result exit_code
    start_time=$(date +%s)
    
    # Update status to running
    python3 -c "
import json
d = json.load(open('$agent_dir/task.json'))
d['status'] = 'running'
json.dump(d, open('$agent_dir/task.json', 'w'))
" 2>/dev/null
    
    # Execute via proxy call or direct
    if angel_has curl; then
      local messages
      messages=$(cat <<EOF
[
  {"role": "system", "content": "You are a $role agent in the AngelKernel swarm. Perform your task to the best of your ability."},
  {"role": "user", "content": $(echo "$task" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")}
]
EOF
)
      result=$(angel_proxy_call "$model" "$messages" 0.5 4096)
      exit_code=$?
    else
      result="{\"error\": \"No curl available\"}"
      exit_code=1
    fi
    
    local elapsed=$(( $(date +%s) - start_time ))
    
    # Write result
    local response_text
    response_text=$(angel_extract_response "$result" 2>/dev/null || echo "No response")
    
    python3 -c "
import json
d = json.load(open('$agent_dir/task.json'))
d['status'] = 'completed'
d['completed'] = $(date +%s)
d['result'] = '''$response_text'''
d['elapsed'] = $elapsed
d['exit_code'] = $exit_code
json.dump(d, open('$agent_dir/task.json', 'w'))
" 2>/dev/null
    
    # Signal completion
    touch "$agent_dir/DONE"
    
  ) 2>/dev/null &
  
  echo "$agent_id"
}

# === Wait for agents to complete ===
swarm_wait() {
  local agent_ids=("$@")
  local timeout="${SWARM_TIMEOUT:-120}"
  local start_time
  start_time=$(date +%s)
  
  for agent_id in "${agent_ids[@]}"; do
    local agent_dir="$SWARM_DIR/$agent_id"
    if [ ! -d "$agent_dir" ]; then
      angel_warn "[swarm] Agent $agent_id not found"
      continue
    fi
    
    # Wait for DONE marker or timeout
    while [ ! -f "$agent_dir/DONE" ]; do
      local elapsed=$(( $(date +%s) - start_time ))
      if [ "$elapsed" -gt "$timeout" ]; then
        angel_warn "[swarm] Timeout waiting for $agent_id"
        break
      fi
      sleep 1
    done
  done
}

# === Get agent result ===
swarm_result() {
  local agent_id="$1"
  local agent_dir="$SWARM_DIR/$agent_id"
  if [ -f "$agent_dir/task.json" ]; then
    python3 -c "
import json
d = json.load(open('$agent_dir/task.json'))
print(json.dumps(d, indent=2))
" 2>/dev/null
  else
    echo "{\"error\": \"Agent $agent_id not found\"}"
  fi
}

# === Send message to an agent ===
swarm_send() {
  local agent_id="$1" message="$2"
  local agent_dir="$SWARM_DIR/$agent_id"
  mkdir -p "$agent_dir/messages"
  local msg_id="MSG-$(date +%s)-${RANDOM}"
  cat > "$agent_dir/messages/$msg_id.json" <<EOF
{
  "msg_id": "$msg_id",
  "from": "swarm-orchestrator",
  "to": "$agent_id",
  "ts": $(date +%s),
  "content": $(echo "$message" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "read": false
}
EOF
  echo "$msg_id"
}

# === Read messages for an agent ===
swarm_read_messages() {
  local agent_id="$1"
  local agent_dir="$SWARM_DIR/$agent_id"
  if [ -d "$agent_dir/messages" ]; then
    for msg_file in "$agent_dir/messages"/*.json; do
      [ -f "$msg_file" ] || continue
      cat "$msg_file"
      echo "---"
    done
  fi
}

# === Democratic consensus: multiple agents vote on a decision ===
swarm_consensus() {
  local question="$1" min_agents="${2:-3}" timeout="${3:-60}"
  
  angel_print "decision" "SWARM CONSENSUS" "question='${question:0:60}' min_agents=$min_agents"
  angel_info "[swarm] Seeking consensus: ${question:0:80}..."
  
  # Spawn multiple agents to evaluate
  local agents=()
  local roles=("thinker" "critic" "planner" "architect" "researcher")
  
  local count=0
  for role in "${roles[@]}"; do
    if [ "$count" -ge "$min_agents" ]; then break; fi
    local agent_id
    agent_id=$(swarm_spawn "$role" "Evaluate this question and provide your reasoning, then give a YES/NO answer with confidence (0-1): $question" "consensus" "high")
    agents+=("$agent_id")
    count=$((count + 1))
  done
  
  # Wait with timeout
  export SWARM_TIMEOUT="$timeout"
  swarm_wait "${agents[@]}"
  
  # Collect votes
  local votes_json=""
  votes_json=$(python3 -c "
import json, os, glob

agents = ${agents[*]}
votes = []
for agent_dir_glob in glob.glob('$SWARM_DIR/SWARM-*'):
    task_file = os.path.join(agent_dir_glob, 'task.json')
    if not os.path.exists(task_file): continue
    try:
        d = json.load(open(task_file))
    except: continue
    if d.get('status') != 'completed': continue
    result = d.get('result', '')
    
    # Simple sentiment: look for YES/NO
    upper = result.upper()
    yes_count = upper.count('YES')
    no_count = upper.count('NO')
    
    # Try to extract confidence
    confidence = 0.5
    import re
    conf_matches = re.findall(r'confidence[:\s]+([0-9.]+)', result)
    if conf_matches:
        confidence = float(conf_matches[0])
    
    vote = 'yes' if yes_count > no_count else ('no' if no_count > yes_count else 'abstain')
    votes.append({
        'agent': d.get('agent_id', 'unknown'),
        'role': d.get('role', 'unknown'),
        'vote': vote,
        'confidence': confidence,
        'reasoning': result[:500]
    })

print(json.dumps(votes, indent=2))
" 2>/dev/null)
  
  # Tally
  local yes_votes no_votes abstain total
  yes_votes=$(echo "$votes_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(sum(1 for v in d if v['vote']=='yes'))" 2>/dev/null)
  no_votes=$(echo "$votes_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(sum(1 for v in d if v['vote']=='no'))" 2>/dev/null)
  abstain=$(echo "$votes_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(sum(1 for v in d if v['vote']=='abstain'))" 2>/dev/null)
  total=$((yes_votes + no_votes + abstain))
  
  local decision="undecided"
  local confidence=0.0
  
  if [ "$total" -gt 0 ]; then
    if [ "$yes_votes" -gt "$no_votes" ]; then
      decision="yes"
      confidence=$(echo "$yes_votes $total" | python3 -c "print($yes_votes / $total)" 2>/dev/null)
    elif [ "$no_votes" -gt "$yes_votes" ]; then
      decision="no"
      confidence=$(echo "$no_votes $total" | python3 -c "print($no_votes / $total)" 2>/dev/null)
    fi
  fi
  
  cat <<EOF
{
  "question": $(echo "$question" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "decision": "$decision",
  "confidence": $confidence,
  "total_votes": $total,
  "yes": $yes_votes,
  "no": $no_votes,
  "abstain": $abstain,
  "votes": $votes_json
}
EOF
}

# === Parallel task execution: fan-out / fan-in ===
swarm_parallel() {
  local task="$1" split_strategy="${2:-auto}" min_agents="${3:-3}"
  
  angel_info "[swarm] Parallel execution: ${task:0:80}..."
  
  # Decompose task into sub-tasks
  local subtasks
  subtasks=$(python3 -c "
import json, sys

task = '''$task'''
lines = task.strip().split('\n')
tasks = []
buffer = ''
for line in lines:
    if line.startswith('-') or line.startswith('*') or line.startswith('1.'):
        if buffer.strip():
            tasks.append(buffer.strip())
            buffer = ''
    buffer += line + ' '
if buffer.strip():
    tasks.append(buffer.strip())

if not tasks:
    tasks = [task]

result = []
for i, t in enumerate(tasks):
    result.append({'id': i+1, 'task': t})

print(json.dumps(result))
" 2>/dev/null)
  
  local task_count
  task_count=$(echo "$subtasks" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" 2>/dev/null)
  [ "$task_count" -gt "$min_agents" ] && task_count=$min_agents
  
  # Spawn agents in parallel
  local agent_ids=()
  for ((i=0; i<task_count; i++)); do
    local sub_task role="worker"
    sub_task=$(echo "$subtasks" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d[$i]['task'])" 2>/dev/null)
    
    # Assign roles round-robin
    local roles=("coder" "thinker" "researcher" "critic" "debugger")
    role="${roles[$((i % ${#roles[@]}))]}"
    
    local agent_id
    agent_id=$(swarm_spawn "$role" "$sub_task" "parallel-$SESSION_ID" "normal")
    agent_ids+=("$agent_id")
  done
  
  # Wait for all
  export SWARM_TIMEOUT=120
  swarm_wait "${agent_ids[@]}"
  
  # Collect results
  echo "{"
  echo "  \"task\": $(echo "$task" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),"
  echo "  \"agents_spawned\": $task_count,"
  echo "  \"results\": ["
  local first=true
  for agent_id in "${agent_ids[@]}"; do
    $first || echo ","
    first=false
    swarm_result "$agent_id" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(json.dumps({'agent_id': d.get('agent_id'), 'role': d.get('role'), 'status': d.get('status'), 'result_preview': (d.get('result','') or '')[:200], 'elapsed': d.get('elapsed')}, indent=2))
" 2>/dev/null
  done
  echo "  ]"
  echo "}"
}

# === Orchestrate: full swarm workflow ===
swarm_orchestrate() {
  local query="$1" mode="${2:-auto}"
  
  case "$mode" in
    consensus)
      swarm_consensus "$query"
      ;;
    parallel)
      swarm_parallel "$query"
      ;;
    debate)
      # Spawn agents with opposing views, then synthesize
      local pro_agent
      local con_agent
      pro_agent=$(swarm_spawn "thinker" "Argue FOR: $query" "debate" "high")
      con_agent=$(swarm_spawn "critic" "Argue AGAINST: $query" "debate" "high")
      swarm_wait "$pro_agent" "$con_agent"
      
      local pro_result con_result
      pro_result=$(swarm_result "$pro_agent" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('result',''))" 2>/dev/null)
      con_result=$(swarm_result "$con_agent" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('result',''))" 2>/dev/null)
      
      # Synthesize
      local synthesizer
      synthesizer=$(swarm_spawn "planner" "Synthesize these two perspectives into a balanced conclusion.\n\nPRO:\n$pro_result\n\nCON:\n$con_result" "debate-synthesis" "high")
      swarm_wait "$synthesizer"
      swarm_result "$synthesizer"
      ;;
    *)
      echo "Usage: angel-swarm.sh orchestrate <query> {consensus|parallel|debate}"
      ;;
  esac
}

# === Stats ===
swarm_stats() {
  echo "=== Swarm Intelligence Stats ==="
  echo "Active agents: $(find "$SWARM_DIR" -name 'DONE' -not -newer "$SWARM_DIR" 2>/dev/null | wc -l)"
  echo "Total sessions: $(ls -d "$SWARM_DIR"/SWARM-* 2>/dev/null | wc -l)"
  echo "Roles available:"
  for role in "${!SWARM_ROLES[@]}"; do
    echo "  $role -> ${SWARM_ROLES[$role]}"
  done
}

# === Cleanup old sessions ===
swarm_cleanup() {
  local max_age="${1:-3600}"
  find "$SWARM_DIR" -name 'DONE' -cmin "+$((max_age / 60))" -exec dirname {} \; | xargs rm -rf 2>/dev/null
  angel_info "[swarm] Cleaned up sessions older than ${max_age}s"
}

case "${1:-}" in
  spawn)
    shift; swarm_spawn "$1" "$2" "${3:-root}" "${4:-normal}" ;;
  wait)
    shift; swarm_wait "$@" ;;
  result)
    shift; swarm_result "$1" ;;
  send)
    shift; swarm_send "$1" "$2" ;;
  messages)
    shift; swarm_read_messages "$1" ;;
  consensus)
    shift; swarm_consensus "$@" ;;
  parallel)
    shift; swarm_parallel "$@" ;;
  debate)
    shift; swarm_orchestrate "$1" "debate" ;;
  orchestrate)
    shift; swarm_orchestrate "$@" ;;
  stats)
    swarm_stats ;;
  cleanup)
    shift; swarm_cleanup "$1" ;;
  *)
    echo "Usage: angel-swarm.sh {spawn|wait|result|send|messages|consensus|parallel|debate|orchestrate|stats|cleanup} [args]"
    ;;
esac
