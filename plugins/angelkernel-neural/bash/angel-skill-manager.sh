#!/bin/bash
set -euo pipefail
# angel-skill-manager — Search, install, and manage skills from skills.sh and GitHub.
#
# Sources:
#   - skills.sh API: https://skills.sh/api (curated skill marketplace)
#   - GitHub: Direct git clone from repositories
#
# Supports automatic skill discovery and installation for AngelKernel

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
SKILLS_DIR="$ANGEL_HOME/skills"
STORE_DIR="$ANGEL_HOME/store"
BIN_DIR="$ANGEL_HOME/bin"

mkdir -p "$SKILLS_DIR" "$STORE_DIR" "$STORE_DIR/skills_cache"

# ============================================================================
# SKILLS.SH INTEGRATION
# ============================================================================

skills_search_skills_sh() {
    local query="$*"
    angel_info "[skill:skills.sh] Searching skills.sh for: $query"
    
    # skills.sh API endpoints
    local results
    results=$(curl -s "https://skills.sh/api/v1/skills?q=$(angel_urlencode "$query")" 2>/dev/null | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for skill in data.get('skills', [])[:10]:
        name = skill.get('name', 'unknown')
        desc = skill.get('description', '')[:80]
        url = skill.get('repo_url', '')
        tags = ','.join(skill.get('tags', []))
        print(f\"{name}|{url}|{desc}|{tags}\")
except:
    pass
" 2>/dev/null)
    
    if [ -z "$results" ]; then
        # Fallback to GitHub search if skills.sh returns nothing
        results=$(github_search_skills "$query")
    fi
    
    echo "$results"
}

skills_install_from_skills_sh() {
    local skill_name="$1"
    angel_info "[skill:skills.sh] Installing from skills.sh: $skill_name"
    
    # Get skill details from API
    local skill_data
    skill_data=$(curl -s "https://skills.sh/api/v1/skills/$skill_name" 2>/dev/null)
    
    if [ -z "$skill_data" ]; then
        # Try to find by search
        skill_data=$(curl -s "https://skills.sh/api/v1/search?q=$(angel_urlencode "$skill_name")" 2>/dev/null | \
            python3 -c "
import json, sys
try:
    for skill in json.load(sys.stdin).get('results', []):
        if skill.get('name', '').lower() == '$skill_name'.lower():
            print(json.dumps(skill))
            break
except: pass
" 2>/dev/null)
    fi
    
    if [ -n "$skill_data" ]; then
        local repo_url
        repo_url=$(echo "$skill_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('repo_url',''))" 2>/dev/null)
        
        if [ -n "$repo_url" ]; then
            # Extract repo from URL
            local repo
            repo=$(echo "$repo_url" | sed 's|https://github.com/||; s|.git$||')
            _install_from_github "$repo" "$skill_name"
            return $?
        fi
    fi
    
    angel_warn "[skill:skills.sh] Skill not found on skills.sh: $skill_name"
    return 1
}

# ============================================================================
# GITHUB INTEGRATION  
# ============================================================================

github_search_skills() {
    local query="$*"
    angel_info "[skill:github] Searching GitHub for: $query"
    
    curl -s "https://api.github.com/search/repositories?q=$query+skill&sort=stars&per_page=10" 2>/dev/null | \
        python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for r in d.get('items', []):
        print(f\"{r['full_name']}|{r['full_name']}|{r.get('description','')[:80]}|{r.get('language','')}\")
except: pass
" 2>/dev/null
}

_install_from_github() {
    local repo="$1"
    local name="${2:-$(echo "$repo" | cut -d'/' -f2)}"
    local target_dir="$SKILLS_DIR/$name"
    
    [ -d "$target_dir" ] && { angel_info "[skill] Already installed: $name"; return 0; }
    
    angel_info "[skill] Installing from GitHub: $repo"
    
    if git clone --depth 1 "https://github.com/$repo.git" "$target_dir" 2>/dev/null; then
        angel_info "[skill] Installed: $name"
        [ -f "$target_dir/install.sh" ] && bash "$target_dir/install.sh" 2>/dev/null
        echo "$repo|$(date +%s)|skills.sh|$name" >> "$STORE_DIR/installed_skills.log"
        return 0
    else
        angel_warn "[skill] Failed to install: $repo"
        rm -rf "$target_dir"
        return 1
    fi
}

# ============================================================================
# SKILL DISCOVERY WITH MULTIPLE SOURCES
# ============================================================================

skills_discover() {
    local query="$*"
    angel_info "[skill] Discovering skills for: $query"
    
    # 1. Search skills.sh first (curated, higher quality)
    local skills_sh_results
    skills_sh_results=$(skills_search_skills_sh "$query")
    
    # 2. Search GitHub as backup
    local github_results
    github_results=$(github_search_skills "$query")
    
    # Combine and deduplicate
    {
        [ -n "$skills_sh_results" ] && echo "$skills_sh_results"
        [ -n "$github_results" ] && echo "$github_results"
    } | awk -F'|' '{seen[$1]=1} END {for (s in seen) print s}'
}

# ============================================================================
# AUTOMATIC SKILL INSTALLATION
# ============================================================================

skills_auto_install() {
    local query="$*"
    angel_info "[skill:auto] Auto-installing skills for: $query"
    
    local skills_to_install
    skills_to_install=$(skills_discover "$query" | head -5)
    
    local installed=0
    while IFS='|' read -r repo desc rest; do
        [ -z "$repo" ] && continue
        # Install (silently succeed if already installed)
        _install_from_github "$repo" 2>/dev/null && installed=$((installed + 1))
    done <<< "$skills_to_install"
    
    angel_info "[skill:auto] Installed $installed skills"
}

# ============================================================================
# LIST AND MANAGE SKILLS
# ============================================================================

skills_list() {
    echo "=== Installed Skills ==="
    echo ""
    if [ -f "$STORE_DIR/installed_skills.log" ]; then
        python3 -c "
import sys
for line in open('$STORE_DIR/installed_skills.log'):
    parts = line.strip().split('|')
    if len(parts) >= 3:
        ts = parts[1]
        source = parts[2] if len(parts) > 2 else 'unknown'
        name = parts[-1] if len(parts) > 3 else parts[0]
        from datetime import datetime
        dt = datetime.fromtimestamp(int(ts)) if ts.isdigit() else 'unknown'
        print(f\"  {name:30s} source={source} installed={dt}\")
" 2>/dev/null || cat "$STORE_DIR/installed_skills.log"
    fi
    echo ""
    echo "=== Skills Directory ==="
    ls -la "$SKILLS_DIR" 2>/dev/null || echo "  (empty)"
}

# ============================================================================
# UTILITIES
# ============================================================================

angel_urlencode() {
    python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1" 2>/dev/null
}

# ============================================================================
# MAIN DISPATCH
# ============================================================================

case "${1:-}" in
    --search|search)
        shift; skills_discover "$@" | while IFS='|' read -r repo desc rest; do
            echo "  $repo — $desc"
        done ;;
    --install|install)
        shift; skills_install_from_skills_sh "$1" ;;
    --search-and-install|search-and-install)
        shift; skills_auto_install "$@" ;;
    --list|list)
        skills_list ;;
    --discover|discover)
        shift; skills_discover "$@" ;;
    --auto-install|auto-install)
        shift; skills_auto_install "$@" ;;
    --from-skills-sh|from-skills-sh)
        shift; skills_install_from_skills_sh "$1" ;;
    --from-github|from-github)
        shift; _install_from_github "$1" ;;
    *)
        echo "AngelKernel Skill Manager v2.0"
        echo ""
        echo "Usage:"
        echo "  angel-skill-manager --search <query>         — Search skills.sh + GitHub"
        echo "  angel-skill-manager --install <name>           — Install from skills.sh"
        echo "  angel-skill-manager --search-and-install <q>   — Auto-install top matches"
        echo "  angel-skill-manager --discover <query>       — Find matching skills"
        echo "  angel-skill-manager --auto-install <query>     — Install without prompt"
        echo "  angel-skill-manager --list                     — List installed skills"
        echo ""
        echo "Sources: skills.sh API, GitHub (public repositories)"
        echo ""
        echo "Examples:"
        echo "  angel-skill-manager --auto-install \"godot game\""
        echo "  angel-skill-manager --install godot-tcg-core"
        ;;
esac