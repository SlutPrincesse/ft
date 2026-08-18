#!/bin/bash
# angel-auto-skill v4.0 — Autonomous Skill Extraction & Management
# Detects patterns → extracts skills → verifies → activates
# Runs as part of the neural cognition pipeline

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="auto-skill"
angel_console_init 2>/dev/null || true

SKILLS_DIR="$ANGEL_HOME/skills"
CORTEX_DIR="$ANGEL_HOME/memory/cortex"
SKILL_DB="$ANGEL_HOME/store/skills.db.json"
PATTERN_LOG="$ANGEL_HOME/memory/neural/patterns.ndjson"
mkdir -p "$SKILLS_DIR" "$(dirname "$SKILL_DB")"

init_skill_db() {
  if [ ! -f "$SKILL_DB" ]; then
    cat > "$SKILL_DB" << 'EOF'
{
  "skills": {},
  "patterns": [],
  "extraction_history": [],
  "stats": { "total_extracted": 0, "total_activated": 0, "total_failed": 0 }
}
EOF
  fi
}
init_skill_db

auto_extract_skill() {
  local domain="$1" content="$2"
  local skill_name
  skill_name=$(echo "$domain" | tr 'A-Z ' 'a-z-' | tr -c 'a-z0-9-' '_')
  skill_name="auto-${skill_name}-$(date +%s | tail -c 5)"
  
  angel_print "evolve" "AUTO-SKILL" "extracting skill='$skill_name' domain='$domain'"
  
  python3 -c "
import json, os, time
db = json.load(open('$SKILL_DB'))
skill_id = '$skill_name'
domain = '$domain'
content = '''$content'''

# Create skill entry
skill = {
    'id': skill_id,
    'domain': domain,
    'trigger_pattern': content[:200],
    'steps': 'Auto-extracted from repeated patterns in: ' + domain,
    'source': 'auto-extraction',
    'extracted_at': time.time(),
    'status': 'pending',  # pending → verified → active
    'execution_count': 0,
    'success_rate': 0.5,
    'version': 1
}

# Check for duplicate
existing_skills = db.get('skills', {})
dup_found = False
for sid, s in existing_skills.items():
    if s.get('domain') == domain and s.get('status') in ('active', 'verified'):
        dup_found = True
        s['version'] = s.get('version', 1) + 1
        s['extracted_at'] = time.time()
        print(f'Updated existing skill: {sid} (v{s[\"version\"]})')
        break

if not dup_found:
    existing_skills[skill_id] = skill
    db['skills'] = existing_skills
    db['stats']['total_extracted'] = db['stats'].get('total_extracted', 0) + 1

db['extraction_history'].append({
    'ts': time.time(),
    'skill': skill_id,
    'domain': domain,
    'status': 'extracted'
})

json.dump(db, open('$SKILL_DB', 'w'), indent=2)
if not dup_found:
    print(f'Extracted new skill: {skill_id}')
" 2>&1 | while read -r msg; do angel_info "[auto-skill] $msg"; done
  
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "skill:extracted" \
    "{\"skill\":\"$skill_name\",\"domain\":\"$domain\"}" "true" 2>/dev/null &
  
  echo "$skill_name"
}

auto_verify_skill() {
  local skill_name="$1"
  angel_print "evolve" "AUTO-SKILL" "verifying: $skill_name"
  
  python3 -c "
import json
db = json.load(open('$SKILL_DB'))
skills = db.get('skills', {})
if '$skill_name' in skills:
    s = skills['$skill_name']
    s['status'] = 'verified'
    s['verified_at'] = $(date +%s)
    db['skills'] = skills
    json.dump(db, open('$SKILL_DB', 'w'), indent=2)
    print(f'Verified skill: $skill_name')
else:
    print(f'Skill not found: $skill_name')
" 2>&1 | while read -r msg; do angel_info "[auto-skill] $msg"; done
  
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "skill:verified" \
    "{\"skill\":\"$skill_name\"}" "true" 2>/dev/null &
}

auto_activate_skill() {
  local skill_name="$1"
  angel_print "evolve" "AUTO-SKILL" "activating: $skill_name"
  
  python3 -c "
import json
db = json.load(open('$SKILL_DB'))
skills = db.get('skills', {})
if '$skill_name' in skills:
    s = skills['$skill_name']
    s['status'] = 'active'
    s['activated_at'] = $(date +%s)
    db['skills'] = skills
    db['stats']['total_activated'] = db['stats'].get('total_activated', 0) + 1
    json.dump(db, open('$SKILL_DB', 'w'), indent=2)
    print(f'Activated skill: $skill_name')
else:
    print(f'Skill not found: $skill_name')
" 2>&1 | while read -r msg; do angel_info "[auto-skill] $msg"; done
  
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "skill:activated" \
    "{\"skill\":\"$skill_name\"}" "true" 2>/dev/null &
}

auto_scan_patterns() {
  angel_print "evolve" "AUTO-SKILL" "scanning for patterns..."
  
  python3 -c "
import json, os
db = json.load(open('$SKILL_DB'))
pattern_log = '$PATTERN_LOG'
patterns = {}

# Read pattern log
if os.path.exists(pattern_log):
    with open(pattern_log) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split('|', 3)
            if len(parts) >= 4:
                source = parts[1]
                content = parts[3]
                key = f'{source}:{content[:50]}'
                if key not in patterns:
                    patterns[key] = {'source': source, 'content': content[:200], 'count': 0}
                patterns[key]['count'] += 1

# Find patterns that repeat 3+ times but haven't been extracted
new_patterns = []
for key, pat in patterns.items():
    if pat['count'] >= 3:
        # Check if already extracted
        already_extracted = False
        for sid, s in db.get('skills', {}).items():
            if s.get('trigger_pattern', '')[:50] in pat['content'] or pat['content'][:50] in s.get('trigger_pattern', ''):
                already_extracted = True
                break
        if not already_extracted:
            new_patterns.append(pat)

print(f'Scanned {len(patterns)} patterns, found {len(new_patterns)} ready for extraction')
for p in new_patterns:
    print(f'  READY: {p[\"source\"]} ({p[\"count\"]}x): {p[\"content\"][:60]}')
" 2>&1
  
  bash "$ANGEL_HOME/bin/angel-hooks.sh" fire "skill:pattern-detected" "{}" "true" 2>/dev/null &
}

auto_list_skills() {
  python3 -c "
import json
db = json.load(open('$SKILL_DB'))
skills = db.get('skills', {})
stats = db.get('stats', {})
print(f'Skills: {len(skills)} total ({stats.get(\"total_activated\",0)} active, {stats.get(\"total_extracted\",0)} extracted)')
print(f'History: {len(db.get(\"extraction_history\",[]))} extractions')
print('')
for sid, s in sorted(skills.items()):
    status_icon = {'active': '✅', 'verified': '🔍', 'pending': '⏳'}.get(s.get('status', ''), '❓')
    print(f'  {status_icon} {sid}: {s.get(\"domain\",\"?\")} (v{s.get(\"version\",1)}, {s.get(\"status\",\"?\")}, rate={s.get(\"success_rate\",0.5)})')
" 2>/dev/null
}

auto_cleanup() {
  angel_print "evolve" "AUTO-SKILL" "cleaning up stale skills..."
  python3 -c "
import json, time
db = json.load(open('$SKILL_DB'))
skills = db.get('skills', {})
now = time.time()
removed = 0
for sid in list(skills.keys()):
    s = skills[sid]
    # Remove pending skills older than 7 days
    if s.get('status') == 'pending' and now - s.get('extracted_at', 0) > 604800:
        del skills[sid]
        removed += 1
    # Remove failed skills
    if s.get('status') == 'failed' and now - s.get('extracted_at', 0) > 86400:
        del skills[sid]
        removed += 1
db['skills'] = skills
json.dump(db, open('$SKILL_DB', 'w'), indent=2)
print(f'Cleaned {removed} stale skills, {len(skills)} remaining')
" 2>&1
}

case "${1:-}" in
  --extract)
    shift; auto_extract_skill "$1" "$2" ;;
  --verify)
    shift; auto_verify_skill "$1" ;;
  --activate)
    shift; auto_activate_skill "$1" ;;
  --scan)
    auto_scan_patterns ;;
  --list)
    auto_list_skills ;;
  --cleanup)
    auto_cleanup ;;
  --pulse)
    auto_scan_patterns
    auto_cleanup ;;
  *)
    echo "AngelKernel Auto-Skill Engine v4.0"
    echo "Usage: angel-auto-skill.sh {--extract|--verify|--activate|--scan|--list|--cleanup|--pulse}"
    ;;
esac
