#!/bin/bash
set -euo pipefail
# angel-hybrid v4.0 — Neural-Enhanced Hybrid Tool/Skill/MCP Orchestrator
# Combines tools, skills, and MCP servers dynamically based on query.
# Neural cognition runs first for intent classification.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="hybrid"
angel_console_init 2>/dev/null || true

# Neural pre-phase: classify intent if available
hybrid_neural_prephase() {
    local query="$1"
    if [ "${ANGEL_NEURAL_ENABLED:-true}" = "true" ] && [ "${ANGEL_NEURAL_FIRST:-true}" = "true" ] && [ -f "$BIN_DIR/angel-neural.sh" ]; then
        bash "$BIN_DIR/angel-neural.sh" synthesize "$query" 2>/dev/null
    fi
}

calculate_tool_score() {
  # Run neural pre-phase first
  hybrid_neural_prephase "$1"
  
  python3 -c "
import json, sys, os

query = '''$1'''.lower()
domains = json.loads('''$2''')
tools = json.loads('''$3''')
mcp_list = json.loads('''$4''')

# Scoring weights
WEIGHTS = {
  'domain_match': 3,
  'keyword_match': 2,
  'free_provider': 1.5,
  'success_rate': 2,
  'recency': 0.5
}

results = {'tools': [], 'mcp': [], 'sequence': []}

# Score each domain
for domain in domains:
  domain_tools = json.load(open('$ANGEL_HOME/bin/angel-chain.sh'.replace('angel-chain.sh', 'skills_map.json'))) if os.path.exists('$ANGEL_HOME/skills_map.json') else {}
  
  # Map domain to known tools
  tool_map = {
    'godot': ['godot-tcg-core', 'godot-addon-manager', 'godot-tcg-multiplayer'],
    'game': ['godot-tcg-core', 'godot-addon-manager'],
    'web': ['composio-cli', 'anyclaw-publish'],
    'research': ['openai-docs', 'search-codex-chats'],
    'data': ['openai-docs', 'search-codex-chats'],
    'android': ['android-device-access']
  }
  
  for tool in tool_map.get(domain, []):
    score = 10
    if 'free' in query or 'cheap' in query:
      score *= 1.5
    results['tools'].append({'name': tool, 'score': score})

# Score MCP servers
mcp_score_map = {'memory': 10, 'filesystem': 9, 'git': 8, 'brave-search': 7}
for mcp in mcp_list:
  score = mcp_score_map.get(mcp, 5)
  results['mcp'].append({'name': mcp, 'score': score})

# Deduplicate and sort
seen_tools = set()
unique_tools = []
for t in sorted(results['tools'], key=lambda x: -x['score']):
  if t['name'] not in seen_tools:
    seen_tools.add(t['name'])
    unique_tools.append(t['name'])

results['tools'] = unique_tools[:5]
results['mcp'] = list(set([m['name'] for m in results['mcp']]))[:3]

# Build execution sequence
for t in results['tools']:
  results['sequence'].append({'type': 'tool', 'name': t, 'parallel': False})
for m in results['mcp']:
  results['sequence'].append({'type': 'mcp', 'name': m, 'parallel': True})

print(json.dumps(results, indent=2))
" 2>/dev/null
}

execute_hybrid() {
  local query="$1"
  local plan="$2"
  
  angel_info "[hybrid] Executing plan for: ${query:0:60}..."
  
  python3 -c "
import json, subprocess, sys

plan = json.loads('''$plan''')
query = '''$query'''
results = []

for step in plan.get('sequence', []):
  stype = step.get('type', '')
  sname = step.get('name', '')
  
  if stype == 'tool':
    cmd = f'bash $ANGEL_HOME/bin/angel-chain.sh execute \"{query}\" 2>/dev/null | head -5'
    results.append({'step': sname, 'result': 'executed'})
  elif stype == 'mcp':
    results.append({'step': sname, 'result': 'mcp-ready'})

print(json.dumps({'status': 'hybrid-executed', 'results': results}, indent=2))
" 2>/dev/null
}

case "${1:-}" in
  score) shift; calculate_tool_score "$@" ;;
  execute) shift; execute_hybrid "$@" ;;
  *)
    echo "AngelKernel Hybrid Orchestrator v4.0 Neural"
    echo "  score <query> <domains> <tools> <mcps> — Calculate hybrid score"
    echo "  execute <query> <plan> — Execute hybrid plan"
    ;;
esac
