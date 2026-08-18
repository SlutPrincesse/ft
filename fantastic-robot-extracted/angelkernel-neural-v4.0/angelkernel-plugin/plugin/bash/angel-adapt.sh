#!/bin/bash
set -euo pipefail
# angel-adapt — Autonomous Adaptation Engine.
#
# Makes AngelKernel truly self-directed by:
#   1. Analyzing any task to determine required skills & plugins
#   2. Proactively discovering, installing, and enabling missing capabilities
#   3. Routing tasks to the optimal skill/plugin combination
#   4. Learning from outcomes to improve future routing
#   5. Continuously scanning for new capabilities
#
# This is the key difference between "reactive" and "autonomous":
#   Reactive: User asks for skill → install skill → use skill
#   Autonomous: User asks for task → analyze → discover needed skills →
#               auto-install → auto-enable → execute with optimal tools → learn

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="adapt"
angel_console_init 2>/dev/null || true

ADAPT_DIR="$ANGEL_HOME/store/adapt"
ROUTING_DB="$ADAPT_DIR/routing.json"
DISCOVERY_CACHE="$ADAPT_DIR/discovery_cache.json"
FEEDBACK_LOG="$ADAPT_DIR/feedback.ndjson"
mkdir -p "$ADAPT_DIR"

# Initialize databases
[ ! -f "$ROUTING_DB" ] && echo '{"routes":[],"skills":{},"plugins":{}}' > "$ROUTING_DB"
[ ! -f "$DISCOVERY_CACHE" ] && echo '{"last_scan":0,"known_skills":[],"known_plugins":[]}' > "$DISCOVERY_CACHE"

# ========================================================================
# PHASE 1: TASK ANALYSIS — Understand what the task needs
# ========================================================================

adapt_analyze() {
  local query="$*"
  angel_info "[adapt] Analyzing task: ${query:0:80}..."

  local domains_json complexity_json tools_json skill_keywords_json
  domains_json=$(angel_detect_domains "$query")
  complexity_json=$(angel_estimate_complexity "$query")
  tools_json=$(angel_detect_tools "$query")
  skill_keywords_json=$(angel_skill_keywords_for_domains "$domains_json")

  local analysis
  analysis=$(python3 -c "
import json, sys
domains = json.loads(sys.argv[1])
complexity = sys.argv[2]
tools = json.loads(sys.argv[3])
skill_keywords = json.loads(sys.argv[4])
print(json.dumps({
    'domains': domains,
    'required_tools': tools,
    'skill_keywords': skill_keywords,
    'complexity': complexity,
    'needs_skills': len(skill_keywords) > 0,
    'needs_plugins': len(domains) > 0,
}))
" "$domains_json" "$complexity_json" "$tools_json" "$skill_keywords_json" 2>/dev/null)

  echo "$analysis"
}

# ========================================================================
# PHASE 2: SKILL DISCOVERY — Find relevant skills
# ========================================================================

adapt_discover_skills() {
  local analysis="$1"
  local domains skill_keywords
  domains=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(','.join(d.get('domains',[])))" 2>/dev/null)
  skill_keywords=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(','.join(d.get('skill_keywords',[])))" 2>/dev/null)

  angel_info "[adapt] Discovering skills for domains: $domains"

  local results='{"installed_matches":[],"available_matches":[],"installable":[]}'

  # --- Scan installed skills ---
  local installed_matches="[]"
  if [ -d "$ANGEL_HOME/skills" ]; then
    installed_matches=$(python3 -c "
import json, os, glob

skill_keywords = '''$skill_keywords'''.lower().split(',')
domains = '''$domains'''.lower().split(',')

matches = []
skills_dir = '$ANGEL_HOME/skills'
if os.path.isdir(skills_dir):
    for skill in os.listdir(skills_dir):
        skill_dir = os.path.join(skills_dir, skill)
        if not os.path.isdir(skill_dir): continue
        skill_lower = skill.lower()
        
        # Check SKILL.md
        readme = ''
        readme_path = os.path.join(skill_dir, 'SKILL.md')
        if os.path.exists(readme_path):
            with open(readme_path) as f:
                readme = f.read().lower()
        
        # Score relevance
        score = 0.0
        for kw in skill_keywords:
            if kw.strip() and kw.strip() in skill_lower:
                score += 1.0
            if kw.strip() and kw.strip() in readme:
                score += 0.5
        for d in domains:
            if d.strip() and d.strip() in skill_lower:
                score += 0.8
            if d.strip() and d.strip() in readme:
                score += 0.4
        
        if score > 0:
            matches.append({'name': skill, 'relevance': round(score, 2), 'source': 'installed', 'path': skill_dir})

matches.sort(key=lambda x: -x['relevance'])
print(json.dumps(matches))
" 2>/dev/null)
  fi

  # --- Scan for installable skills from repos ---
  local available_matches="[]"
  # Check known skill repos (curated list of common skill types)
  available_matches=$(python3 -c "
import json, os

skill_keywords = '''$skill_keywords'''.lower().split(',')
domains = '''$domains'''.lower().split(',')

# Curated skill repository catalog
SKILL_CATALOG = [
    {'name': 'godot-tcg-core', 'repo': 'godot-tcg-core', 'keywords': ['godot', 'tcg', 'game', 'card']},
    {'name': 'godot-addon-manager', 'repo': 'godot-addon-manager', 'keywords': ['godot', 'addon', 'plugin', 'game']},
    {'name': 'flightclaw', 'repo': 'flightclaw', 'keywords': ['flight', 'travel', 'search', 'price']},
    {'name': 'android-device-access', 'repo': 'android', 'keywords': ['android', 'mobile', 'device', 'camera']},
    {'name': 'anyclaw-publish', 'repo': 'anyclaw-publish', 'keywords': ['web', 'deploy', 'publish', 'hosting']},
    {'name': 'imagegen', 'repo': 'imagegen', 'keywords': ['image', 'generate', 'photo', 'illustration']},
    {'name': 'composio-cli', 'repo': 'composio-cli', 'keywords': ['tool', 'api', 'integration', 'cli']},
    {'name': 'openai-docs', 'repo': 'openai-docs', 'keywords': ['openai', 'api', 'llm', 'gpt']},
    {'name': 'search-codex-chats', 'repo': 'search-codex-chats', 'keywords': ['search', 'chat', 'history']},
    {'name': 'telegram-bridge', 'repo': 'telegram-bridge-send', 'keywords': ['telegram', 'message', 'notify']},
    {'name': 'twitter-auto-post', 'repo': 'twitter-auto-post-shizuku', 'keywords': ['twitter', 'social', 'post', 'automation']},
    {'name': 'plugin-creator', 'repo': 'plugin-creator', 'keywords': ['plugin', 'scaffold', 'create']},
    {'name': 'skill-creator', 'repo': 'skill-creator', 'keywords': ['skill', 'create', 'scaffold']},
]

matches = []
installed_path = '$ANGEL_HOME/skills'
for skill in SKILL_CATALOG:
    # Skip if already installed
    skill_dir = os.path.join(installed_path, skill['name'])
    if os.path.isdir(skill_dir):
        continue
    
    score = 0.0
    for kw in skill_keywords:
        if kw.strip() and kw.strip() in ' '.join(skill['keywords']):
            score += 1.0
    for d in domains:
        if d.strip() and d.strip() in ' '.join(skill['keywords']):
            score += 0.8
    
    if score > 0:
        matches.append({'name': skill['name'], 'repo': skill['repo'], 'relevance': round(score, 2), 'source': 'catalog'})

matches.sort(key=lambda x: -x['relevance'])
print(json.dumps(matches))
" 2>/dev/null)

  # --- Check for installable via GitHub search ---
  local github_matches="[]"
  if [ "$(echo "$available_matches" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(len(d))" 2>/dev/null)" = "0" ]; then
    # If catalog had no matches, try GitHub search for top keyword
    local top_keyword
    top_keyword=$(echo "$skill_keywords" | cut -d',' -f1)
    if [ -n "$top_keyword" ] && [ "$top_keyword" != " " ]; then
      github_matches=$(curl -s "https://api.github.com/search/repositories?q=$top_keyword+skill&sort=stars&per_page=5" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    items = d.get('items', [])
    results = []
    for r in items[:3]:
        results.append({
            'name': r['full_name'].split('/')[-1],
            'repo': r['full_name'],
            'relevance': round(r['stargazers_count'] / 1000, 2),
            'source': 'github',
            'url': r['html_url']
        })
    print(json.dumps(results))
except: print('[]')
" 2>/dev/null)
    fi
  fi

  # Combine results
  python3 -c "
import json
installed = json.loads('''$installed_matches''')
available = json.loads('''$available_matches''')
github = json.loads('''$github_matches''') if '''$github_matches''' != '[]' else []
print(json.dumps({
    'installed_matches': installed,
    'available_matches': available,
    'github_matches': github,
    'has_gaps': len(available) > 0 or len(github) > 0
}))
"
}

# ========================================================================
# PHASE 3: PLUGIN DISCOVERY — Find and auto-enable relevant plugins
# ========================================================================

adapt_discover_plugins() {
  local analysis="$1"
  local domains
  domains=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(','.join(d.get('domains',[])))" 2>/dev/null)

  angel_info "[adapt] Discovering plugins for domains: $domains"

  # Check available but disabled plugins
  local matches="[]"
  if [ -d "$ANGEL_HOME/plugins/available" ]; then
    for plugin_dir in "$ANGEL_HOME/plugins/available"/*/; do
      [ -d "$plugin_dir" ] || continue
      local plugin_name
      plugin_name=$(basename "$plugin_dir")
      local manifest="$plugin_dir/plugin.json"
      
      # Skip if already enabled
      [ -L "$ANGEL_HOME/plugins/enabled/$plugin_name" ] && continue
      
      if [ -f "$manifest" ]; then
        local score=0
        # Match plugin description against domains
        local desc
        desc=$(python3 -c "import json; print(json.load(open('$manifest')).get('description','').lower())" 2>/dev/null)
        for d in $(echo "$domains" | tr ',' ' '); do
          echo "$desc" | grep -qi "$d" && score=$((score + 1))
        done
        # Match plugin name
        for d in $(echo "$domains" | tr ',' ' '); do
          echo "$plugin_name" | grep -qi "$d" && score=$((score + 2))
        done
        if [ "$score" -gt 0 ]; then
          matches=$(python3 -c "
import json
m = json.loads('''$matches''')
m.append({'name': '$plugin_name', 'relevance': $score, 'manifest': '$manifest'})
print(json.dumps(m))
" 2>/dev/null)
        fi
      fi
    done
  fi

  echo "$matches"
}

# ========================================================================
# PHASE 4: AUTO-INSTALL — Install missing skills without user prompt
# ========================================================================

adapt_auto_install() {
  local analysis="$1" discovery="$2"
  local has_gaps
  has_gaps=$(echo "$discovery" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('has_gaps', False))" 2>/dev/null)

  if [ "$has_gaps" != "True" ]; then
    angel_info "[adapt] No skill gaps detected"
    return 0
  fi

  angel_info "[adapt] Detected skill gaps — auto-installing via skills.sh + GitHub..."

  # Use enhanced skill manager with skills.sh integration
  if [ -f "$ANGEL_HOME/bin/angel-skill-manager.sh" ]; then
    local domains
    domains=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(','.join(d.get('domains',[])))" 2>/dev/null)
    bash "$ANGEL_HOME/bin/angel-skill-manager.sh" --auto-install "$domains" 2>/dev/null
    return $?
  fi

  # Fallback: Install from catalog directly
  local catalog_items
  catalog_items=$(echo "$discovery" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
items = d.get('available_matches', [])
for item in items:
    print(f\"{item['name']}|{item['repo']}|{item['relevance']}\")
" 2>/dev/null)

  local installed_count=0
  while IFS='|' read -r name repo relevance; do
    [ -z "$name" ] && continue
    angel_info "[adapt] Auto-installing skill: $name (relevance: $relevance)"
    
    # Check if skill installer exists
    if [ -f "$ANGEL_HOME/bin/angel-skill-manager.sh" ]; then
      # Try from local repo first
      if [ -d "$ANGEL_HOME/repos/$repo" ]; then
        cp -r "$ANGEL_HOME/repos/$repo" "$ANGEL_HOME/skills/$name" 2>/dev/null && {
          angel_info "[adapt] Installed skill: $name (from local repo)"
          installed_count=$((installed_count + 1))
        }
      else
        # Install via skill manager
        bash "$ANGEL_HOME/bin/angel-skill-manager.sh" --install "$repo" 2>/dev/null && {
          # Move to skills if installed to wrong location
          if [ -d "$ANGEL_HOME/skills/$repo" ]; then
            mv "$ANGEL_HOME/skills/$repo" "$ANGEL_HOME/skills/$name" 2>/dev/null
          fi
          angel_info "[adapt] Installed skill: $name"
          installed_count=$((installed_count + 1))
        }
      fi
    else
      # Manual install
      local target="$ANGEL_HOME/skills/$name"
      mkdir -p "$target"
      cat > "$target/SKILL.md" << SKILLEOF
# $name

Auto-installed by AngelKernel Adaptation Engine

## Source
Catalog: $repo
Relevance: $relevance
Installed: $(angel_iso)

## Trigger
This skill was auto-installed based on task analysis.
SKILLEOF
      installed_count=$((installed_count + 1))
    fi
  done <<< "$catalog_items"

  angel_info "[adapt] Auto-installed $installed_count new skills"
}

# ========================================================================
# PHASE 5: AUTO-ENABLE — Enable relevant plugins
# ========================================================================

adapt_auto_enable() {
  local analysis="$1" plugin_matches="$2"
  local match_count
  match_count=$(echo "$plugin_matches" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(len(d))" 2>/dev/null)

  if [ "$match_count" = "0" ] || [ -z "$match_count" ]; then
    angel_info "[adapt] No plugins to enable"
    return 0
  fi

  angel_info "[adapt] Auto-enabling $match_count plugin(s)..."

  echo "$plugin_matches" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for plugin in d:
    print(f\"{plugin['name']}|{plugin['relevance']}\")
" 2>/dev/null | while IFS='|' read -r name relevance; do
    [ -z "$name" ] && continue
    if [ -f "$ANGEL_HOME/bin/angel-plugin.sh" ]; then
      bash "$ANGEL_HOME/bin/angel-plugin.sh" enable "$name" 2>/dev/null && {
        angel_info "[adapt] Enabled plugin: $name"
        # Log the auto-enable
        echo "$(date +%s)|auto-enabled|$name|$relevance" >> "$ADAPT_DIR/auto_enables.log"
      }
    fi
  done
}

# ========================================================================
# PHASE 6: TASK ROUTING — Route to optimal skill+plugin combination
# ========================================================================

adapt_route() {
  local query="$*"
  angel_info "[adapt] Routing task: ${query:0:80}..."

  # Check routing database for similar tasks
  local route
  route=$(python3 -c "
import json, sys

query = '''$query'''.lower()
query_words = set(query.split())

try:
    with open('$ROUTING_DB') as f:
        db = json.load(f)
except:
    db = {'routes': [], 'skills': {}, 'plugins': {}}

# Find best matching route
best_route = None
best_score = 0.0
for route in db.get('routes', []):
    pattern_words = set(route.get('pattern', '').split())
    overlap = len(query_words & pattern_words)
    if len(pattern_words) > 0:
        score = overlap / len(pattern_words)
        success_rate = route.get('success_rate', 0.5)
        score = score * 0.7 + success_rate * 0.3
        if score > best_score:
            best_score = score
            best_route = route

if best_route and best_score > 0.3:
    best_route['match_confidence'] = round(best_score, 3)
    print(json.dumps(best_route))
else:
    print(json.dumps({'match_confidence': 0, 'skills': [], 'plugins': [], 'strategy': 'discover'}))
" 2>/dev/null)

  local match_conf
  match_conf=$(echo "$route" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('match_confidence', 0))" 2>/dev/null)

  if [ "$(python3 -c "print(1 if $match_conf > 0.3 else 0)" 2>/dev/null)" = "1" ]; then
    angel_info "[adapt] Found route with confidence $match_conf"
    echo "$route"
  else
    angel_info "[adapt] No route found — will discover"
    echo "{\"match_confidence\":0,\"skills\":[],\"plugins\":[],\"strategy\":\"discover\"}"
  fi
}

# ========================================================================
# PHASE 7: FEEDBACK — Learn from outcomes
# ========================================================================

adapt_feedback() {
  local query="$1" skills_used="$2" plugins_used="$3" success="$4" duration="$5"
  
  angel_info "[adapt] Recording feedback for: ${query:0:60}..."
  
  # Log feedback
  local feedback_entry
  feedback_entry=$(cat <<EOF
{
  "ts": $(date +%s),
  "query": $(echo "$query" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()[:200]))"),
  "skills_used": $(echo "$skills_used" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "plugins_used": $(echo "$plugins_used" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "success": $success,
  "duration": $duration
}
EOF
)
  echo "$feedback_entry" >> "$FEEDBACK_LOG"
  
  # Update routing database (pass vars via argv to avoid bash/python truthiness issues)
  python3 -c "
import json, sys

query = sys.argv[1].lower()
skills = sys.argv[2].strip()
plugins = sys.argv[3].strip()
success_str = sys.argv[4].strip().lower()
success = success_str == 'true' or success_str == '1'
routing_db = sys.argv[5]
now = int(sys.argv[6])

try:
    with open(routing_db) as f:
        db = json.load(f)
except:
    db = {'routes': [], 'skills': {}, 'plugins': {}}

# Extract key pattern from query (first 3-5 significant words)
words = [w for w in query.split() if len(w) > 3][:5]
pattern = ' '.join(words)

# Find existing route
found = False
for route in db.get('routes', []):
    if route.get('pattern', '') == pattern:
        route['count'] = route.get('count', 0) + 1
        route['success_count'] = route.get('success_count', 0) + (1 if success else 0)
        route['success_rate'] = route['success_count'] / route['count']
        route['last_used'] = now
        if skills:
            route['skills'] = list(dict.fromkeys(route.get('skills', []) + [s.strip() for s in skills.split(',') if s.strip()]))
        if plugins:
            route['plugins'] = list(dict.fromkeys(route.get('plugins', []) + [p.strip() for p in plugins.split(',') if p.strip()]))
        found = True
        break

if not found and pattern:
    db['routes'].append({
        'pattern': pattern,
        'count': 1,
        'success_count': 1 if success else 0,
        'success_rate': 1.0 if success else 0.0,
        'skills': [s.strip() for s in skills.split(',') if s.strip()],
        'plugins': [p.strip() for p in plugins.split(',') if p.strip()],
        'first_used': now,
        'last_used': now
    })

# Update skill stats
if skills:
    for s in skills.split(','):
        s = s.strip()
        if not s: continue
        if s not in db['skills']:
            db['skills'][s] = {'uses': 0, 'successes': 0}
        db['skills'][s]['uses'] += 1
        if success:
            db['skills'][s]['successes'] += 1

# Update plugin stats
if plugins:
    for p in plugins.split(','):
        p = p.strip()
        if not p: continue
        if p not in db['plugins']:
            db['plugins'][p] = {'uses': 0, 'successes': 0}
        db['plugins'][p]['uses'] += 1
        if success:
            db['plugins'][p]['successes'] += 1

with open(routing_db, 'w') as f:
    json.dump(db, f, indent=2)
" "$query" "$skills_used" "$plugins_used" "$success" "$ROUTING_DB" "$(date +%s)" 2>/dev/null
}

# ========================================================================
# PHASE 8: CONTINUOUS SCAN — Background discovery
# ========================================================================

adapt_scan() {
  angel_info "[adapt] Scanning for new capabilities..."
  
  local scan_result='{"skills_found":0,"plugins_found":0,"new_skills":[],"new_plugins":[]}'
  
  # Check for uninstalled skills in repos dir
  local new_skills=()
  if [ -d "$ANGEL_HOME/repos" ]; then
    for repo_dir in "$ANGEL_HOME/repos"/*/; do
      [ -d "$repo_dir" ] || continue
      local repo_name
      repo_name=$(basename "$repo_dir")
      # Check if it has a skill-like structure
      if [ -f "$repo_dir/SKILL.md" ] || [ -f "$repo_DIR/skill.json" ]; then
        [ ! -d "$ANGEL_HOME/skills/$repo_name" ] && new_skills+=("$repo_name")
      fi
    done
  fi
  
  # Check for uninstalled plugins
  # Plugins in available/ that aren't enabled
  local new_plugins=()
  if [ -d "$ANGEL_HOME/plugins/available" ]; then
    for plugin_dir in "$ANGEL_HOME/plugins/available"/*/; do
      [ -d "$plugin_dir" ] || continue
      local plugin_name
      plugin_name=$(basename "$plugin_dir")
      [ ! -L "$ANGEL_HOME/plugins/enabled/$plugin_name" ] && new_plugins+=("$plugin_name")
    done
  fi
  
  # Update cache
  python3 -c "
import json
cache = json.load(open('$DISCOVERY_CACHE'))
cache['last_scan'] = $(date +%s)
cache['known_skills'] = $(python3 -c "import json; print(json.dumps($(echo "${new_skills[@]}" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split()))")))") 
cache['known_plugins'] = $(python3 -c "import json; print(json.dumps($(echo "${new_plugins[@]}" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split()))")))")
json.dump(cache, open('$DISCOVERY_CACHE', 'w'))
"
  
  scan_result=$(python3 -c "
import json
skills = $(python3 -c "import json; print(json.dumps($(echo "${new_skills[@]}" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split()))")))")
plugins = $(python3 -c "import json; print(json.dumps($(echo "${new_plugins[@]}" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split()))")))")
print(json.dumps({
    'skills_found': len(skills),
    'plugins_found': len(plugins),
    'new_skills': skills,
    'new_plugins': plugins
}))
")
  
  echo "$scan_result"
}

# ========================================================================
# MAIN: Full Autonomous Adaptation Loop
# ========================================================================

adapt_auto() {
  # Lock: only one adaptation at a time
  angel_lock "adapt" || {
    angel_info "[adapt] Already running — reusing previous analysis"
    local cached="$ADAPT_DIR/last_analysis.json"
    [ -f "$cached" ] && cat "$cached" && return 0
    echo '{"domains":["general"],"complexity":"simple","required_tools":[],"skill_keywords":[]}'
    return 0
  }

  local query="$*"
  local start_time
  start_time=$(date +%s)

  # All user-facing output goes to stderr so callers can capture
  # the JSON result cleanly from stdout
  echo "╔══════════════════════════════════════════════╗" >&2
  echo "║  AngelKernel Autonomous Adaptation           ║" >&2
  echo "╚══════════════════════════════════════════════╝" >&2
  
  echo "── Step 1: Task Analysis ──" >&2
  local analysis
  analysis=$(adapt_analyze "$query")
  local domains complexity
  domains=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(', '.join(d.get('domains',[])))" 2>/dev/null)
  complexity=$(echo "$analysis" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('complexity','simple'))" 2>/dev/null)
  echo "  Domains:    $domains" >&2
  echo "  Complexity: $complexity" >&2
  angel_print "decision" "ADAPT ANALYZE" "domains=$domains complexity=$complexity"
  
  echo "── Step 2: Route Lookup ──" >&2
  local route
  route=$(adapt_route "$query")
  local route_conf
  route_conf=$(echo "$route" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('match_confidence', 0))" 2>/dev/null)
  echo "  Route confidence: $route_conf" >&2
  angel_print "decision" "ADAPT ROUTE" "confidence=$route_conf"
  
  echo "── Step 3: Skill Discovery ──" >&2
  local discovery='{}'
  if [ "$(python3 -c "print(1 if float('$route_conf') < 0.3 else 0)" 2>/dev/null)" = "1" ]; then
    discovery=$(adapt_discover_skills "$analysis")
    local installed_count available_count
    installed_count=$(echo "$discovery" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(len(d.get('installed_matches',[])))" 2>/dev/null)
    available_count=$(echo "$discovery" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(len(d.get('available_matches',[])))" 2>/dev/null)
    echo "  Installed skills matched: $installed_count" >&2
    echo "  Available skills found:  $available_count" >&2
    
    local has_gaps
    has_gaps=$(echo "$discovery" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('has_gaps', False))" 2>/dev/null)
    if [ "$has_gaps" = "True" ]; then
      echo "── Step 3b: Auto-Install Skills ──" >&2
      adapt_auto_install "$analysis" "$discovery"
    fi
  else
    echo "  Using cached route — skipping discovery" >&2
  fi
  
  echo "── Step 4: Plugin Discovery ──" >&2
  local plugin_matches
  plugin_matches=$(adapt_discover_plugins "$analysis")
  local plugin_count
  plugin_count=$(echo "$plugin_matches" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(len(d))" 2>/dev/null)
  echo "  Matchable plugins found: $plugin_count" >&2
  if [ "$plugin_count" -gt 0 ]; then
    echo "── Step 4b: Auto-Enable Plugins ──" >&2
    adapt_auto_enable "$analysis" "$plugin_matches"
  fi
  
  # Step 5: Record what was learned
  local skills_used plugins_used
  skills_used=$(echo "$discovery" | python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    items = d.get('installed_matches', []) + d.get('available_matches', [])
    print(','.join([i['name'] for i in items[:3]]))
except: print('')
" 2>/dev/null)
  plugins_used=$(echo "$plugin_matches" | python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(','.join([i['name'] for i in d[:3]]))
except: print('')
" 2>/dev/null)
  
  local duration=$(( $(date +%s) - start_time ))
  adapt_feedback "$query" "$skills_used" "$plugins_used" true "$duration"
  
  echo "║  Adaptation Complete (${duration}s)            ║" >&2
  echo "╚══════════════════════════════════════════════╝" >&2
  
  # Cache analysis for concurrent callers
  echo "$analysis" > "$ADAPT_DIR/last_analysis.json"
  angel_unlock "adapt"

  # Only the JSON analysis goes to stdout
  echo "$analysis"
}

# ========================================================================
# UTILITY: Show routing stats
# ========================================================================

adapt_stats() {
  echo "=== Adaptation Engine Stats ==="
  echo ""
  
  if [ -f "$ROUTING_DB" ]; then
    python3 -c "
import json
with open('$ROUTING_DB') as f:
    db = json.load(f)
routes = db.get('routes', [])
skills = db.get('skills', {})
plugins = db.get('plugins', {})
print(f'Learned routes: {len(routes)}')
print(f'Skills tracked: {len(skills)}')
print(f'Plugins tracked: {len(plugins)}')
print('')
if routes:
    print('Top routes by success rate:')
    sorted_routes = sorted(routes, key=lambda x: -x.get('success_rate', 0))[:5]
    for r in sorted_routes:
        print(f'  {r[\"pattern\"][:50]:50s} rate={r.get(\"success_rate\",0):.2f} count={r.get(\"count\",0)}')
print('')
if skills:
    print('Skill effectiveness:')
    sorted_skills = sorted(skills.items(), key=lambda x: -x[1].get('successes',0)/max(x[1].get('uses',1),1))
    for name, stats in sorted_skills[:5]:
        rate = stats.get('successes',0) / max(stats.get('uses',1), 1)
        print(f'  {name:30s} uses={stats.get(\"uses\",0)} success_rate={rate:.2f}')
" 2>/dev/null
  fi
  
  echo ""
  if [ -f "$FEEDBACK_LOG" ]; then
    echo "Feedback entries: $(wc -l < "$FEEDBACK_LOG")"
  fi
  if [ -f "$DISCOVERY_CACHE" ]; then
    python3 -c "
import json
c = json.load(open('$DISCOVERY_CACHE'))
from datetime import datetime
last = c.get('last_scan', 0)
if last:
    print(f'Last scan: {datetime.fromtimestamp(last).strftime(\"%Y-%m-%d %H:%M\")}')
print(f'Known skills: {len(c.get(\"known_skills\",[]))}')
print(f'Known plugins: {len(c.get(\"known_plugins\",[]))}')
" 2>/dev/null
  fi
}

# ========================================================================
# MAIN DISPATCH
# ========================================================================

case "${1:-}" in
  auto|adapt)
    shift; adapt_auto "$@" ;;
  analyze)
    shift; adapt_analyze "$@" ;;
  discover-skills)
    shift; adapt_discover_skills "$(adapt_analyze "$@")" ;;
  discover-plugins)
    shift; adapt_discover_plugins "$(adapt_analyze "$@")" ;;
  install)
    shift; adapt_auto_install "$(adapt_analyze "$@")" "$(adapt_discover_skills "$(adapt_analyze "$@")")" ;;
  enable)
    shift; adapt_auto_enable "$(adapt_analyze "$@")" "$(adapt_discover_plugins "$(adapt_analyze "$@")")" ;;
  route)
    shift; adapt_route "$@" ;;
  feedback)
    shift; adapt_feedback "$1" "$2" "$3" "$4" "$5" ;;
  scan)
    adapt_scan ;;
  stats)
    adapt_stats ;;
  *)
    echo "AngelKernel Autonomous Adaptation Engine"
    echo ""
    echo "Usage:"
    echo "  angel-adapt.sh auto <query>       — Full autonomous adaptation loop"
    echo "  angel-adapt.sh analyze <query>    — Analyze task requirements"
    echo "  angel-adapt.sh route <query>      — Find best skill/plugin route"
    echo "  angel-adapt.sh scan               — Scan for new capabilities"
    echo "  angel-adapt.sh stats              — Show adaptation stats"
    echo ""
    echo "Examples:"
    echo "  angel-adapt.sh auto \"Build a Godot trading card game\""
    echo "  angel-adapt.sh auto \"Search web for latest AI news\""
    echo "  angel-adapt.sh auto \"Create a mobile app with Android\""
    ;;
esac
