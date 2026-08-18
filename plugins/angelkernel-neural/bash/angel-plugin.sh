#!/bin/bash
set -euo pipefail
# angel-plugin — Plugin lifecycle management system.
#
# Lifecycle: discover → validate → install → enable → run → disable → uninstall
# 
# Each plugin is a directory with plugin.json manifest:
# {
#   "name": "my-plugin",
#   "version": "1.0.0",
#   "description": "...",
#   "hooks": ["pre-exec", "post-exec", "on-error"],
#   "commands": [{"name": "my-cmd", "script": "script.sh"}],
#   "dependencies": [],
#   "permissions": ["bash", "network", "files"]
# }

ANGEL_SCRIPT="plugin"
ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true

PLUGINS_DIR="$ANGEL_HOME/plugins"
ENABLED_DIR="$ANGEL_HOME/plugins/enabled"
AVAILABLE_DIR="$ANGEL_HOME/plugins/available"
METADATA_FILE="$ANGEL_HOME/store/plugin_manifest.json"
mkdir -p "$PLUGINS_DIR" "$ENABLED_DIR" "$AVAILABLE_DIR"

[ ! -f "$METADATA_FILE" ] && echo '{}' > "$METADATA_FILE"

# === Discover plugins ===
plugin_discover() {
  angel_info "[plugin] Discovering available plugins..."
  local count=0
  for dir in "$AVAILABLE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local manifest="$dir/plugin.json"
    if [ -f "$manifest" ]; then
      local name
      name=$(python3 -c "import json; print(json.load(open('$manifest')).get('name','unknown'))" 2>/dev/null)
      echo "  [DETECTED] $name ($(basename "$dir"))"
      count=$((count + 1))
    fi
  done
  echo "  Total: $count plugins"
}

# === Validate a plugin manifest ===
plugin_validate() {
  local plugin_dir="$1"
  local manifest="$plugin_dir/plugin.json"
  
  if [ ! -f "$manifest" ]; then
    angel_error "[plugin] No plugin.json in $plugin_dir"
    return 1
  fi
  
  python3 -c "
import json, sys
try:
    d = json.load(open('$manifest'))
    required = ['name', 'version']
    for field in required:
        if field not in d:
            print(f'Missing required field: {field}')
            sys.exit(1)
    if d.get('version', '').count('.') != 2:
        print(f'Invalid version: {d.get(\"version\")}')
        sys.exit(1)
    print(f'Valid: {d[\"name\"]} v{d[\"version\"]}')
except json.JSONDecodeError as e:
    print(f'Invalid JSON: {e}')
    sys.exit(1)
" 2>/dev/null
}

# === Install a plugin ===
plugin_install() {
  local source="$1"
  local plugin_name
  
  if [ -d "$source" ] && [ -f "$source/plugin.json" ]; then
    # Local directory
    plugin_name=$(python3 -c "import json; print(json.load(open('$source/plugin.json')).get('name','unknown'))" 2>/dev/null)
    local target="$AVAILABLE_DIR/$plugin_name"
    if [ -d "$target" ]; then
      angel_warn "[plugin] Already installed: $plugin_name"
      return 1
    fi
    cp -r "$source" "$target"
    angel_info "[plugin] Installed $plugin_name from $source"
  elif [[ "$source" =~ ^https?:// ]]; then
    # Remote URL (git repo or tarball)
    angel_info "[plugin] Downloading from $source..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    if git clone --depth 1 "$source" "$tmp_dir/plugin" 2>/dev/null; then
      if [ -f "$tmp_dir/plugin/plugin.json" ]; then
        plugin_name=$(python3 -c "import json; print(json.load(open('$tmp_dir/plugin/plugin.json')).get('name','unknown'))" 2>/dev/null)
        mv "$tmp_dir/plugin" "$AVAILABLE_DIR/$plugin_name"
        angel_info "[plugin] Installed $plugin_name from $source"
      else
        angel_error "[plugin] No plugin.json in repository"
        rm -rf "$tmp_dir"
        return 1
      fi
    else
      angel_error "[plugin] Failed to clone $source"
      rm -rf "$tmp_dir"
      return 1
    fi
    rm -rf "$tmp_dir"
  else
    angel_error "[plugin] Source not found: $source"
    return 1
  fi
  
  # Validate after install
  plugin_validate "$AVAILABLE_DIR/$plugin_name" && {
    # Run install hook if present
    [ -f "$AVAILABLE_DIR/$plugin_name/install.sh" ] && {
      angel_info "[plugin] Running install script for $plugin_name..."
      bash "$AVAILABLE_DIR/$plugin_name/install.sh" 2>/dev/null
    }
    # Update manifest
    python3 -c "
import json
d = json.load(open('$METADATA_FILE'))
d['$plugin_name'] = {'status': 'installed', 'installed_at': $(date +%s)}
json.dump(d, open('$METADATA_FILE', 'w'))
" 2>/dev/null
  }
}

# === Enable a plugin ===
plugin_enable() {
  local plugin_name="$1"
  local plugin_dir="$AVAILABLE_DIR/$plugin_name"
  
  if [ ! -d "$plugin_dir" ]; then
    angel_print "plugin" "ENABLE FAIL" "plugin=$plugin_name not found"
    angel_error "[plugin] Plugin not found: $plugin_name"
    return 1
  fi
  angel_print "plugin" "ENABLE" "plugin=$plugin_name"
  
  # Symlink into enabled
  ln -sf "$plugin_dir" "$ENABLED_DIR/$plugin_name" 2>/dev/null
  
  # Load hooks
  if [ -d "$plugin_dir/hooks" ]; then
    for hook in "$plugin_dir/hooks"/*.sh; do
      [ -f "$hook" ] || continue
      local hook_name
      hook_name=$(basename "$hook" .sh)
      ln -sf "$hook" "$ANGEL_HOME/hooks/${plugin_name}.${hook_name}.sh" 2>/dev/null
      # Also register with hook system for proper event routing
      if [ -f "$ANGEL_HOME/bin/angel-hooks.sh" ]; then
        # Register with both : and - versions for compatibility
        local event_name="${hook_name//-/:}"
        # Deduplication: skip if this event+script already registered
        local already_registered
        already_registered=$(python3 -c "
import json
try:
    d = json.load(open(\'$ANGEL_HOME/store/hook_registry.json\'))
    for h in d.get(\'hooks\',{}).get(\'$event_name\',[]):
        if h.get(\'script\',\'\') == \'$hook\':
            print(\'yes\')
            break
except: pass
" 2>/dev/null)
        if [ "$already_registered" != "yes" ]; then
        bash "$ANGEL_HOME/bin/angel-hooks.sh" register "$event_name" \
          "$hook" 50 "Plugin: $plugin_name" 2>/dev/null
      fi
        fi
    done
  fi
  
  # Load commands
  if [ -d "$plugin_dir/commands" ]; then
    for cmd in "$plugin_dir/commands"/*.sh; do
      [ -f "$cmd" ] || continue
      local cmd_name
      cmd_name=$(basename "$cmd" .sh)
      ln -sf "$cmd" "$ANGEL_HOME/bin/plugin-${plugin_name}-${cmd_name}" 2>/dev/null
      chmod +x "$ANGEL_HOME/bin/plugin-${plugin_name}-${cmd_name}" 2>/dev/null
    done
  fi
  
  # Update manifest
  python3 -c "
import json
d = json.load(open('$METADATA_FILE'))
if '$plugin_name' not in d: d['$plugin_name'] = {}
d['$plugin_name']['status'] = 'enabled'
d['$plugin_name']['enabled_at'] = $(date +%s)
json.dump(d, open('$METADATA_FILE', 'w'))
" 2>/dev/null
  
  angel_info "[plugin] Enabled: $plugin_name"
}

# === Disable a plugin ===
plugin_disable() {
  local plugin_name="$1"
  
  # Remove symlinks
  rm -f "$ENABLED_DIR/$plugin_name" 2>/dev/null
  rm -f "$ANGEL_HOME/hooks/${plugin_name}."*.sh 2>/dev/null
  rm -f "$ANGEL_HOME/bin/plugin-${plugin_name}-"* 2>/dev/null
  
  # Update manifest
  python3 -c "
import json
d = json.load(open('$METADATA_FILE'))
if '$plugin_name' in d: d['$plugin_name']['status'] = 'disabled'
json.dump(d, open('$METADATA_FILE', 'w'))
" 2>/dev/null
  
  angel_info "[plugin] Disabled: $plugin_name"
}

# === Uninstall a plugin completely ===
plugin_uninstall() {
  local plugin_name="$1"
  plugin_disable "$plugin_name"
  rm -rf "$AVAILABLE_DIR/$plugin_name" 2>/dev/null
  
  python3 -c "
import json
d = json.load(open('$METADATA_FILE'))
d.pop('$plugin_name', None)
json.dump(d, open('$METADATA_FILE', 'w'))
" 2>/dev/null
  
  angel_info "[plugin] Uninstalled: $plugin_name"
}

# === List plugins ===
plugin_list() {
  echo "=== AngelKernel Plugins ==="
  echo ""
  echo "Enabled:"
  for link in "$ENABLED_DIR"/*; do
    [ -L "$link" ] || continue
    local name
    name=$(basename "$link")
    local manifest="$AVAILABLE_DIR/$name/plugin.json"
    if [ -f "$manifest" ]; then
      python3 -c "
import json
d = json.load(open('$manifest'))
print(f'  {d[\"name\"]} v{d[\"version\"]} — {d.get(\"description\",\"\")[:60]}')
" 2>/dev/null
    else
      echo "  $name"
    fi
  done
  
  echo ""
  echo "Available (disabled):"
  for dir in "$AVAILABLE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    [ -L "$ENABLED_DIR/$name" ] && continue
    local manifest="$dir/plugin.json"
    if [ -f "$manifest" ]; then
      python3 -c "
import json
d = json.load(open('$manifest'))
print(f'  {d[\"name\"]} v{d[\"version\"]} — {d.get(\"description\",\"\")[:60]}')
" 2>/dev/null
    else
      echo "  $name (no plugin.json)"
    fi
  done
}

# === Create a plugin scaffold ===
plugin_scaffold() {
  local name="$1" description="${2:-A new AngelKernel plugin}"
  local dir="$AVAILABLE_DIR/$name"
  
  if [ -d "$dir" ]; then
    angel_error "[plugin] Already exists: $name"
    return 1
  fi
  
  mkdir -p "$dir"/{hooks,commands}
  
  # Create plugin.json
  cat > "$dir/plugin.json" <<EOF
{
  "name": "$name",
  "version": "1.0.0",
  "description": "$description",
  "author": "",
  "license": "MIT",
  "hooks": ["pre-exec", "post-exec", "on-error"],
  "commands": [],
  "dependencies": [],
  "permissions": ["bash"]
}
EOF
  
  # Create example hook
  cat > "$dir/hooks/pre-exec.sh" << 'EOF'
#!/bin/bash
# Pre-execution hook — runs before each RALPH action
echo "[plugin:hook] Pre-exec: $*"
EOF
  chmod +x "$dir/hooks/pre-exec.sh"
  
  # Create example command
  cat > "$dir/commands/hello.sh" << 'EOF'
#!/bin/bash
# Example plugin command
echo "Hello from plugin '$name'!"
EOF
  chmod +x "$dir/commands/hello.sh"
  
  angel_info "[plugin] Scaffolded: $name"
  echo "  Location: $dir"
  echo "  Enable:   angel-plugin.sh enable $name"
}

case "${1:-}" in
  discover)
    plugin_discover ;;
  validate)
    plugin_validate "$2" ;;
  install)
    plugin_install "$2" ;;
  enable)
    plugin_enable "$2" ;;
  disable)
    plugin_disable "$2" ;;
  uninstall)
    plugin_uninstall "$2" ;;
  list)
    plugin_list ;;
  scaffold)
    plugin_scaffold "$2" "$3" ;;
  *)
    echo "Usage: angel-plugin.sh {discover|validate|install|enable|disable|uninstall|list|scaffold} [args]"
    ;;
esac
