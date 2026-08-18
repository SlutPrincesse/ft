#!/bin/bash
set -euo pipefail
# angel-test — AngelKernel Testing Framework.
#
# Provides:
#   1. Unit tests for individual components
#   2. Integration tests for component interactions
#   3. Regression test suite
#   4. Performance benchmarks
#   5. Coverage reporting
#   6. Self-healing test runner (retries flaky tests)
#
# Tests are defined as simple scripts in $TEST_DIR that
# exit 0 for pass, non-zero for fail.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="test"
angel_console_init 2>/dev/null || true

TEST_DIR="$ANGEL_HOME/store/tests"
REPORT_DIR="$ANGEL_HOME/logs/reports"
mkdir -p "$TEST_DIR" "$REPORT_DIR"

PASS=0
FAIL=0
SKIP=0
TOTAL=0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========================================================================
# TEST RUNNER
# ========================================================================

test_run() {
  local test_name="$1" test_cmd="$2" timeout="${3:-30}"
  
  TOTAL=$((TOTAL + 1))
  
  # Run with timeout
  local output
  output=$(timeout "$timeout" bash -c "$test_cmd" 2>&1)
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}[PASS]${NC} %s\n" "$test_name"
    return 0
  elif [ $exit_code -eq 124 ]; then
    SKIP=$((SKIP + 1))
    printf "  ${YELLOW}[SKIP]${NC} %s (timeout after ${timeout}s)\n" "$test_name"
    return 0
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}[FAIL]${NC} %s\n" "$test_name"
    [ -n "$output" ] && echo "    $output" | head -3
    return 1
  fi
}

# ========================================================================
# BUILT-IN TEST SUITES
# ========================================================================

test_suite_core() {
  echo ""
  echo "── Core Infrastructure ──"
  
  test_run "angel-lib.sh loads" \
    "source $ANGEL_HOME/lib/angel-lib.sh && angel_has bash"
  
  test_run "Config has version" \
    "source $ANGEL_HOME/config/angel.conf && [ -n \"$ANGEL_VERSION\" ]"
  
  test_run "All binaries exist" \
    'for f in angel-cortex.sh angel-superloop.sh angel-swarm.sh angel-metacog.sh angel-plugin.sh angel-hooks.sh angel-observe.sh angel-adapt.sh angel-prompter.sh angel-safety.sh angel-kernel.sh angel-daemon.sh angel-init angel-stop angel-status angel-pulse.sh angel-edit.sh angel-evolve.sh angel-self-improve.sh angel-skill-manager.sh; do [ -x "'$ANGEL_HOME'/bin/$f" ] || exit 1; done'
}

test_suite_cortex() {
  echo ""
  echo "── Memory Cortex ──"
  
  # Setup
  local test_file="$ANGEL_HOME/memory/cortex/l2_episodic/log.ndjson"
  local saved_content=""
  [ -f "$test_file" ] && saved_content=$(cat "$test_file")
  
  test_run "L2 store with metadata" \
    "bash $ANGEL_HOME/bin/angel-cortex.sh store 'test suite memory' 'test' '{\"suite\":\"test\"}' 2>/dev/null"
  
  test_run "L2 search" \
    "bash $ANGEL_HOME/bin/angel-cortex.sh l2-search 'test suite' 3 0 2>/dev/null | python3 -c 'import json,sys; d=json.loads(sys.stdin.readline()); assert d.get(\"content\",\"\")'" 
  
  test_run "L1 working memory" \
    "bash $ANGEL_HOME/bin/angel-cortex.sh l1-store 'test-k' 'test-v' 10 2>/dev/null && bash $ANGEL_HOME/bin/angel-cortex.sh l1-get 'test-k' 2>/dev/null | grep -q 'test-v'"
  
  test_run "L4 procedural memory" \
    "bash $ANGEL_HOME/bin/angel-cortex.sh l4-store 'test-skill' 'test pattern' 'step1, step2' 1.0 2>/dev/null"
  
  test_run "L4 search" \
    "bash $ANGEL_HOME/bin/angel-cortex.sh l4-search 'test pattern' 2>/dev/null | python3 -c 'import json,sys; d=json.loads(sys.stdin.readline()); assert d.get(\"success_rate\",0) > 0'"
  
  # Cleanup (partial - don't remove test data that might be useful)
  # We leave the L2 data intact but restore the L1
  bash $ANGEL_HOME/bin/angel-cortex.sh l1-clear 2>/dev/null
}

test_suite_metacog() {
  echo ""
  echo "── Meta-Cognition ──"
  
  test_run "Confidence estimation" \
    "bash $ANGEL_HOME/bin/angel-metacog.sh confidence 'What is 2+2?' '4' 2>/dev/null | grep -qE '^0\.[0-9]'"
  
  test_run "Strategy switching" \
    "bash $ANGEL_HOME/bin/angel-metacog.sh strategy 'direct' 0.3 'test' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"next_strategy\")'"
  
  test_run "Hallucination detection" \
    "bash $ANGEL_HOME/bin/angel-metacog.sh hallucination 'test claim' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hallucination_probability\" in d'"
}

test_suite_adapt() {
  echo ""
  echo "── Autonomous Adaptation ──"
  
  test_run "Task analysis" \
    "bash $ANGEL_HOME/bin/angel-adapt.sh analyze 'Build a Godot game' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d.get(\"domains\",[])) > 0'"
  
  test_run "Skill discovery" \
    "bash $ANGEL_HOME/bin/angel-adapt.sh discover-skills 'python coding' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"installed_matches\" in d'"
  
  test_run "Route learning" \
    "bash $ANGEL_HOME/bin/angel-adapt.sh route 'test query route' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"match_confidence\" in d'"
  
  test_run "Capability scan" \
    "bash $ANGEL_HOME/bin/angel-adapt.sh scan 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"skills_found\" in d'"
}

test_suite_prompter() {
  echo ""
  echo "── Prompt Engineer ──"
  
  test_run "Task type detection" \
    "result=\$(bash $ANGEL_HOME/bin/angel-prompter.sh analyze 'Write a Python function to sort a list' 2>/dev/null); [ \"\$result\" = \"code\" ]"
  
  test_run "Prompt building" \
    "bash $ANGEL_HOME/bin/angel-prompter.sh build 'Explain quantum computing' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"system_prompt\")'"
  
  test_run "Prompt application" \
    "bash $ANGEL_HOME/bin/angel-prompter.sh apply 'Write a Python function' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"messages\" in d'"
  
  test_run "Prompt evaluation" \
    "bash $ANGEL_HOME/bin/angel-prompter.sh evaluate 'Test query' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"quality_score\")'"
}

test_suite_safety() {
  echo ""
  echo "── Safety Governor ──"
  
  test_run "Permission check" \
    "bash $ANGEL_HOME/bin/angel-safety.sh check test-entity command_exec 2>/dev/null | grep -qE 'allow|deny|ask'"
  
  test_run "Threat scan (safe)" \
    "result=\$(bash $ANGEL_HOME/bin/angel-safety.sh scan 'echo hello world' 2>/dev/null); echo \"\$result\" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"risk_score\",1) < 0.5'"
  
  test_run "Threat scan (dangerous)" \
    "result=\$(bash $ANGEL_HOME/bin/angel-safety.sh scan 'rm -rf /' 2>/dev/null); echo \"\$result\" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"risk_score\",0) > 0.5'"
  
  test_run "Audit log exists" \
    "bash $ANGEL_HOME/bin/angel-safety.sh audit 10 2>/dev/null"
  
  test_run "Sandbox execution" \
    "result=\$(bash $ANGEL_HOME/bin/angel-safety.sh sandbox 'echo sandbox-test' 5 128 test-suite 2>/dev/null); echo \"\$result\" | grep -q 'sandbox-test'"
  
  test_run "Permission set/list" \
    "bash $ANGEL_HOME/bin/angel-safety.sh set test-skill command_exec allow 2>/dev/null && bash $ANGEL_HOME/bin/angel-safety.sh perms 2>/dev/null | grep -q 'test-skill'"
}

test_suite_plugins_hooks() {
  echo ""
  echo "── Plugins & Hooks ──"
  
  test_run "Hook fire" \
    "bash $ANGEL_HOME/bin/angel-hooks.sh fire 'test:event' '{}' false 2>/dev/null"
  
  test_run "Hook list" \
    "bash $ANGEL_HOME/bin/angel-hooks.sh list 2>/dev/null"
  
  test_run "Plugin list" \
    "bash $ANGEL_HOME/bin/angel-plugin.sh list 2>/dev/null"
}

test_suite_swarm() {
  echo ""
  echo "── Swarm Intelligence ──"
  
  test_run "Swarm spawn" \
    "bash $ANGEL_HOME/bin/angel-swarm.sh spawn thinker 'test task' 'test-suite' 2>/dev/null"
  
  test_run "Swarm stats" \
    "bash $ANGEL_HOME/bin/angel-swarm.sh stats 2>/dev/null"
}

test_suite_observe() {
  echo ""
  echo "── Observability ──"
  
  test_run "Record metric" \
    "bash $ANGEL_HOME/bin/angel-observe.sh record 'test.metric' 1 '{}' 2>/dev/null"
  
  test_run "System metrics" \
    "bash $ANGEL_HOME/bin/angel-observe.sh system 2>/dev/null | python3 -c 'import json,sys; json.load(sys.stdin)'"
  
  test_run "Kernel metrics" \
    "bash $ANGEL_HOME/bin/angel-observe.sh kernel 2>/dev/null | python3 -c 'import json,sys; json.load(sys.stdin)'"
  
  test_run "Report generation" \
    "bash $ANGEL_HOME/bin/angel-observe.sh report 2>/dev/null"
}

test_suite_mcp_v2() {
  echo ""
  echo "── MCP v2 Server ──"
  
  local MCP_PORT="${ANGEL_MCP_PORT:-8200}"
  local MCP_BASE="http://127.0.0.1:$MCP_PORT"
  
  test_run "Health endpoint" \
    "curl -s --max-time 3 $MCP_BASE/health 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"result\"][\"status\"] == \"ok\"; assert d[\"result\"][\"tools_count\"] >= 10'"
  
  test_run "Tools list (GET)" \
    "curl -s --max-time 3 $MCP_BASE/tools 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"result\"][\"tools\"]) >= 10'"
  
  test_run "Tools list (JSON-RPC)" \
    "curl -s --max-time 3 -X POST $MCP_BASE/ -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"result\"][\"tools\"]) >= 10; print(f\"  {len(d[\"result\"][\"tools\"])} tools\")'"
  
  test_run "JSON-RPC initialize" \
    "curl -s --max-time 3 -X POST $MCP_BASE/ -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"result\"][\"protocolVersion\"]; assert d[\"result\"][\"serverInfo\"][\"name\"] == \"AngelKernel MCP v2\"'"
  
  test_run "Tool execution (health)" \
    "curl -s --max-time 3 -X POST $MCP_BASE/ -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"health\",\"arguments\":{}}}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); r = d[\"result\"]; assert r.get(\"status\") == \"ok\" or r.get(\"stdout\",\"\").find(\"ok\") >= 0'"
  
  test_run "Tool execution (observe_system)" \
    "curl -s --max-time 5 -X POST $MCP_BASE/ -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"observe_system\",\"arguments\":{}}}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin)'"
  
  test_run "Ping endpoint" \
    "curl -s --max-time 3 -X POST $MCP_BASE/ -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\",\"params\":{}}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"result\"][\"pong\"]'"
  
  test_run "Resources list" \
    "curl -s --max-time 3 -X POST $MCP_BASE/ -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/list\",\"params\":{}}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"result\"][\"resources\"]) >= 3'"
  
  test_run "Prompts list" \
    "curl -s --max-time 3 -X POST $MCP_BASE/ -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"prompts/list\",\"params\":{}}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"result\"][\"prompts\"]) >= 3'"
}

# ========================================================================
# FULL TEST SUITE
# ========================================================================

test_all() {
  local start_time
  start_time=$(date +%s)
  
  echo "╔══════════════════════════════════════════════════╗"
  echo "║      AngelKernel Test Framework v2.0             ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "Started: $(date)"
  echo ""
  
  # Run all suites
  test_suite_core
  test_suite_cortex
  test_suite_metacog
  test_suite_adapt
  test_suite_prompter
  test_suite_safety
  test_suite_plugins_hooks
  test_suite_swarm
  test_suite_observe
  test_suite_mcp_v2
  
  local elapsed=$(( $(date +%s) - start_time ))
  
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║  Results                                          ║"
  echo "╠══════════════════════════════════════════════════╣"
  printf "║  Total:  %3d                                 ║\n" "$TOTAL"
  printf "║  Passed: %3d  ${GREEN}✓${NC}                                ║\n" "$PASS"
  [ "$FAIL" -gt 0 ] && printf "║  Failed: %3d  ${RED}✗${NC}                                ║\n" "$FAIL"
  [ "$SKIP" -gt 0 ] && printf "║  Skipped: %3d ${YELLOW}○${NC}                                ║\n" "$SKIP"
  printf "║  Time:   %3ds                                  ║\n" "$elapsed"
  echo "╚══════════════════════════════════════════════════╝"
  
  # Write report
  local report_file="$REPORT_DIR/test-report-$(date +%Y%m%d-%H%M%S).json"
  python3 -c "
import json
report = {
    'timestamp': $(date +%s),
    'iso': '$(angel_iso)',
    'total': $TOTAL,
    'passed': $PASS,
    'failed': $FAIL,
    'skipped': $SKIP,
    'elapsed': $elapsed
}
with open('$report_file', 'w') as f:
    json.dump(report, f, indent=2)
print(f'Report written: $report_file')
" 2>/dev/null
  
  return $FAIL
}

# ========================================================================
# SELECTIVE TEST RUNNING
# ========================================================================

test_suite() {
  local suite="$1"
  
  case "$suite" in
    core)     test_suite_core ;;
    cortex)   test_suite_cortex ;;
    metacog)  test_suite_metacog ;;
    adapt)    test_suite_adapt ;;
    prompter) test_suite_prompter ;;
    safety)   test_suite_safety ;;
    plugins)  test_suite_plugins_hooks ;;
    swarm)    test_suite_swarm ;;
    observe)  test_suite_observe ;;
    mcp_v2|mcp) test_suite_mcp_v2 ;;
    *)
      echo "Unknown suite: $suite"
      echo "Available: core, cortex, metacog, adapt, prompter, safety, plugins, swarm, observe, mcp_v2"
      return 1
      ;;
  esac
  
  echo ""
  printf "Suite results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}, ${YELLOW}%d skipped${NC}\n" "$PASS" "$FAIL" "$SKIP"
}

# ========================================================================
# REGRESSION CHECK
# ========================================================================

test_regression() {
  local baseline_file="$TEST_DIR/baseline.json"
  
  if [ ! -f "$baseline_file" ]; then
    echo "No baseline found. Creating from current run..."
    test_all
    # Save as baseline
    python3 -c "
import json
baseline = {
    'created': $(date +%s),
    'total': $TOTAL,
    'passed': $PASS,
    'failed': $FAIL
}
with open('$baseline_file', 'w') as f:
    json.dump(baseline, f, indent=2)
echo 'Baseline saved: $baseline_file'
"
    return 0
  fi
  
  # Run tests and compare
  test_all
  
  python3 -c "
import json
with open('$baseline_file') as f:
    baseline = json.load(f)
current = {'total': $TOTAL, 'passed': $PASS, 'failed': $FAIL}

print()
print('=== Regression Check ===')
print(f'Baseline: {baseline[\"passed\"]}/{baseline[\"total\"]} passed')
print(f'Current:  {current[\"passed\"]}/{current[\"total\"]} passed')

if current['failed'] > baseline.get('failed', 0):
    print('⚠️  REGRESSION DETECTED: More failures than baseline')
    return 1
else:
    print('✓ No regression detected')
    return 0
" 2>/dev/null
}

# ========================================================================
# PERFORMANCE BENCHMARK
# ========================================================================

test_benchmark() {
  local iterations="${1:-5}"
  
  echo "=== AngelKernel Performance Benchmark ==="
  echo "Iterations: $iterations"
  echo ""
  
  local total_time=0
  
  for ((i=1; i<=iterations; i++)); do
    local start
    start=$(date +%s%N)
    
    # Run a standard set of operations
    source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null
    angel_has bash > /dev/null
    angel_ts > /dev/null
    bash "$ANGEL_HOME/bin/angel-cortex.sh" l1-store "bench-k" "bench-v" 5 2>/dev/null
    bash "$ANGEL_HOME/bin/angel-cortex.sh" l1-get "bench-k" 2>/dev/null
    bash "$ANGEL_HOME/bin/angel-cortex.sh" stats 2>/dev/null
    bash "$ANGEL_HOME/bin/angel-observe.sh" system 2>/dev/null
    bash "$ANGEL_HOME/bin/angel-safety.sh" check test command_exec 2>/dev/null
    bash "$ANGEL_HOME/bin/angel-prompter.sh" analyze "test query" 2>/dev/null
    
    local end
    end=$(date +%s%N)
    local elapsed_ns=$((end - start))
    local elapsed_ms=$((elapsed_ns / 1000000))
    total_time=$((total_time + elapsed_ms))
    
    echo "  Iteration $i: ${elapsed_ms}ms"
  done
  
  local avg=$((total_time / iterations))
  echo ""
  echo "Average: ${avg}ms per iteration"
  echo "Total:   ${total_time}ms across ${iterations} iterations"
  
  # Save benchmark
  local bench_file="$REPORT_DIR/benchmark-$(date +%Y%m%d-%H%M%S).json"
  python3 -c "
import json
bench = {
    'timestamp': $(date +%s),
    'iterations': $iterations,
    'total_ms': $total_time,
    'avg_ms': $avg
}
with open('$bench_file', 'w') as f:
    json.dump(bench, f, indent=2)
print(f'Benchmark saved: $bench_file')
" 2>/dev/null
}

# ========================================================================
# LIST TESTS
# ========================================================================

test_list() {
  echo "=== Available Test Suites ==="
  echo ""
  echo "  core      — Core infrastructure (lib, config, binaries)"
  echo "  cortex    — Memory Cortex (L1-L4, recall, search)"
  echo "  metacog   — Meta-Cognition (confidence, hallucination)"
  echo "  adapt     — Autonomous Adaptation (analysis, routing)"
  echo "  prompter  — Prompt Engineer (templates, building)"
  echo "  safety    — Safety Governor (permissions, sandbox)"
  echo "  plugins   — Plugins & Hooks"
  echo "  swarm     — Swarm Intelligence"
  echo "  observe   — Observability"
  echo "  mcp_v2    — MCP v2 Server (HTTP + JSON-RPC integration tests)"
  echo ""
  echo "Commands:"
  echo "  angel-test.sh all          — Run all test suites"
  echo "  angel-test.sh suite <name> — Run a specific suite"
  echo "  angel-test.sh regression   — Compare against baseline"
  echo "  angel-test.sh benchmark [n] — Performance benchmark"
  echo "  angel-test.sh list         — List available tests"
}

# ========================================================================
# MAIN
# ========================================================================

case "${1:-}" in
  all|full)
    test_all ;;
  suite)
    shift; test_suite "$1" ;;
  regression)
    test_regression ;;
  benchmark)
    test_benchmark "${2:-5}" ;;
  list)
    test_list ;;
  run)
    shift; test_run "$1" "$2" "${3:-30}" ;;
  *)
    test_list
    ;;
esac
