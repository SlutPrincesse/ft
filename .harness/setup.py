#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - Setup Script
Initializes harness directories and integrates with existing codebase.
"""

import sys
import json
import os
from pathlib import Path
from typing import Dict, Any


def setup_harness_directories():
    """Create required harness directories."""
    dirs = [
        ".harness/tools",
        ".harness/tools/synthesized",
        ".harness/tools/global",
        ".harness/memory",
        ".harness/steering",
        ".harness/logs",
        ".harness/state",
        ".human/tools",
        ".human/skills",
        ".human/memory",
        ".human/config",
        ".shadow-fs",
    ]
    
    for d in dirs:
        Path(d).mkdir(parents=True, exist_ok=True)
        print(f"  Created: {d}")


def setup_harness_files():
    """Create required harness files."""
    files = {
        ".harness/memory/dataset.jsonl": "",
        ".harness/state/harness_state.json": json.dumps({
            "version": "1.0.0",
            "initialized_at": "2026-08-18T00:00:00",
            "task_counter": 0,
            "active_mode": "ocd",
            "neuro_modes": ["ocd", "adhd", "autistic", "bipolar", "schizophrenia", "shadow-clones"],
            "tools": {},
            "shadow_git_enabled": True,
            "stealth_enabled": False,
        }, indent=2),
        ".harness/state/tool_manifest.json": json.dumps({"tools": {}}, indent=2),
        ".harness/state/shadow_deltas.jsonl": "",
        ".harness/state/task_dag.json": json.dumps({"tasks": {}}, indent=2),
        ".human/tools/manifest.json": json.dumps({"tools": {}}, indent=2),
    }
    
    for file_path, content in files.items():
        path = Path(file_path)
        if not path.exists():
            path.write_text(content)
            print(f"  Created: {file_path}")


def verify_git_repo():
    """Verify that we're in a git repository."""
    git_dir = Path(".git")
    if not git_dir.exists():
        print("  WARNING: No git repository found. Shadow Git requires git.")
        return False
    
    # Check if there are any commits
    try:
        import subprocess
        result = subprocess.run(
            ["git", "log", "--oneline"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0 or not result.stdout.strip():
            print("  WARNING: Git repository has no commits yet.")
            return False
    except FileNotFoundError:
        print("  WARNING: git command not found.")
        return False
    
    print("  Git repository verified")
    return True


def verify_dependencies():
    """Verify that required dependencies are available."""
    dependencies = {
        "python": "Python 3.8+",
        "git": "Git",
        "cargo": "Rust/Cargo (for tool installation)",
        "gh": "GitHub CLI (for shadow-broker research)",
    }
    
    import shutil
    available = []
    missing = []
    
    for cmd, name in dependencies.items():
        if shutil.which(cmd):
            available.append(name)
        else:
            missing.append(name)
    
    print(f"  Available: {', '.join(available)}")
    if missing:
        print(f"  Missing (optional): {', '.join(missing)}")
    
    return len(missing) == 0


def run_integration():
    """Run full harness integration."""
    print("\nRunning integration...")
    
    try:
        from .harness.integration import initialize_harness
        result = initialize_harness()
        print(f"  Integration complete: {result['status']}")
        return True
    except Exception as e:
        print(f"  Integration failed: {e}")
        return False


def main():
    """Main setup entry point."""
    print("=" * 60)
    print("  AGNOSTIC-HARVESTER Harness Setup")
    print("=" * 60)
    
    print("\n[1/4] Creating harness directories...")
    setup_harness_directories()
    
    print("\n[2/4] Creating harness files...")
    setup_harness_files()
    
    print("\n[3/4] Verifying git repository...")
    git_ok = verify_git_repo()
    
    print("\n[4/4] Verifying dependencies...")
    deps_ok = verify_dependencies()
    
    print("\n[Finalizing] Running integration...")
    integration_ok = run_integration()
    
    print("\n" + "=" * 60)
    if integration_ok:
        print("  ✓ Harness setup complete!")
        print("\n  Next steps:")
        print("    1. Run: python .harness/cli.py init")
        print("    2. Run: python .harness/cli.py process --prompt 'Hello'")
        print("    3. Run: python .harness/tui.py")
    else:
        print("  ✗ Setup completed with warnings")
    print("=" * 60)


if __name__ == "__main__":
    main()
