#!/bin/bash
# angel-cortex — Memory Cortex: Multi-tier persistent memory system
# 
# Tiers:
#   L1 - Working Memory (session context, ephemeral)
#   L2 - Episodic Memory (interactions with importance weights)
#   L3 - Semantic Memory (extracted knowledge, patterns, concepts)
#   L4 - Procedural Memory (skills, workflows, recipes)
#
# Features:
#   - Importance-weighted retrieval
#   - Automatic consolidation (L2→L3→L4)
#   - Forgetting curve (decay unimportant memories)
#   - Cross-session recall
#   - Memory search with relevance scoring

ANGEL_SCRIPT="cortex"
ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true

CORTEX_DIR="$ANGEL_HOME/memory/cortex"
mkdir -p "$CORTEX_DIR"/{l1_working,l2_episodic,l3_semantic,l4_procedural,index}

# === L1: Working Memory (current session, lost on shutdown) ===
cortex_l1_store() {
  local key="$1" value="$2" ttl="${3:-3600}"
  local expires=$(( $(date +%s) + ttl ))
  echo "$value" > "$CORTEX_DIR/l1_working/$key"
  echo "$expires" > "$CORTEX_DIR/l1_working/${key}.ttl"
  angel_print "memory" "L1 STORE" "key=$key ttl=${ttl}s"
}

cortex_l1_get() {
  local key="$1"
  local ttl_file="$CORTEX_DIR/l1_working/${key}.ttl"
  local val_file="$CORTEX_DIR/l1_working/$key"
  if [ -f "$ttl_file" ] && [ -f "$val_file" ]; then
    local expires
    expires=$(cat "$ttl_file")
    [ "$(date +%s)" -lt "$expires" ] && cat "$val_file" && return 0
    rm -f "$val_file" "$ttl_file"
  fi
  return 1
}

cortex_l1_clear() {
  rm -rf "$CORTEX_DIR/l1_working"
  mkdir -p "$CORTEX_DIR/l1_working"
  angel_info "[cortex:L1] Cleared working memory"
}

# === L2: Episodic Memory (interaction history) ===
cortex_l2_store() {
  local content="$1" importance="${2:-0.5}" source="${3:-system}" metadata="${4:-}"
  [ -z "$metadata" ] && metadata="{}"
  local id="EP-$(date +%s)-$$"
  local iso
  iso=$(angel_iso)
  local ts
  ts=$(date +%s)
  # Pass data to Python via argv to avoid shell escaping issues
  local entry
  entry=$(python3 -c "
import json, sys
content = sys.argv[1]
metadata_raw = sys.argv[2]
try:
    metadata = json.loads(metadata_raw) if metadata_raw.strip() else {}
except:
    metadata = {}
entry = {
    'id': sys.argv[3],
    'ts': int(sys.argv[4]),
    'iso': sys.argv[5],
    'content': content.strip(),
    'importance': float(sys.argv[6]),
    'source': sys.argv[7],
    'access_count': 0,
    'metadata': metadata
}
print(json.dumps(entry, separators=(',', ':')))
" "$content" "$metadata" "$id" "$ts" "$iso" "$importance" "$source" 2>/dev/null)
  echo "$entry" >> "$CORTEX_DIR/l2_episodic/log.ndjson"
  # Update index
  echo "$id|$importance|$(date +%s)|$source" >> "$CORTEX_DIR/index/episodic.idx"
  angel_print "memory" "L2 STORE" "id=$id importance=$importance source=$source"
  # Trigger consolidation if episodic memory is large
  local count
  count=$(wc -l < "$CORTEX_DIR/l2_episodic/log.ndjson" 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ] && [ $((count % 10)) -eq 0 ]; then
    cortex_consolidate &
  fi
  echo "$id"
}

cortex_l2_search() {
  local query="$1" limit="${2:-10}" min_importance="${3:-0.0}"
  angel_print "memory" "L2 SEARCH" "query='${query:0:60}' limit=$limit min_imp=$min_importance"
  python3 -c "
import json, sys, math

query_lower = '$query'.lower()
query_words = set(query_lower.split())
results = []
try:
    with open('$CORTEX_DIR/l2_episodic/log.ndjson') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
            except:
                continue
            if e.get('importance', 0) < $min_importance:
                continue
            content = e.get('content', '')
            content_lower = content.lower()
            # TF-like relevance scoring
            score = 0.0
            for w in query_words:
                if w in content_lower:
                    score += 1.0 / len(query_words)
            score *= e.get('importance', 0.5)
            # Recency bonus
            age = $(date +%s) - e.get('ts', 0)
            recency = max(0, 1.0 - age / 864000.0)  # 10 day half-life
            score += recency * 0.3
            results.append((score, e))
    results.sort(key=lambda x: -x[0])
    for score, e in results[:$limit]:
        e['relevance_score'] = round(score, 3)
        print(json.dumps(e))
except FileNotFoundError:
    pass
" 2>/dev/null
}

# === L3: Semantic Memory (extracted knowledge, concepts) ===
cortex_l3_store() {
  local concept="$1" content="$2" confidence="${3:-0.5}" source_episode="${4:-unknown}"
  local id="SM-$(date +%s)-$$"
  local ts
  ts=$(date +%s)
  angel_print "memory" "L3 STORE" "concept='${concept:0:40}' confidence=$confidence"
  # Pass data via argv to avoid shell escaping issues
  local entry
  entry=$(python3 -c "
import json, sys
entry = {
    'id': sys.argv[1],
    'concept': sys.argv[2].strip(),
    'content': sys.argv[3].strip(),
    'confidence': float(sys.argv[4]),
    'ts': int(sys.argv[5]),
    'source_episode': sys.argv[6],
    'access_count': 0
}
print(json.dumps(entry, separators=(',', ':')))
" "$id" "$concept" "$content" "$confidence" "$ts" "$source_episode" 2>/dev/null)
  # Dedup: check if concept already exists
  local found_old
  found_old=$(python3 -c "
import json
try:
    with open('$CORTEX_DIR/l3_semantic/knowledge.jsonl') as f:
        for line in f:
            try:
                e = json.loads(line)
                if e.get('concept','').lower() == '$concept'.lower():
                    print(e.get('confidence', 0))
                    break
            except: pass
except: pass
" 2>/dev/null)
  if [ -n "$found_old" ]; then
    # Merge: use max confidence, append content
    python3 -c "
import json
entries = []
with open('$CORTEX_DIR/l3_semantic/knowledge.jsonl') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
            if e.get('concept','').lower() != '$concept'.lower():
                entries.append(e)
        except: pass
entries.append(json.loads('''$entry'''))
with open('$CORTEX_DIR/l3_semantic/knowledge.jsonl', 'w') as f:
    for e in entries:
        f.write(json.dumps(e, separators=(',', ':')) + '\n')
" 2>/dev/null
  else
    echo "$entry" >> "$CORTEX_DIR/l3_semantic/knowledge.jsonl"
  fi
  echo "$id"
}

cortex_l3_search() {
  local query="$1" limit="${2:-5}"
  angel_print "memory" "L3 SEARCH" "query='${query:0:60}' limit=$limit"
  python3 -c "
import json, sys

query_lower = '$query'.lower()
query_words = set(query_lower.split())
results = []
try:
    with open('$CORTEX_DIR/l3_semantic/knowledge.jsonl') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
            except: continue
            concept = e.get('concept', '').lower()
            content = e.get('content', '').lower()
            score = 0.0
            for w in query_words:
                if w in concept: score += 0.8
                if w in content: score += 0.4
            score *= e.get('confidence', 0.5)
            results.append((score, e))
    results.sort(key=lambda x: -x[0])
    for score, e in results[:$limit]:
        e['relevance_score'] = round(score, 3)
        print(json.dumps(e))
except FileNotFoundError:
    pass
" 2>/dev/null
}

# === L4: Procedural Memory (skills, workflows) ===
cortex_l4_store() {
  local skill_name="$1" trigger_pattern="$2" steps="$3" success_rate="${4:-1.0}"
  local id="PM-$(date +%s)-$$"
  local ts
  ts=$(date +%s)
  angel_print "memory" "L4 STORE" "skill='$skill_name' trigger='${trigger_pattern:0:40}'"
  # Pass data via argv to avoid shell escaping issues
  local entry
  entry=$(python3 -c "
import json, sys
entry = {
    'id': sys.argv[1],
    'skill_name': sys.argv[2].strip(),
    'trigger_pattern': sys.argv[3].strip(),
    'steps': sys.argv[4].strip(),
    'success_rate': float(sys.argv[5]),
    'ts': int(sys.argv[6]),
    'execution_count': 1
}
print(json.dumps(entry, separators=(',', ':')))
" "$id" "$skill_name" "$trigger_pattern" "$steps" "$success_rate" "$ts" 2>/dev/null)
  # Check for existing skill with same name
  local found
  found=$(python3 -c "
import json
try:
    with open('$CORTEX_DIR/l4_procedural/skills.jsonl') as f:
        for line in f:
            try:
                e = json.loads(line)
                if e.get('skill_name','').lower() == '$skill_name'.lower():
                    print('found')
                    break
            except: pass
except: pass
" 2>/dev/null)
  if [ -n "$found" ]; then
    # Update: increment count, average success rate
    python3 -c "
import json
entries = []
with open('$CORTEX_DIR/l4_procedural/skills.jsonl') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
            if e.get('skill_name','').lower() == '$skill_name'.lower():
                e['execution_count'] = e.get('execution_count', 0) + 1
                e['success_rate'] = (e.get('success_rate', 0) * (e['execution_count'] - 1) + $success_rate) / e['execution_count']
                e['ts'] = $(date +%s)
            entries.append(e)
        except: pass
with open('$CORTEX_DIR/l4_procedural/skills.jsonl', 'w') as f:
    for e in entries:
        f.write(json.dumps(e, separators=(',', ':')) + '\n')
" 2>/dev/null
  else
    echo "$entry" >> "$CORTEX_DIR/l4_procedural/skills.jsonl"
  fi
  # Also create skill file in skills dir
  local skill_dir="$ANGEL_HOME/skills/$skill_name"
  mkdir -p "$skill_dir"
  cat > "$skill_dir/SKILL.md" << SKILLEOF
# $skill_name

Auto-generated by AngelKernel Memory Cortex (L4: Procedural Memory)

## Trigger
$trigger_pattern

## Steps
$steps

## Metadata
- Created: $(angel_iso)
- Success Rate: $success_rate
- Executions: 1
SKILLEOF
  echo "$id"
}

cortex_l4_search() {
  local query="$1" limit="${2:-5}"
  angel_print "memory" "L4 SEARCH" "query='${query:0:60}' limit=$limit"
  python3 -c "
import json, sys

query_lower = '$query'.lower()
query_words = set(query_lower.split())
results = []
try:
    with open('$CORTEX_DIR/l4_procedural/skills.jsonl') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
            except: continue
            name = e.get('skill_name', '').lower()
            trigger = e.get('trigger_pattern', '').lower()
            score = 0.0
            for w in query_words:
                if w in name: score += 1.0
                if w in trigger: score += 0.6
            score *= e.get('success_rate', 0.5)
            score *= min(e.get('execution_count', 1) / 5.0, 1.0)  # confidence from repetition
            results.append((score, e))
    results.sort(key=lambda x: -x[0])
    for score, e in results[:$limit]:
        e['relevance_score'] = round(score, 3)
        print(json.dumps(e))
except FileNotFoundError:
    pass
" 2>/dev/null
}

# === Unified Recall (searches all tiers) ===
cortex_recall() {
  local query="$1" limit="${2:-5}"
  angel_print "memory" "RECALL ALL TIERS" "query='${query:0:60}' limit=$limit"
  echo "=== Memory Cortex Recall: '$query' ==="
  echo ""
  echo "--- L2: Episodic ---"
  cortex_l2_search "$query" "$limit" 2>/dev/null | head -$limit
  echo ""
  echo "--- L3: Semantic ---"
  cortex_l3_search "$query" "$limit" 2>/dev/null | head -$limit
  echo ""
  echo "--- L4: Procedural ---"
  cortex_l4_search "$query" "$limit" 2>/dev/null | head -$limit
}

# === Store with automatic importance estimation ===
cortex_store() {
  local content="$1" source="${2:-system}" metadata="${3:-}"
  [ -z "$metadata" ] && metadata="{}"
  angel_print "memory" "STORE" "source=$source content='${content:0:60}'"
  # Estimate importance based on content features
  local importance=0.5
  # Longer content = potentially more important
  local len
  len=$(echo "$content" | wc -c | xargs)
  [ "$len" -gt 200 ] && importance=$(python3 -c "print(min(1.0, $importance + 0.1))")
  [ "$len" -gt 1000 ] && importance=$(python3 -c "print(min(1.0, $importance + 0.1))")
  # Error/keywords boost importance
  if echo "$content" | grep -qiE "error|fail|bug|critical|important|learn|patent|novel"; then
    importance=$(python3 -c "print(min(1.0, $importance + 0.2))")
  fi
  # Success/completion keywords
  if echo "$content" | grep -qiE "solved|fixed|completed|success|optimized"; then
    importance=$(python3 -c "print(min(1.0, $importance + 0.15))")
  fi
  cortex_l2_store "$content" "$importance" "$source" "$metadata"
  # Also try to extract semantic knowledge
  if [ "$(echo "$content" | wc -w)" -gt 20 ]; then
    cortex_extract_knowledge "$content" "$source" &
  fi
}

# === Extract semantic knowledge from content ===
cortex_extract_knowledge() {
  local content="$1" source="$2"
  # Extract concept-key phrases (simple heuristic: repeated n-grams)
  python3 -c "
import re, json
from collections import Counter

content = '''$content'''
# Simple concept extraction: find capitalized phrases and repeated patterns
words = re.findall(r'[A-Z][a-z]+(?:\s+[a-z]+){0,3}', content)
phrases = [' '.join(ws) for ws in [w.split() for w in words]]
# Find 2-3 word patterns that appear
trigrams = Counter()
for i in range(len(words) - 1):
    trigrams[' '.join(words[i:i+2])] += 1
for phrase, count in trigrams.most_common(5):
    if count >= 2 and len(phrase) > 5:
        print(json.dumps({'concept': phrase, 'count': count}))
" 2>/dev/null | while read -r line; do
    local concept
    concept=$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('concept',''))")
    [ -n "$concept" ] && cortex_l3_store "$concept" "$content" 0.3 "$source"
  done
}

# === Consolidation: L2→L3 (summarize episodes into knowledge) ===
cortex_consolidate() {
  angel_print "memory" "CONSOLIDATE" "L2→L3 semantic extraction"
  angel_info "[cortex] Starting memory consolidation..."
  
  ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}" python3 << 'PYEOF'
import json, os, re
from collections import defaultdict, Counter
from datetime import datetime

cortex_dir = os.environ.get('ANGEL_HOME', os.path.expanduser('~/.angelkernel')) + '/memory/cortex'
l2_file = f'{cortex_dir}/l2_episodic/log.ndjson'
l3_file = f'{cortex_dir}/l3_semantic/knowledge.jsonl'

# Read all L2 episodes
episodes = []
try:
    with open(l2_file) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
                if e.get('importance', 0) > 0.3:
                    episodes.append(e)
            except: pass
except FileNotFoundError:
    print('No L2 episodes found')
    exit(0)

if len(episodes) < 3:
    print(f'Not enough episodes to consolidate ({len(episodes)} < 3)')
    exit(0)

# Read existing L3 knowledge to avoid duplicates
existing_concepts = {}
try:
    with open(l3_file) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
                concept = e.get('concept', '').lower()
                if concept:
                    existing_concepts[concept] = e
            except: pass
except FileNotFoundError:
    pass

# Cluster episodes by keyword overlap
clusters = []
used = set()
for i, e1 in enumerate(episodes):
    if i in used: continue
    cluster = [i]
    used.add(i)
    words1 = set(w.lower() for w in re.findall(r'\b[a-z]{4,}\b', e1.get('content', '')))
    for j, e2 in enumerate(episodes):
        if j in used: continue
        words2 = set(w.lower() for w in re.findall(r'\b[a-z]{4,}\b', e2.get('content', '')))
        overlap = len(words1 & words2)
        if overlap >= 2:
            cluster.append(j)
            used.add(j)
    if len(cluster) >= 2:
        clusters.append(cluster)

# For each cluster, create a proper semantic concept
new_concepts = 0
updated_concepts = 0
for cluster in clusters:
    cluster_episodes = [episodes[i] for i in cluster]
    
    # Extract key terms from the cluster
    all_text = ' '.join(e.get('content', '') for e in cluster_episodes)
    words = re.findall(r'\b[a-z]{4,}\b', all_text.lower())
    stop_words = {'this', 'that', 'with', 'from', 'have', 'been', 'were', 'will', 'would', 'could', 'should', 'about', 'their', 'there', 'which', 'when', 'what', 'your', 'more', 'some', 'than', 'them', 'then', 'also', 'just', 'only', 'very', 'much', 'such', 'into', 'over', 'after', 'before'}
    filtered = [w for w in words if w not in stop_words]
    word_freq = Counter(filtered)
    top_terms = [w for w, c in word_freq.most_common(3)]
    
    if not top_terms:
        continue
    
    concept = ' '.join(top_terms)
    concept_lower = concept.lower()
    
    # Create a proper summary (not just concatenation)
    cluster_episodes.sort(key=lambda e: e.get('importance', 0.5), reverse=True)
    
    # Deduplicate: only include unique content
    unique_contents = []
    for e in cluster_episodes[:5]:
        c = e.get('content', '')[:200]
        is_dup = False
        for u in unique_contents:
            if len(set(c.lower().split()) & set(u.lower().split())) / max(len(set(c.lower().split())), 1) > 0.7:
                is_dup = True
                break
        if not is_dup:
            unique_contents.append(c)
    
    summary = ' | '.join(unique_contents) if unique_contents else cluster_episodes[0].get('content', '')[:300]
    avg_importance = sum(e.get('importance', 0.5) for e in cluster_episodes) / len(cluster_episodes)
    confidence = min(0.95, avg_importance * (1 + len(cluster_episodes) * 0.05))
    
    if concept_lower in existing_concepts:
        existing = existing_concepts[concept_lower]
        existing['confidence'] = max(existing.get('confidence', 0), confidence)
        existing['access_count'] = existing.get('access_count', 0) + 1
        existing['ts'] = int(datetime.now().timestamp())
        if summary not in existing.get('content', ''):
            existing['content'] = existing['content'][:500] + ' | ' + summary[:200]
        updated_concepts += 1
    else:
        entry = {
            'id': f'SM-CONSOLIDATED-{int(datetime.now().timestamp())}-{cluster[0]}',
            'concept': concept,
            'content': summary[:500],
            'confidence': round(confidence, 2),
            'ts': int(datetime.now().timestamp()),
            'source_episode': 'consolidated',
            'access_count': 0,
            'cluster_size': len(cluster_episodes)
        }
        existing_concepts[concept_lower] = entry
        new_concepts += 1

# Write back all concepts
with open(l3_file, 'w') as f:
    for concept in existing_concepts.values():
        f.write(json.dumps(concept, separators=(',', ':')) + '\n')

print(f'Consolidation: {new_concepts} new, {updated_concepts} updated, {len(existing_concepts)} total')

PYEOF
  
  angel_info "[cortex] Consolidation complete"
}


# === Forget: remove low-importance, old memories ===
cortex_forget() {
  local threshold_days="${1:-30}"
  local threshold_importance="${2:-0.1}"
  local cutoff=$(( $(date +%s) - threshold_days * 86400 ))
  angel_print "memory" "FORGET" "threshold_days=$threshold_days threshold_imp=$threshold_importance"
  
  # L2: remove old, low-importance episodes
  python3 -c "
import json
entries = []
removed = 0
try:
    with open('$CORTEX_DIR/l2_episodic/log.ndjson') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
            except: continue
            if e.get('ts', 0) < $cutoff and e.get('importance', 0) < $threshold_importance:
                removed += 1
            else:
                entries.append(e)
    with open('$CORTEX_DIR/l2_episodic/log.ndjson', 'w') as f:
        for e in entries:
            f.write(json.dumps(e) + '\n')
    print(f'Removed {removed} low-importance memories, kept {len(entries)}')
" 2>&1
}

# === Stats ===
cortex_stats() {
  echo "=== Memory Cortex Stats ==="
  echo "L1 Working:  $(find "$CORTEX_DIR/l1_working" -type f ! -name '*.ttl' 2>/dev/null | wc -l) entries"
  echo "L2 Episodic: $(wc -l < "$CORTEX_DIR/l2_episodic/log.ndjson" 2>/dev/null || echo 0) episodes"
  echo "L3 Semantic: $(wc -l < "$CORTEX_DIR/l3_semantic/knowledge.jsonl" 2>/dev/null || echo 0) concepts"
  echo "L4 Procedural: $(wc -l < "$CORTEX_DIR/l4_procedural/skills.jsonl" 2>/dev/null || echo 0) skills"
}

# === Query interface ===
case "${1:-}" in
  store)
    shift; _m="${3:-}"; [ -z "$_m" ] && _m="{}"; cortex_store "$1" "${2:-system}" "$_m" ;;
  recall)
    shift; cortex_recall "$1" "${2:-5}" ;;
  l1-store)
    shift; cortex_l1_store "$1" "$2" "${3:-3600}" ;;
  l1-get)
    shift; cortex_l1_get "$1" ;;
  l1-clear)
    cortex_l1_clear ;;
  l2-search)
    shift; cortex_l2_search "$1" "${2:-10}" "${3:-0.0}" ;;
  l3-search)
    shift; cortex_l3_search "$1" "${2:-5}" ;;
  l4-search)
    shift; cortex_l4_search "$1" "${2:-5}" ;;
  l4-store)
    shift; cortex_l4_store "$1" "$2" "$3" "${4:-1.0}" ;;
  consolidate)
    cortex_consolidate ;;
  forget)
    shift; cortex_forget "$1" "$2" ;;
  stats)
    cortex_stats ;;
  *)
    echo "Usage: angel-cortex {store|recall|l1-store|l1-get|l2-search|l3-search|l4-search|l4-store|consolidate|forget|stats} [args]"
    ;;
esac
