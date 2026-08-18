#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - Main Entry Point
Zero-cost LLM pre-processing and context optimization framework.
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from .harness_core import HarnessOrchestrator
from .harness_modules import AGNOSTIC_HARVESTER
from .shadow_broker import ShadowBroker


def cmd_init(args):
    """Initialize harness directories and state."""
    orchestrator = HarnessOrchestrator()
    orchestrator.initialize()
    print("✓ AGNOSTIC-HARVESTER Harness initialized")
    print(f"  State directory: {Path('.harness/state').absolute()}")
    print(f"  Memory directory: {Path('.harness/memory').absolute()}")
    print(f"  Tools directory: {Path('.harness/tools').absolute()}")


def cmd_process(args):
    """Process a prompt through the harness pipeline."""
    prompt = args.prompt or "Initialize harness and perform system check."
    model = args.model or "local"
    
    harness = AGNOSTIC_HARVESTER()
    result = harness.process_prompt(prompt)
    
    print(json.dumps(result, indent=2))


def cmd_research(args):
    """Shadow Broker research and planning."""
    query = args.query or "rust cli tools"
    
    broker = ShadowBroker()
    result = broker.research_and_plan(query)
    
    print(json.dumps(result, indent=2))


def cmd_status(args):
    """Show harness status."""
    orchestrator = HarnessOrchestrator()
    status = orchestrator.get_status()
    
    print(json.dumps(status, indent=2))


def cmd_audit(args):
    """Run post-queue audit."""
    orchestrator = HarnessOrchestrator()
    from .harness_modules import PostQueueAuditor
    
    auditor = PostQueueAuditor()
    report = auditor.audit(orchestrator.dag)
    
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(
        prog="agnostic-harvester",
        description="AGNOSTIC-HARVESTER Harness - Zero-cost LLM pre-processing framework"
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # init command
    subparsers.add_parser("init", help="Initialize harness directories and state")
    
    # process command
    process_parser = subparsers.add_parser("process", help="Process a prompt through the harness")
    process_parser.add_argument("--prompt", "-p", help="Prompt to process")
    process_parser.add_argument("--model", "-m", default="local", help="Model to use")
    
    # research command
    research_parser = subparsers.add_parser("research", help="Shadow Broker research")
    research_parser.add_argument("--query", "-q", help="Research query")
    
    # status command
    subparsers.add_parser("status", help="Show harness status")
    
    # audit command
    subparsers.add_parser("audit", help="Run post-queue audit")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    commands = {
        "init": cmd_init,
        "process": cmd_process,
        "research": cmd_research,
        "status": cmd_status,
        "audit": cmd_audit,
    }
    
    cmd_func = commands.get(args.command)
    if cmd_func:
        cmd_func(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
