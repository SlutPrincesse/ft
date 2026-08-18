#!/bin/bash
# angel-agent-installer — Install AngelKernel profiles for all CLI agents

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
PROFILE_DIR="$ANGEL_HOME/profiles/agents"

install_for_kilo() {
  echo "[installer] Installing for Kilo..."
  cp "$PROFILE_DIR/kilo.json" "$HOME/kilo.json" 2>/dev/null || true
  cp "$PROFILE_DIR/universal-agent.json" "$HOME/AGENTS.md" 2>/dev/null || true
  echo "  → Copied to ~/kilo.json and ~/AGENTS.md"
}

install_for_opencode() {
  echo "[installer] Installing for Opencode..."
  mkdir -p "$HOME/.opencode"
  cp "$PROFILE_DIR/universal-agent.json" "$HOME/.opencode/agent.json" 2>/dev/null || true
  echo "  → Copied to ~/.opencode/agent.json"
}

install_for_poolside() {
  echo "[installer] Installing for Poolside..."
  mkdir -p "$HOME/.config/poolside"
  cp "$PROFILE_DIR/universal-agent.json" "$HOME/.config/poolside/config.json" 2>/dev/null || true
  echo "  → Copied to ~/.config/poolside/config.json"
}

install_for_codex() {
  echo "[installer] Installing for Codex..."
  mkdir -p "$HOME/.codex"
  cp "$PROFILE_DIR/universal-agent.json" "$HOME/.codex/agent.json" 2>/dev/null || true
  echo "  → Copied to ~/.codex/agent.json"
}

install_for_amp() {
  echo "[installer] Installing for Amp..."
  mkdir -p "$HOME/.amp"
  cp "$PROFILE_DIR/universal-agent.json" "$HOME/.amp/agent.json" 2>/dev/null || true
  echo "  → Copied to ~/.amp/agent.json"
}

install_for_openclaw() {
  echo "[installer] Installing for OpenClaw..."
  mkdir -p "$HOME/.openclaw"
  cp "$PROFILE_DIR/universal-agent.json" "$HOME/.openclaw/config.json" 2>/dev/null || true
  echo "  → Copied to ~/.openclaw/config.json"
}

install_all() {
  echo "=== Installing AngelKernel for All Agents ==="
  install_for_kilo
  install_for_opencode
  install_for_poolside
  install_for_codex
  install_for_amp
  install_for_openclaw
  echo ""
  echo "✓ All agents configured with AngelKernel universal profile"
}

case "${1:-all}" in
  kilo) install_for_kilo ;;
  opencode) install_for_opencode ;;
  poolside) install_for_poolside ;;
  codex) install_for_codex ;;
  amp) install_for_amp ;;
  openclaw) install_for_openclaw ;;
  all|*) install_all ;;
esac