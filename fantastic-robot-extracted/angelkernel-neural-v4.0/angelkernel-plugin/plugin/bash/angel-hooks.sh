#!/bin/bash
# angel-hooks — Event-driven hook system for the AngelKernel.
#
# Events:
#   system:init      — System startup
#   system:shutdown  — System shutdown  
#   ralph:reason     — Before reasoning phase
#   ralph:act        — Before action phase
#   ralph:learn      — Before learning phase
#   ralph:patch      — Before patching phase
#   ralph:hook       — Before hook phase
#   ralph:complete   — After RALPH loop completes
#   memory:store     — Before memory store
#   memory:recall    — Before memory recall
#   error:occurred   — On error
#   skill:extracted  — When a skill is extracted
#   plugin:enabled   — When a plugin is enabled
#   plugin:disabled  — When a plugin is disabled
#   pulse:tick       — On pulse daemon tick
# 
# Hooks can be:
#   - Scripts in $ANGEL_HOME/hooks/<event>.sh or <event>/*.sh
#   - Plugin hooks
#   - Custom user hooks
#
# Each hook receives: event_name, payload (JSON), timestamp

ANGEL_SCRIPT="hooks"
ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true

HOOKS_DIR="$ANGEL_HOME/hooks"
mkdir -p "$HOOKS_DIR"

# Registry of all registered hooks
REGISTRY_FILE="$ANGEL_HOME/store/hook_registry.json"
[ ! -f "$REGISTRY_FILE" ] && echo '{"hooks":{}}' > "$REGISTRY_FILE"

# === Register a hook ===
hook_register() {
  local event="$1" script="$2" priority="${3:-50}" description="${4:-}"
  
  python3 -c "
import json
d = json.load(open('$REGISTRY_FILE'))
if '$event' not in d['hooks']:
    d['hooks']['$event'] = []
d['hooks']['$event'].append({
    'script': '$script',
    'priority': $priority,
    'description': '${description:-Registered hook}',
    'registered_at': $(date +%s)
})
# Sort by priority
d['hooks']['$event'].sort(key=lambda x: x.get('priority', 50))
json.dump(d, open('$REGISTRY_FILE', 'w'))
" 2>/dev/null
  
  angel_info "[hooks] Registered '$script' for event '$event' (priority $priority)"
}

# === Unregister a hook ===
hook_unregister() {
  local event="$1" script="$2"
  
  python3 -c "
import json
d = json.load(open('$REGISTRY_FILE'))
if '$event' in d['hooks']:
    d['hooks']['$event'] = [h for h in d['hooks']['$event'] if h.get('script') != '$script']
    if not d['hooks']['$event']:
        del d['hooks']['$event']
json.dump(d, open('$REGISTRY_FILE', 'w'))
" 2>/dev/null
  
  angel_info "[hooks] Unregistered '$script' from event '$event'"
}

# === Fire an event (execute all hooks for this event) ===
hook_fire() {
  local event="$1" payload="${2:-}" async="${3:-true}"
  [ -z "$payload" ] && payload="{}"
  
  angel_print "hook" "FIRE" "event=$event async=$async"
  
  # Add system info to payload
  local full_payload
  full_payload=$(python3 -c "
import json, os
payload = json.loads('''$payload''')
payload['event'] = '$event'
payload['ts'] = $(date +%s)
payload['iso'] = '$(angel_iso)'
payload['host'] = '$(hostname 2>/dev/null || echo unknown)'
payload['depth'] = ${ANGEL_DEPTH:-0}
print(json.dumps(payload))
" 2>/dev/null)
  
  angel_info "[hooks] Firing event: $event"
  angel_metric "hook.fired" 1 "{\"event\":\"$event\"}"
  
  # Collect all scripts to run
  local scripts=()
  
  # Convert event name for filesystem: support both colon (event:name) and dash (event-name) naming
  local event_dash
  event_dash=$(echo "$event" | tr ':' '-')
  
  # 1. From file system: direct <event>.sh (supports both : and - naming)
  [ -f "$HOOKS_DIR/${event}.sh" ] && scripts+=("$HOOKS_DIR/${event}.sh")
  [ -f "$HOOKS_DIR/${event_dash}.sh" ] && scripts+=("$HOOKS_DIR/${event_dash}.sh")
  
  # 2. From file system: <event>/*.sh directory (supports both : and - naming)
  if [ -d "$HOOKS_DIR/$event" ]; then
    for script in "$HOOKS_DIR/$event"/*.sh; do
      [ -f "$script" ] && scripts+=("$script")
    done
  fi
  if [ -d "$HOOKS_DIR/$event_dash" ]; then
    for script in "$HOOKS_DIR/$event_dash"/*.sh; do
      [ -f "$script" ] && scripts+=("$script")
    done
  fi
  
  # 3. From registry
  local registered_scripts
  registered_scripts=$(python3 -c "
import json
d = json.load(open('$REGISTRY_FILE'))
hooks = d['hooks'].get('$event', [])
for h in hooks:
    print(h.get('script', ''))
" 2>/dev/null)
  while IFS= read -r script; do
    [ -n "$script" ] && [ -f "$script" ] && scripts+=("$script")
  done <<< "$registered_scripts"
  
  # 4. From enabled plugins (supports both : and - naming)
  for plugin_link in "$ANGEL_HOME/plugins/enabled"/*; do
    [ -L "$plugin_link" ] || continue
    local plugin_hook="$plugin_link/hooks/${event}.sh"
    local plugin_hook_dash="$plugin_link/hooks/${event_dash}.sh"
    [ -f "$plugin_hook" ] && scripts+=("$plugin_hook")
    [ -f "$plugin_hook_dash" ] && scripts+=("$plugin_hook_dash")
  done
  
  # 5. Global event hook (catches all events)
  [ -f "$HOOKS_DIR/all.sh" ] && scripts+=("$HOOKS_DIR/all.sh")
  
  # Remove duplicates
  scripts=($(echo "${scripts[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  
  if [ ${#scripts[@]} -eq 0 ]; then
    return 0
  fi
  
  angel_info "[hooks] Running ${#scripts[@]} hook(s) for '$event'"
  
  # Execute hooks
  for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
      if [ "$async" = "true" ]; then
        # Fire and forget
        (bash "$script" "$event" "$full_payload" "$(angel_iso)" 2>/dev/null) &
      else
        # Synchronous
        bash "$script" "$event" "$full_payload" "$(angel_iso)" 2>/dev/null || true
      fi
    fi
  done
}

# === List hooks ===
hook_list() {
  echo "=== AngelKernel Hook Registry ==="
  echo ""
  
  # File system hooks
  echo "File System Hooks:"
  for f in "$HOOKS_DIR"/*.sh; do
    [ -f "$f" ] && echo "  $(basename "$f" .sh)"
  done
  for d in "$HOOKS_DIR"/*/; do
    [ -d "$d" ] || continue
    local event
    event=$(basename "$d")
    local count
    count=$(ls "$d"/*.sh 2>/dev/null | wc -l)
    [ "$count" -gt 0 ] && echo "  $event ($count hooks)"
  done
  
  echo ""
  echo "Registered Hooks:"
  python3 -c "
import json
d = json.load(open('$REGISTRY_FILE'))
for event, hooks in d['hooks'].items():
    for h in hooks:
        print(f'  {event} → {h[\"script\"]} (priority {h[\"priority\"]})')
" 2>/dev/null
  
  echo ""
  echo "Plugin Hooks:"
  for link in "$ANGEL_HOME/plugins/enabled"/*; do
    [ -L "$link" ] || continue
    local plugin
    plugin=$(basename "$link")
    local hook_count
    hook_count=$(ls "$link/hooks"/*.sh 2>/dev/null | wc -l)
    [ "$hook_count" -gt 0 ] && echo "  $plugin: $hook_count hook(s)"
  done
}

# === Fire a lifecycle event (pre/post around an action) ===
hook_lifecycle() {
  local phase="$1" action="$2" payload="${3:-}"
  [ -z "$payload" ] && payload="{}"
  hook_fire "${phase}:${action}" "$payload" "true"
}

case "${1:-}" in
  register)
    shift; hook_register "$1" "$2" "${3:-50}" "${4:-}" ;;
  unregister)
    shift; hook_unregister "$1" "$2" ;;
  fire)
    shift; hook_fire "$1" "$2" "${3:-true}" ;;
  list)
    hook_list ;;
  lifecycle)
    shift; hook_lifecycle "$1" "$2" "$3" ;;
  *)
    echo "Usage: angel-hooks.sh {register|unregister|fire|list|lifecycle} [args]"
    ;;
esac
