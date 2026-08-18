#!/usr/bin/env python3
"""Find minimal set of Python files needed by key modules."""
import ast
import os
from pathlib import Path
from collections import deque
import shutil

STAGING = Path("/workspace/fb56b5e0-e79f-401c-ab9a-b089802077df/sessions/agent_6819029a-0d5c-44ae-8eb7-c97d5c9a40b0/agent-wun/staging")

def get_imports(filepath: Path) -> set:
    """Get all relative imports from a Python file."""
    imports = set()
    try:
        tree = ast.parse(filepath.read_text(encoding='utf-8', errors='ignore'))
    except Exception:
        return imports
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            if node.level and node.module:
                pkg = node.module.split('.')[0]
                imports.add(pkg)
    return imports

def find_package_files(pkg_name: str, search_root: Path) -> list:
    """Find all Python files in a package directory or single file."""
    results = []
    # Check if it's a directory
    pkg_dir = search_root / pkg_name
    if pkg_dir.is_dir():
        for py in pkg_dir.rglob('*.py'):
            results.append(py)
    else:
        # Check if it's a single file
        py_file = search_root / f"{pkg_name}.py"
        if py_file.is_file():
            results.append(py_file)
    return results

LOOPX_SRC = STAGING / "loopx" / "loopx"
LOOPX_DST = Path("/workspace/fb56b5e0-e79f-401c-ab9a-b089802077df/sessions/agent_6819029a-0d5c-44ae-8eb7-c97d5c9a40b0/agent-wun/core/loopx")

key_modules = [
    'todos', 'quota', 'worker_bridge', 'feedback', 'history',
    'state_refresh', 'agent_registry', 'paths', 'file_lock',
    'rollout_event_log', 'status', 'configuration_catalog',
    'contract', 'authority', 'boundary_authority', 'execution_profile',
    'orchestration', 'runtime', 'session_runtime', 'global_registry',
    'global_risks', 'global_todos', 'handoff_budget', 'heartbeat_prequota',
    'heartbeat_prompt', 'help_surface', 'host_loop_activation',
    'host_mode_planner', 'install_contract', 'interface_budget',
    'long_task_cadence', 'materials', 'onboarding', 'operator_gate',
    'presets', 'project_alias', 'project_map', 'project_prompt',
    'project_skill_cli', 'project_skill_delivery', 'project_uninstall',
    'promotion_gate', 'ready_score', 'registry_writability',
    'release_candidate', 'release_manifest', 'repository_identity',
    'review_packet', 'self_update', 'skill_install_readback',
    'slash_command_install', 'slash_commands', 'state_backup',
    'state_migration', 'state_projection', 'summary_all',
    'thread_agent_binding', 'todo_followups', 'todo_suggestion_prompt',
    'turn_identity', 'upgrade', 'visible_governance',
    'visible_multi_agent_launcher', 'visible_multi_agent_tmux',
    'domain_state', 'dreaming', 'entrypoint', 'event_sourced_state',
    'explore_graph', 'ark_managed_agent_host',
]

needed = set(key_modules)
queue = deque(key_modules)

while queue:
    mod = queue.popleft()
    files = find_package_files(mod, LOOPX_SRC)
    for f in files:
        for imp in get_imports(f):
            if imp not in needed:
                needed.add(imp)
                queue.append(imp)

print(f"Loopx needed modules: {sorted(needed)}")
print(f"Total: {len(needed)}")

# Now copy only needed files
if LOOPX_DST.exists():
    shutil.rmtree(LOOPX_DST)
LOOPX_DST.mkdir(parents=True)

for mod in sorted(needed):
    files = find_package_files(mod, LOOPX_SRC)
    for f in files:
        rel = f.relative_to(LOOPX_SRC)
        dst = LOOPX_DST / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(f.read_bytes())

py_count = sum(1 for _ in LOOPX_DST.rglob('*.py'))
total_lines = sum(1 for _ in open(f, 'r', errors='ignore').readlines() for f in LOOPX_DST.rglob('*.py'))
print(f"Copied {py_count} files, ~{total_lines} lines")
