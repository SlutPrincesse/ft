#!/usr/bin/env python3
"""Agent-Wun-Tu-Free API server."""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path
from typing import Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))


def _try_import_flask():
    try:
        from flask import Flask, jsonify, request, Response
        return Flask, jsonify, request, Response, True
    except ImportError:
        return None, None, None, None, False


def create_app() -> Any | None:
    Flask, jsonify, request, Response, flask_available = _try_import_flask()
    if not flask_available:
        logger.error("Flask is not installed. Install with: pip install flask")
        return None

    app = Flask(__name__)
    app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "agent-wun-tu-free-secret")

    _agent_store: dict[str, Any] = {}

    def _get_agent(agent_id: str) -> Any | None:
        if agent_id not in _agent_store:
            try:
                from agent import Agent, AgentConfig
                cfg = AgentConfig(id=agent_id, name=agent_id, profile="default")
                _agent_store[agent_id] = Agent(config=cfg, agent_name=agent_id)
            except Exception as exc:
                logger.error("Failed to create agent %s: %s", agent_id, exc)
                return None
        return _agent_store[agent_id]

    @app.route("/health", methods=["GET"])
    def health():
        return jsonify({"status": "ok", "project": "agent-wun-tu-free", "version": "1.0"})

    @app.route("/api/v1/status", methods=["GET"])
    def status():
        status_info = {"project": "agent-wun-tu-free", "version": "1.0", "modules": {}, "agents": {}}
        try:
            from core import loopx_adapter, taskplan_adapter, sme_adapter, trelix_adapter, reql_adapter
            for name, mod in [
                ("loopx", loopx_adapter),
                ("taskplan", taskplan_adapter),
                ("sme", sme_adapter),
                ("trelix", trelix_adapter),
                ("reql", reql_adapter),
            ]:
                status_info["modules"][name] = {"available": mod.is_available()}
        except Exception as exc:
            status_info["modules"]["error"] = str(exc)

        try:
            from provider import LLMProvider
            provider = LLMProvider()
            status_info["provider"] = {"available": provider.is_available(), "provider": provider.provider, "model": provider.model}
        except Exception as exc:
            status_info["provider"] = {"error": str(exc)}

        for agent_id in list(_agent_store.keys())[:5]:
            agent = _agent_store[agent_id]
            status_info["agents"][agent_id] = {"name": agent.agent_name, "tools": agent.list_tools()}

        return jsonify(status_info)

    @app.route("/api/v1/chat", methods=["POST"])
    def chat():
        data = request.get_json(force=True, silent=True) or {}
        agent_id = data.get("agent_id", "default")
        message = data.get("message", "")
        model = data.get("model")
        if not message:
            return jsonify({"error": "message is required"}), 400
        agent = _get_agent(agent_id)
        if agent is None:
            return jsonify({"error": f"failed to create agent: {agent_id}"}), 500
        try:
            from provider import LLMProvider
            provider = LLMProvider()
            messages = [{"role": "user", "content": message}]
            import asyncio
            reply = asyncio.run(provider.chat(messages, model=model))
            agent.hist_add_message("user", message)
            agent.hist_add_message("assistant", reply)
            return jsonify({"agent_id": agent_id, "reply": reply})
        except Exception as exc:
            logger.error("Chat failed: %s", exc)
            return jsonify({"error": str(exc)}), 500

    @app.route("/api/v1/agents", methods=["GET"])
    def list_agents():
        agents_dir = PROJECT_ROOT / "agents"
        result = []
        if agents_dir.exists():
            for entry in agents_dir.iterdir():
                if entry.is_dir() and not entry.name.startswith("_"):
                    result.append({"id": entry.name, "path": str(entry.relative_to(PROJECT_ROOT))})
        return jsonify({"agents": result})

    @app.route("/api/v1/tools", methods=["GET"])
    def list_tools():
        agent_id = request.args.get("agent_id", "default")
        agent = _get_agent(agent_id)
        if agent is None:
            return jsonify({"error": "agent not found"}), 404
        return jsonify({"tools": agent.list_tools()})

    @app.route("/api/v1/providers", methods=["GET"])
    def list_providers():
        try:
            from provider import LLMProvider
            provider = LLMProvider()
            return jsonify({"provider": provider.provider, "model": provider.model, "available": provider.is_available(), "models": provider.list_models()})
        except Exception as exc:
            return jsonify({"error": str(exc)}), 500

    return app


def main() -> int:
    app = create_app()
    if app is None:
        return 1
    port = int(os.getenv("PORT", 8080))
    logger.info("Starting Agent-Wun-Tu-Free API on port %d", port)
    app.run(host="0.0.0.0", port=port, debug=False, use_reloader=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
