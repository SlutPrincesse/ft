#!/usr/bin/env python3
"""Agent-Wun-Tu-Free entrypoint."""

from __future__ import annotations

import asyncio
import logging
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).parent.absolute()


def main() -> int:
    print("Agent-Wun-Tu-Free v1.0")
    print("Unified autonomous agent framework")
    print(f"Project root: {PROJECT_ROOT}")

    workspace = PROJECT_ROOT / "workspace"
    workspace.mkdir(exist_ok=True)

    sys.path.insert(0, str(PROJECT_ROOT))

    try:
        from core import loopx_adapter, taskplan_adapter, sme_adapter, trelix_adapter, reql_adapter
        print("\nCore adapters:")
        for name, mod in [
            ("loopx", loopx_adapter),
            ("taskplan", taskplan_adapter),
            ("sme", sme_adapter),
            ("trelix", trelix_adapter),
            ("reql", reql_adapter),
        ]:
            print(f"  {name}: available={mod.is_available()}")

        from provider import LLMProvider
        provider = LLMProvider()
        print(f"\nLLM Provider: available={provider.is_available()}")

        print("\nAgent-Wun-Tu-Free ready.")
        print("Run 'python -m server.api' to start the API server.")
        return 0

    except Exception as e:
        logger.error("Startup failed: %s", e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
