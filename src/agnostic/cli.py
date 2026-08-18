#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - CLI Entry Point
"""

import asyncio
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from agnostic.config import HarnessConfig
from agnostic.ui.tui import HarnessTUI


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        prog="agnostic",
        description="AGNOSTIC-HARVESTER Harness - Zero-cost LLM pre-processing framework"
    )
    
    parser.add_argument(
        "--config", "-c",
        type=Path,
        help="Path to configuration file"
    )
    parser.add_argument(
        "--tui", "-t",
        action="store_true",
        help="Launch interactive TUI"
    )
    parser.add_argument(
        "--prompt", "-p",
        type=str,
        help="Process a prompt and exit"
    )
    parser.add_argument(
        "--audit", "-a",
        action="store_true",
        help="Run audit and exit"
    )
    parser.add_argument(
        "--init", "-i",
        action="store_true",
        help="Initialize harness and exit"
    )
    
    args = parser.parse_args()
    
    config = HarnessConfig.from_file(args.config)
    
    if args.init:
        config.ensure_directories()
        config.to_file()
        print("Harness initialized")
        return
    
    if args.tui:
        tui = HarnessTUI(config)
        tui.start()
        return
    
    if args.prompt:
        async def run_prompt():
            orchestrator = HarnessOrchestrator(config)
            result = await orchestrator.process_prompt(args.prompt)
            print(result)
        
        asyncio.run(run_prompt())
        return
    
    if args.audit:
        orchestrator = HarnessOrchestrator(config)
        report = orchestrator.run_audit()
        print(report)
        return
    
    # Default: launch TUI
    tui = HarnessTUI(config)
    tui.start()


if __name__ == "__main__":
    main()
