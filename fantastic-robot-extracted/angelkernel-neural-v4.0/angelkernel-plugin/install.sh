#!/usr/bin/env bash
set -euo pipefail

# AngelKernel Neural v4.0 — Standalone Plugin Installer
# Installs the TypeScript plugin for AI coding agents (OpenCode, Codex, Claude Code, etc.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="angelkernel-neural"

echo "AngelKernel Neural v4.0 Plugin Installer"
echo "========================================="

SRC="$SCRIPT_DIR"

if [ ! -f "$SRC/dist/index.js" ]; then
    echo "Looking for dist/index.js..."
    # Try parent in case we're inside a subdir
    if [ -f "$SCRIPT_DIR/../dist/index.js" ]; then
        SRC="$SCRIPT_DIR/.."
    elif [ -f "$PWD/dist/index.js" ]; then
        SRC="$PWD"
    else
        echo "ERROR: Cannot find plugin build (dist/index.js)"
        echo "Make sure the zip was extracted correctly and you're running"
        echo "install.sh from the extracted directory."
        exit 1
    fi
fi

echo "Source: $SRC"

# Detect install targets
TARGETS=()

for dir in "$HOME/.opencode/plugins" "$HOME/.codex/plugins" "$HOME/.claude/plugins"; do
    if [ -d "$dir" ]; then
        AGENT=$(basename "$(dirname "$(dirname "$dir")")")
        TARGETS+=("${AGENT}:${dir}")
        echo "  [detected] $AGENT plugins dir"
    fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "  [info] No known agent plugin dirs found. Using ~/.opencode/plugins"
    mkdir -p "$HOME/.opencode/plugins"
    TARGETS+=("opencode:$HOME/.opencode/plugins")
fi

# Step 1: Copy plugin to each target
for target in "${TARGETS[@]}"; do
    AGENT="${target%%:*}"
    DIR="${target##*:}"
    PLUGIN_DIR="$DIR/$PLUGIN_NAME"

    echo ""
    echo "--- Installing to $AGENT ($PLUGIN_DIR) ---"

    if [ -e "$PLUGIN_DIR" ]; then
        rm -rf "$PLUGIN_DIR"
    fi

    mkdir -p "$DIR"
    cp -r "$SRC" "$PLUGIN_DIR"
    echo "  OK"
done

# Step 2: Update marketplace
echo ""
echo "--- Marketplace ---"
MARKETPLACE_DIR="$HOME/.agents/plugins"
MARKETPLACE_FILE="$MARKETPLACE_DIR/marketplace.json"
mkdir -p "$MARKETPLACE_DIR"

FIRST_TARGET_DIR="${TARGETS[0]##*/}"
FIRST_PLUGIN_PATH="${TARGETS[0]##*:}/$PLUGIN_NAME"

cat > "$MARKETPLACE_FILE" << MARKET
{
  "name": "Agent Plugins",
  "plugins": [
    {
      "name": "angelkernel-neural",
      "path": "$FIRST_PLUGIN_PATH",
      "version": "4.0.0",
      "description": "AngelKernel v4.0 Neural - Autonomous Neural Cognition OS",
      "enabled": true
    }
  ]
}
MARKET
echo "  Marketplace configured"

# Step 3: Data directories
echo ""
echo "--- Data directories ---"
mkdir -p "$HOME/.angelkernel-neural-data/store"
mkdir -p "$HOME/.angelkernel-neural-data/memory/cortex"
mkdir -p "$HOME/.angelkernel-neural-data/neural"
mkdir -p "$HOME/.angelkernel-neural-data/logs"
echo "  Ready"

# Step 4: Init data files
echo ""
echo "--- Data files ---"
for path in "$HOME/.angelkernel-neural-data/neural/skills.json" "$HOME/.angelkernel-neural-data/neural/routes.json" "$HOME/.angelkernel-neural-data/store/event-log.json"; do
    if [ ! -f "$path" ]; then
        echo '{}' > "$path"
        echo "  Created $(basename "$path")"
    fi
done

if [ ! -f "$HOME/.angelkernel-neural-data/store/error-correction.json" ]; then
    echo '{"created":"","patterns":[],"fixes":[],"learnings":[]}' > "$HOME/.angelkernel-neural-data/store/error-correction.json"
    echo "  Created error-correction.json"
fi

# Step 5: Verify
echo ""
echo "--- Verification ---"
NODE_OK=0
if command -v node &>/dev/null; then
    NODE_VER=$(node --version)
    echo "  Node.js: $NODE_VER"
    NODE_OK=1
else
    echo "  WARNING: Node.js not found - install Node 20+ to use the plugin"
fi

if [ -f "$SRC/dist/scripts/angel-status.js" ] && [ "$NODE_OK" = "1" ]; then
    if node "$SRC/dist/scripts/angel-status.js" &>/dev/null; then
        echo "  Runtime: OK"
    else
        echo "  Runtime: WARNING (missing AngelKernel data? Run angel-doctor)"
    fi
fi

echo ""
echo "========================================="
echo " AngelKernel Neural v4.0 installed!"
echo ""
echo "Add to PATH for CLI access:"
echo "  export PATH=\"\$PATH:$SRC/dist/scripts\""
echo ""
echo "Or symlink individual commands:"
echo "  ln -sf $SRC/dist/scripts/angel-* /usr/local/bin/"
echo ""
echo "Run diagnostics:"
echo "  node $SRC/dist/scripts/angel-doctor.js"
echo "========================================="
