#!/bin/bash
set -e

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
mkdir -p "$ANGEL_HOME"/{bin,skills,backups,context,memory/{session,interactions,learnings},logs,hooks,subagents,config,lib,profiles,daemons,mcp,plugins,store,repos,run}

export PATH="$ANGEL_HOME/bin:/usr/local/bin:$PATH"

echo "=== AngelKernel Bootstrap v1.0 ==="

CONF_FILE="$ANGEL_HOME/config/angel.conf"
if [ ! -f "$CONF_FILE" ]; then
  cat > "$CONF_FILE" << 'CONF'
ANGEL_HOME="$HOME/.angelkernel"
ANGEL_AUTO_MODE=true
ANGEL_MAX_DEPTH=5
ANGEL_BACKUP_RETENTION_DAYS=7
ANGEL_MCP_PORT=8200
ANGEL_KILOPROXY_PORT=8201
ANGEL_AUTO_EVOLVE=true
ANGEL_AUTO_SKILL_SEARCH=true
ANGEL_REVIEW_MODE=false
ANGEL_MEMORY_BACKEND=icm
ANGEL_MEMORY_PORT=3032
ANGEL_CTX_BACKEND=lean-ctx
ANGEL_CTX_PORT=3879
ANGEL_BROWSER_BACKEND=browser39
ANGEL_CODE_INTEL_BACKEND=toktoken
CONF
  echo "Config written: $CONF_FILE"
fi

install_binary() {
  local name="$1"
  local repo="$2"
  local binary="$3"
  local target="$ANGEL_HOME/bin/$name"

  if [ -f "$target" ] && [ -x "$target" ]; then
    echo "[bin] $name already installed"
    return 0
  fi

  echo "[bin] Installing $name from $repo..."
  if command -v cargo &>/dev/null && [ -d "$ANGEL_HOME/repos/$name" ]; then
    (cd "$ANGEL_HOME/repos/$name" && cargo build --release 2>/dev/null) && {
      find "$ANGEL_HOME/repos/$name/target/release" -maxdepth 1 -executable -type f -name "$binary" -exec cp {} "$target" \; 2>/dev/null
      chmod +x "$target" 2>/dev/null
    }
  fi

  if [ ! -f "$target" ]; then
    echo "[bin] $name NOT built. Will use npm/pip fallback or skip."
    return 1
  fi
  echo "[bin] $name installed: $target"
}

install_python_tool() {
  local name="$1"
  local pkg="$2"
  if pip install -q "$pkg" 2>/dev/null; then
    echo "[pip] $name installed"
  fi
}

install_npm_tool() {
  local name="$1"
  local pkg="$2"
  if npm install -g "$pkg" --silent 2>/dev/null; then
    echo "[npm] $name installed"
  fi
}

install_binary "engram-gentleman" "engram-gentleman" "engram"
install_python_tool "engram-raya" "engram-memory-system" &
install_npm_tool "pskoett-ai-skills" "@pskoett/ai-skills" &

echo ""
echo "[symlink] Setting up global symlinks..."
for f in "$ANGEL_HOME/bin"/*; do
  if [ -f "$f" ] && [ -x "$f" ]; then
    name=$(basename "$f")
    ln -sf "$f" "/usr/local/bin/$name" 2>/dev/null
  fi
done

echo ""
echo "=== AngelKernel Bootstrap Complete ==="
echo "  Bin:    $ANGEL_HOME/bin"
echo "  Config: $CONF_FILE"
echo "  Run:    angel-init"
echo ""
echo "  Tools available:"
ls -1 "$ANGEL_HOME/bin" 2>/dev/null
