#!/bin/bash
# angel-profile-update.sh — Update AngelKernel agent profile
set -euo pipefail

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
PROFILE_DIR="$ANGEL_HOME/profiles"
AGENT_FILE="$HOME/.config/opencode/agents/angelkernel.md"

echo "=== AngelKernel Profile Update ==="
echo ""

# Gather current system state
VERSION=$(grep "ANGEL_VERSION=" "$ANGEL_HOME/config/angel.conf" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "3.0.0")
SCRIPTS_COUNT=$(ls "$ANGEL_HOME/bin/angel-*.sh" 2>/dev/null | wc -l)
SKILLS_COUNT=$(ls "$ANGEL_HOME/skills/" 2>/dev/null | wc -l)
PLUGINS_COUNT=$(ls "$ANGEL_HOME/plugins/enabled/" 2>/dev/null | wc -l)
EVOS=$(python3 -c "import json; print(json.load(open('$ANGEL_HOME/store/evolution/evolution.json')).get('total_evolutions',0))" 2>/dev/null || echo 0)
L2=$(wc -l < "$ANGEL_HOME/memory/cortex/l2_episodic/log.ndjson" 2>/dev/null || echo 0)
L3=$(wc -l < "$ANGEL_HOME/memory/cortex/l3_semantic/knowledge.jsonl" 2>/dev/null || echo 0)

echo "Current state:"
echo "  Version: $VERSION"
echo "  Scripts: $SCRIPTS_COUNT"
echo "  Skills: $SKILLS_COUNT"
echo "  Plugins: $PLUGINS_COUNT"
echo "  Evolutions: $EVOS"
echo "  Memory: L2=$L2 L3=$L3"
echo ""

# Update the version history in the agent profile
if [ -f "$AGENT_FILE" ]; then
    # Update the version line
    sed -i "s/\*\*v3\.0\*\* (.*)/**v3.0** ($(date +%Y-%m-%d)): Unity pipeline, L1-L4 memory, evolution counters, disk cleanup, log rotation, watchdog retry, integration tests, agent profile optimization/" "$AGENT_FILE" 2>/dev/null || true
    echo "  ✅ Agent profile updated"
else
    warn "  Agent profile not found at $AGENT_FILE"
fi

# Store profile update in evolution DB
python3 -c "
import json
from datetime import datetime, timezone
evo_file = '$ANGEL_HOME/store/evolution/evolution.json'
try:
    with open(evo_file) as f:
        d = json.load(f)
except:
    d = {'version': '3.0.0', 'total_evolutions': 0, 'skills_extracted': 0, 'auto_heals': 0, 'refinements': 0, 'evolution_history': [], 'error_count': 0}
entry = {
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'type': 'refinement',
    'details': 'Profile update: v$VERSION | $SCRIPTS_COUNT scripts | $EVOS evolutions | L2=$L2 L3=$L3'
}
d['evolution_history'].append(entry)
d['evolution_history'] = d['evolution_history'][-100:]
d['refinements'] = d.get('refinements', 0) + 1
with open(evo_file, 'w') as f:
    json.dump(d, f, indent=2)
print('  ✅ Evolution DB updated')
" 2>/dev/null || echo "  ⚠️  Could not update evolution DB"

echo ""
echo "Profile update complete."
