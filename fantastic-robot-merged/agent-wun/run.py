"""Agent-Wun Main Entry Point.

Unified entry point merging Agent Zero's run_ui, Hermes Agent's run_agent,
and AgenticSeek's api.py into a single executable.
"""
import os
import sys
import asyncio
import logging
import argparse
from pathlib import Path

# Ensure project root is on path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from core.agent import AgentRuntime, AgentConfig
from core.router import AgentRouter
from core.learning import get_learning_loop
from core.memory import get_memory
from core.state import get_state


def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[logging.StreamHandler()],
    )


def run_interactive(profile: str = "default"):
    """Interactive CLI mode."""
    setup_logging()
    runtime = AgentRuntime()
    agent = runtime.create_agent("cli", profile)
    router = AgentRouter()
    learning = get_learning_loop()

    print("Agent-Wun Interactive Mode")
    print("Type 'exit' to quit, 'memory <query>' to search memory\n")

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            break

        if not user_input:
            continue
        if user_input.lower() in ("exit", "quit"):
            break

        if user_input.startswith("memory "):
            query = user_input[7:]
            results = get_memory().search(query)
            print(f"Memory results for '{query}':")
            for r in results:
                print(f"  - {r.get('key', '')}: {r.get('value', '')[:80]}")
            continue

        # Route to best agent
        result = router.route(user_input)
        print(f"[Router] -> {result.role.value} (confidence: {result.confidence:.2f}, complexity: {result.complexity})")

        # Run agent
        from core.agent import UserMessage
        response = asyncio.run(agent.monologue(UserMessage(message=user_input)))
        print(f"Agent: {response}\n")

        # Record experience for learning
        learning.record_experience(user_input, response)

    print("\nGoodbye!")


def run_api(host: str = "127.0.0.1", port: int = 5000):
    """Run API server."""
    from api.main import create_app
    app = create_app()
    app.run(host=host, port=port, debug=False)


def main():
    parser = argparse.ArgumentParser(description="Agent-Wun Unified Agent Framework")
    parser.add_argument("mode", choices=["cli", "api", "init"], help="Run mode")
    parser.add_argument("--profile", default="default", help="Agent profile")
    parser.add_argument("--host", default="127.0.0.1", help="API host")
    parser.add_argument("--port", type=int, default=5000, help="API port")
    args = parser.parse_args()

    if args.mode == "cli":
        run_interactive(args.profile)
    elif args.mode == "api":
        run_api(args.host, args.port)
    elif args.mode == "init":
        print("Initializing Agent-Wun...")
        # Create default directories
        for d in ["tmp", "logs", "data"]:
            Path(d).mkdir(exist_ok=True)
        print("Done.")


if __name__ == "__main__":
    main()
