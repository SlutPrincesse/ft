#!/bin/bash
set -euo pipefail
# angel-mcp-optimize — MCP Server Discovery and Usage Optimization
# Discovers, registers, and optimizes MCP servers dynamically

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true

MCP_DIR="$ANGEL_HOME/mcp"
MCP_CONFIG="$MCP_DIR/mcp.json"
MCP_REGISTRY="$MCP_DIR/registry.json"
mkdir -p "$MCP_DIR"

# Initialize MCP registry with popular servers
init_mcp_registry() {
  if [ ! -f "$MCP_REGISTRY" ]; then
    cat > "$MCP_REGISTRY" << 'EOF'
{
  "servers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "/"],
      "capabilities": ["read", "write", "list"],
      "contexts": ["file", "code", "general"]
    },
    "memory": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-memory"],
      "capabilities": ["store", "recall", "search"],
      "contexts": ["memory", "context", "all"]
    },
    "brave-search": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-brave-search"],
      "capabilities": ["web-search", "find"],
      "contexts": ["research", "web", "general"]
    },
    "git": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-git", "--repository", "/"],
      "capabilities": ["status", "log", "diff"],
      "contexts": ["git", "version-control", "dev"]
    },
    "github": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"],
      "capabilities": ["issues", "repos", "prs"],
      "contexts": ["github", "devops", "collaboration"]
    },
    "postgres": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-postgres", "postgresql://..."],
      "capabilities": ["query", "schema", "data"],
      "contexts": ["database", "data", "sql"]
    },
    "slack": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-slack"],
      "capabilities": ["messages", "channels", "users"],
      "contexts": ["communication", "team", "notifications"]
    }
  },
  "auto_discovery": {
    "enabled": true,
    "sources": ["npm", "github", "community-lists"]
  }
}
EOF
  fi
}

# Discover and register new MCP servers
discover_mcps() {
  angel_info "[mcp] Discovering MCP servers..."
  
  # Search npm for MCP servers
  local new_mcps
  new_mcps=$(curl -s "https://registry.npmjs.org/-/v1/search?text=mcp%20server&size=20" 2>/dev/null | \
    python3 -c "
import json, sys
try:
    results = json.load(sys.stdin).get('objects', [])
    for r in results[:10]:
        name = r.get('package', {}).get('name', '')
        if 'mcp' in name and 'server' in name:
            print(name)
except: pass
" 2>/dev/null)
  
  echo "$new_mcps"
}

# Generate optimized MCP config based on query
optimize_mcp_for_query() {
  local query="$1"
  
  python3 -c "
import json, sys

query = '''$query'''.lower()
registry = json.load(open('$MCP_REGISTRY'))

# Score servers based on query relevance
scores = {}
for name, info in registry.get('servers', {}).items():
  score = 0
  for ctx in info.get('contexts', []):
    if ctx in query or query in ctx:
      score += 2
    # Partial matches
    for word in query.split():
      if word in ctx:
        score += 1
  scores[name] = score

# Select top servers
selected = [n for n, s in sorted(scores.items(), key=lambda x: -x[1]) if s > 0][:4]

# Build config
mcp_config = {}
for name in selected:
  if name in registry['servers']:
    mcp_config[name] = registry['servers'][name].copy()
    mcp_config[name].pop('contexts', None)

result = {
  'selected': selected,
  'config': mcp_config,
  'reasoning': {n: scores[n] for n in selected}
}
print(json.dumps(result, indent=2))
" 2>/dev/null
}

# Auto-register high-score MCP servers
auto_register() {
  init_mcp_registry
  
  local available_servers
  available_servers=$(discover_mcps)
  
  if [ -n "$available_servers" ]; then
    echo "[mcp] Found potential servers:"
    echo "$available_servers" | head -10
    
    # Register top ones
    for server in $(echo "$available_servers" | head -3); do
      if ! grep -q "$server" "$MCP_REGISTRY"; then
        angel_info "[mcp] Registering: $server"
        python3 -c "
import json
r = json.load(open('$MCP_REGISTRY'))
r['servers']['$server'] = {
  'command': 'npx',
  'args': ['$server'],
  'capabilities': ['auto-detected'],
  'contexts': ['general']
}
json.dump(r, open('$MCP_REGISTRY', 'w'), indent=2)
" 2>/dev/null
      fi
    done
  fi
}

# Performance optimization
optimize_performance() {
  local metrics_file="$ANGEL_HOME/store/metrics.ndjson"
  
  python3 -c "
import json, sys

# Analyze MCP performance
servers = {}
try:
  with open('$metrics_file') as f:
    for line in f:
      try:
        m = json.loads(line)
        if 'mcp' in m.get('name', ''):
          name = m.get('labels', {}).get('server', 'unknown')
          if name not in servers:
            servers[name] = {'calls': 0, 'errors': 0, 'total_time': 0}
          servers[name]['calls'] += 1
          servers[name]['total_time'] += m.get('value', 0)
          if m.get('status') == 'error':
            servers[name]['errors'] += 1
      except: pass
except: pass

# Rank by performance
ranked = sorted(servers.items(), key=lambda x: (x[1]['errors']/max(x[1]['calls'],1), x[1]['total_time']/max(x[1]['calls'],1)))

print('MCP Performance Ranking:')
for name, stats in ranked[:5]:
  err_rate = stats['errors']/max(stats['calls'],1)*100
  avg_time = stats['total_time']/max(stats['calls'],1)
  print(f'  {name}: {stats[\"calls\"]} calls, {err_rate:.1f}% errors, {avg_time:.0f}ms avg')
" 2>/dev/null
}

# Main
case "${1:-}" in
  init) init_mcp_registry && echo "MCP registry initialized" ;;
  discover) discover_mcps ;;
  optimize) shift; optimize_mcp_for_query "$@" ;;
  register) auto_register ;;
  perf) optimize_performance ;;
  *)
    echo "AngelKernel MCP Optimizer"
    echo "  init      — Initialize MCP registry"
    echo "  discover  — Find new MCP servers"
    echo "  optimize <query> — Optimize for query"
    echo "  register  — Auto-register discovered servers"
    echo "  perf      — Show performance ranking"
    ;;
esac