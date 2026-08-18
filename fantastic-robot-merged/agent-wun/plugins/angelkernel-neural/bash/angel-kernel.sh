#!/bin/bash
set -euo pipefail
# angel-kernel v4.0 — AngelKernel Neural Main Entry Point
# Routes ALL queries through Neural Cognition (P0) then Unified Execution Engine.
# Single path for every query — Neural first, ALL subsystems active, ALL providers free.
#
# Usage:
#   angel-kernel "your natural language query"
#   angel-kernel --depth 5 "complex task"  # Set recursion depth

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="kernel"
angel_console_init 2>/dev/null || true

BIN_DIR="$ANGEL_HOME/bin"
DEPTH="${ANGEL_DEPTH:-0}"
MAX_DEPTH="${ANGEL_MAX_DEPTH:-5}"

# Parse flags
while [[ "$1" == --* ]]; do
    case "$1" in
        --depth) MAX_DEPTH="$2"; shift 2 ;;
        --help) 
            echo "AngelKernel v4.0 Neural — Autonomous Neural Cognition OS"
            echo ""
            echo "Usage:"
            echo "  angel-kernel \"your natural language query\""
            echo "  angel-kernel --depth 5 \"complex multi-step task\""
            echo ""
            echo "Pipeline: NEURAL → ENHANCE → ANALYZE → PLAN → EXECUTE → EVOLVE → REFLECT"
            echo "All operations route through Neural Cognition Engine first."
            echo "All providers are FREE. No API keys required."
            exit 0
            ;;
        *) break ;;
    esac
done

# Recursion guard
if [ "$DEPTH" -ge "$MAX_DEPTH" ]; then
    angel_error "Max recursion depth ($MAX_DEPTH) reached."
    exit 1
fi

export ANGEL_DEPTH=$((DEPTH + 1))

# --- Phase 0: Neural Cognition (pre-dispatch) ---
if [ "${ANGEL_NEURAL_ENABLED:-true}" = "true" ] && [ "${ANGEL_NEURAL_FIRST:-true}" = "true" ] && [ -f "$BIN_DIR/angel-neural.sh" ]; then
    angel_print "neural" "KERNEL PRE-DISPATCH" "synthesizing query before routing..."
    bash "$BIN_DIR/angel-neural.sh" synthesize "$*" 2>/dev/null &
    # Register universal hooks if not yet done
    if [ "${ANGEL_UNIVERSAL_HOOKS_ENABLED:-true}" = "true" ] && [ ! -f "$ANGEL_HOME/store/hook_registry.json" ]; then
        bash "$BIN_DIR/angel-hooks-universal.sh" register-all 2>/dev/null &
    fi
fi

# Route through Unified Neural Execution Engine
if [ -f "$BIN_DIR/angel-unity.sh" ]; then
    # Always use the full neural-unified path — no shortcuts
    exec bash "$BIN_DIR/angel-unity.sh" "$@"
else
    # Fallback: direct superloop
    angel_warn "Unity engine not found — falling back to SuperLoop"
    exec bash "$BIN_DIR/angel-superloop.sh" "$@"
fi
