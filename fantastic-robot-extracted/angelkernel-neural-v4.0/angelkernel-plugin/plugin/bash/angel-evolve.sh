#!/bin/bash
# angel-evolve v3 — Self-Evolution Engine with Recursive Reflection
# Integrated with Mycelium cross-pollination and Unity recursive analysis.
# Handles auto-healing, tool/skill creation, and recursive refinement.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="evolve"
angel_console_init 2>/dev/null || true

BIN_DIR="$ANGEL_HOME/bin"
EVOLVE_DIR="$ANGEL_HOME/evolve"
SKILLS_DIR="$ANGEL_HOME/skills"
ERROR_LOG="$EVOLVE_DIR/error_patterns.ndjson"
PATTERN_DB="$EVOLVE_DIR/patterns.json"
REFLECTIONS_DIR="$ANGEL_HOME/memory/reflections"
mkdir -p "$EVOLVE_DIR" "$SKILLS_DIR" "$REFLECTIONS_DIR"

init_patterns() {
    if [ ! -f "$PATTERN_DB" ]; then
        cat > "$PATTERN_DB" << 'EOF'
{
  "patterns": {
    "missing_tool": {"threshold": 3, "action": "create_tool"},
    "missing_skill": {"threshold": 2, "action": "install_skill"},
    "repeated_error": {"threshold": 5, "action": "generate_fix"},
    "performance_bottleneck": {"threshold": 3, "action": "optimize_chain"},
    "workspace_issue": {"threshold": 2, "action": "recursive_reflect"},
    "domain_bridge": {"threshold": 2, "action": "mycelium_connect"}
  },
  "auto_creation": {
    "enabled": true,
    "max_attempts": 3,
    "test_before_deploy": true
  }
}
EOF
    fi
}

# ============================================================================
# RECURSIVE REFLECTION — Post-task workspace analysis with auto-loop
# Triggered when evolution detects issues that need deeper investigation
# ============================================================================

recursive_reflect() {
    local query="$1"
    local context="${2:-}"
    local reflection_id="RFL-$(date +%s)"
    local reflection_file="$REFLECTIONS_DIR/$reflection_id.json"
    
    angel_print "evolve" "RECURSIVE REFLECT" "analyzing: ${query:0:60}..."
    
    # Analyze workspace for actionable findings
    local reflection
    reflection=$(python3 -c "
import json, sys, os, time

query = '''$query'''
context = '''$context'''
workspace = os.environ.get('ANGEL_WORKSPACE', '/root')

issues = []
improvements = []

# 1. Check git status
git_dir = os.path.join(workspace, '.git')
if os.path.isdir(git_dir):
    try:
        import subprocess
        result = subprocess.run(['git', 'status', '--porcelain'],
                              capture_output=True, text=True, cwd=workspace, timeout=10)
        if result.stdout.strip():
            lines = result.stdout.strip().split('\n')
            for line in lines[:20]:
                state = line[:2]
                path = line[3:]
                if state == '??':
                    issues.append({'type': 'untracked', 'path': path, 'severity': 'info'})
                elif state in ('M ', ' M'):
                    issues.append({'type': 'modified', 'path': path, 'severity': 'info'})
                elif state in ('D ', ' D'):
                    issues.append({'type': 'deleted', 'path': path, 'severity': 'low'})
    except: pass

# 2. Check for error patterns in logs
log_dir = os.path.join('$ANGEL_HOME', 'logs')
if os.path.isdir(log_dir):
    error_count = 0
    failure_count = 0
    try:
        for fname in os.listdir(log_dir):
            fpath = os.path.join(log_dir, fname)
            if os.path.isfile(fpath) and time.time() - os.path.getmtime(fpath) < 86400:
                with open(fpath) as f:
                    for line in f.readlines()[-100:]:
                        if 'ERROR' in line: error_count += 1
                        if 'FAIL' in line or 'fatal' in line: failure_count += 1
        if error_count > 5:
            issues.append({'type': 'error_spike', 'count': error_count, 'severity': 'high'})
            improvements.append('Check $ANGEL_HOME/logs for error details')
        if failure_count > 3:
            issues.append({'type': 'execution_failures', 'count': failure_count, 'severity': 'medium'})
    except: pass

# 3. Check disk usage
try:
    stat = os.statvfs(workspace)
    free_pct = stat.f_bavail / stat.f_blocks * 100
    if free_pct < 10:
        issues.append({'type': 'disk_space', 'free_percent': round(free_pct, 1), 'severity': 'high'})
    elif free_pct < 25:
        issues.append({'type': 'disk_space', 'free_percent': round(free_pct, 1), 'severity': 'low'})
except: pass

# 4. Check ANGEL_HOME health
angel_home = os.path.expanduser('$ANGEL_HOME')
if os.path.isdir(angel_home):
    # Check if critical files exist
    critical_files = [
        'bin/angel-unity.sh', 'bin/angel-kernel.sh', 'lib/angel-lib.sh',
        'config/angel.conf', 'proxy/providers.json'
    ]
    missing = [f for f in critical_files if not os.path.exists(os.path.join(angel_home, f))]
    if missing:
        issues.append({'type': 'missing_critical_files', 'files': missing, 'severity': 'critical'})
        improvements.append(f'Restore missing files: {missing}')

# Determine severity and action
critical_count = sum(1 for i in issues if i.get('severity') in ('high', 'critical'))
total_count = len(issues)

result = {
    'reflection_id': '$reflection_id',
    'query': query,
    'context': context,
    'timestamp': int(time.time()),
    'issues_found': total_count,
    'critical_issues': critical_count,
    'issues': issues[:20],
    'improvements': improvements[:10],
    'needs_recursive_loop': critical_count > 0 or total_count > 5,
    'recommended_action': 're_loop' if critical_count > 0 else ('present' if total_count > 0 else 'clean')
}

with open('$reflection_file', 'w') as f:
    json.dump(result, f, indent=2)

print(json.dumps(result, indent=2))
" 2>/dev/null)
    
    local recommended_action
    recommended_action=$(echo "$reflection" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('recommended_action','clean'))" 2>/dev/null || echo "present")
    local needs_loop
    needs_loop=$(echo "$reflection" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('needs_recursive_loop',False)).lower())" 2>/dev/null || echo "false")
    
    echo "$reflection"
    
    # If critical, trigger recursive loop
    if [ "$needs_loop" = "true" ] && [ -f "$BIN_DIR/angel-unity.sh" ]; then
        local depth="${ANGEL_DEPTH:-0}"
        local max_depth="${ANGEL_MAX_DEPTH:-5}"
        if [ "$depth" -lt "$max_depth" ]; then
            angel_print "evolve" "RECURSIVE LOOP" "critical issues found — refining at depth $((depth+1))"
            export ANGEL_DEPTH=$((depth + 1))
            bash "$BIN_DIR/angel-unity.sh" "Refine: ${query} — fix all issues from reflection $reflection_id" 2>/dev/null &
        fi
    fi
    
    return 0
}

# ============================================================================
# MYCELIUM INTEGRATED EVOLUTION — Full evo cycle with mycelium bridge detection
# ============================================================================

evolve_cycle() {
    local error="${1:-}"
    local context="${2:-}"
    
    init_patterns
    
    if [ -n "$error" ]; then
        local pattern
        pattern=$(analyze_error "$error" "$context")
        
        angel_print "evolve" "PATTERN" "$pattern"
        
        case "$pattern" in
            missing_tool)
                local tool_name
                tool_name=$(echo "$error" | awk '{print $NF}' | sed 's/[^a-zA-Z0-9_-]//g')
                [ -n "$tool_name" ] && create_tool "$tool_name" "Handles: $error"
                ;;
            missing_skill)
                auto_install_skill "$context"
                ;;
            performance_bottleneck)
                generate_fix "$error"
                ;;
            *)
                # Default: run recursive reflection + mycelium forage
                angel_print "evolve" "RECURSIVE REFLECT" "unknown pattern — deep analysis"
                recursive_reflect "$error" "$context"
                
                # Also run mycelium forage for cross-pollination
                if [ -f "$BIN_DIR/angel-self-improve.sh" ]; then
                    bash "$BIN_DIR/angel-self-improve.sh" --forage 2>/dev/null &
                fi
                ;;
        esac
    fi
    
    # Return evolution summary
    echo "{\"status\":\"evolved\",\"pattern\":\"${pattern:-none}\",\"error\":\"${error:0:100}\"}"
}

# ============================================================================
# LEGACY FUNCTIONS (preserved for compatibility)
# ============================================================================

analyze_error() {
    local error="$1"
    local context="$2"
    
    local entry
    entry=$(cat <<EOF
{"ts":$(date +%s),"error":"$(echo "$error" | head -c 500)","context":"$context","type":"analysis"}
EOF
)
    echo "$entry" >> "$ERROR_LOG"
    
    local pattern_type="unknown"
    case "$error" in
        *"command not found"*|*"not recognized"*)
            pattern_type="missing_tool" ;;
        *"skill not found"*|*"no skills matched"*)
            pattern_type="missing_skill" ;;
        *"timeout"*|*"slow response"*)
            pattern_type="performance_bottleneck" ;;
    esac
    
    echo "$pattern_type"
}

create_tool() {
    local tool_name="$1"
    local purpose="$2"
    angel_info "[evolve] Auto-creating tool: $tool_name"
    
    local tool_path="$BIN_DIR/$tool_name"
    cat > "$tool_path" << TOOLEOF
#!/bin/bash
# Auto-created by AngelKernel Evolution Engine
# Purpose: $purpose
# Created: $(date -Iseconds)

ANGEL_HOME="\${ANGEL_HOME:-\$HOME/.angelkernel}"
source "\$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true

main() {
    local query="\$*"
    angel_info "[auto-tool/$tool_name] Processing: \${query:0:60}..."
    if [ -f "\$ANGEL_HOME/bin/angel-unity.sh" ]; then
        bash "\$ANGEL_HOME/bin/angel-unity.sh" "\$query"
    elif [ -f "\$ANGEL_HOME/bin/angel-adapt.sh" ]; then
        bash "\$ANGEL_HOME/bin/angel-adapt.sh" auto "\$query" 2>/dev/null
    else
        echo "Executed auto-tool: $tool_name on \$query"
    fi
}

main "\$@"
TOOLEOF
    chmod +x "$tool_path"
    angel_info "[evolve] Tool created: $tool_path"
}

auto_install_skill() {
    local skill_keywords="$1"
    angel_info "[evolve] Searching for skill: $skill_keywords"
    
    local found_skill
    found_skill=$(curl -s "https://api.github.com/search/repositories?q=$skill_keywords+skill+angelkernel&sort=stars&per_page=3" 2>/dev/null | \
        python3 -c "
import json, sys
try:
    items = json.load(sys.stdin).get('items', [])
    for item in items[:1]:
        print(f\"{item['full_name']}|{item['html_url']}|{item['stargazers_count']}\")
except: print('')
" 2>/dev/null)
    
    if [ -n "$found_skill" ]; then
        local repo_name repo_url stars
        IFS='|' read -r repo_name repo_url stars <<< "$found_skill"
        angel_info "[evolve] Found skill candidate: $repo_name ($stars stars)"
        
        local target_dir="$SKILLS_DIR/$(basename "$repo_name")"
        if [ ! -d "$target_dir" ]; then
            git clone --depth 1 "$repo_url" "$target_dir" 2>/dev/null && \
                angel_info "[evolve] Installed skill: $target_dir"
        fi
    fi
}

generate_fix() {
    local error_pattern="$1"
    local fix_code
    fix_code=$(python3 -c "
error = '''$error_pattern'''
fixes = {
    'file not found': 'Create the file with proper structure',
    'permission denied': 'Check file permissions and run with appropriate access',
    'timeout': 'Increase timeout or split into smaller chunks',
    'rate limit': 'Wait and retry with exponential backoff'
}
for kw, fix in fixes.items():
    if kw in error.lower():
        print(fix)
        break
else:
    print('Analyze error context and apply appropriate solution')
" 2>/dev/null)
    angel_info "[evolve] Suggested fix: $fix_code"
}

# ============================================================================
# MAIN
# ============================================================================

case "${1:-}" in
    init) init_patterns && echo "Evolution patterns initialized" ;;
    analyze) shift; analyze_error "$@" ;;
    create-tool) shift; create_tool "$@" ;;
    install-skill) shift; auto_install_skill "$@" ;;
    reflect)
        shift; recursive_reflect "$@" ;;
    cycle)
        shift; evolve_cycle "$@" ;;
    *)
        echo "AngelKernel Evolution Engine v3 — with Recursive Reflection"
        echo ""
        echo "Usage:"
        echo "  init              — Initialize patterns"
        echo "  analyze <e> <ctx> — Analyze error pattern"
        echo "  create-tool <n> <p>  — Create new tool"
        echo "  install-skill <k> — Auto-install skill"
        echo "  reflect <q> [ctx] — Recursive workspace reflection"
        echo "  cycle <e> <ctx>   — Full evolution cycle"
        ;;
esac
