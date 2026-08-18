"""Agent-Wun API Layer.

Merges Agent Zero's Flask API with Hermes Agent's FastAPI gateway
and AgenticSeek's endpoints.
"""
import os
import sys
import json
import logging
from pathlib import Path
from typing import Optional, Dict, Any

# Ensure project root on path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from flask import Flask, request, jsonify, Response
from flask_cors import CORS

logger = logging.getLogger("agent-wun.api")


def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)
    app.config["JSON_AS_ASCII"] = False

    @app.get("/health")
    def health():
        return jsonify({"status": "ok", "service": "agent-wun"})

    @app.get("/api/v1/models")
    def list_models():
        from providers import get_provider_manager
        manager = get_provider_manager()
        models = []
        for name, prov in manager.providers.items():
            models.append({"provider": name, "models": prov.models if hasattr(prov, 'models') else ["auto"]})
        return jsonify({"models": models})

    @app.post("/api/v1/chat")
    def chat():
        data = request.get_json(force=True)
        messages = data.get("messages", [])
        model = data.get("model", "auto")
        from providers import get_provider_manager
        manager = get_provider_manager()
        import asyncio
        result = asyncio.run(manager.chat(messages, model=model))
        return jsonify(result)

    @app.post("/api/v1/agent/create")
    def create_agent():
        data = request.get_json(force=True)
        ctx_id = data.get("id", "default")
        profile = data.get("profile", "default")
        from core import AgentRuntime
        runtime = AgentRuntime.get_runtime()
        agent = runtime.create_agent(ctx_id, profile)
        return jsonify({"id": ctx_id, "profile": profile, "status": "created"})

    @app.post("/api/v1/agent/message")
    def agent_message():
        data = request.get_json(force=True)
        ctx_id = data.get("id", "default")
        message = data.get("message", "")
        from core import AgentRuntime
        runtime = AgentRuntime.get_runtime()
        agent = runtime.get_agent(ctx_id)
        if not agent:
            return jsonify({"error": "Agent not found"}), 404
        from core import UserMessage
        import asyncio
        result = asyncio.run(agent.monologue(UserMessage(message=message)))
        return jsonify({"response": result})

    @app.get("/api/v1/sessions")
    def list_sessions():
        from core.state import get_state
        state = get_state()
        with sqlite3.connect(state.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT id, profile, created_at FROM sessions ORDER BY updated_at DESC").fetchall()
            return jsonify({"sessions": [dict(r) for r in rows]})

    @app.get("/api/v1/sessions/<session_id>/messages")
    def get_session_messages(session_id: str):
        from core.state import get_state
        state = get_state()
        msgs = state.get_messages(session_id)
        return jsonify({"messages": msgs})

    @app.get("/api/v1/memory/search")
    def search_memory():
        query = request.args.get("q", "")
        limit = int(request.args.get("limit", 10))
        from core.memory import get_memory
        mem = get_memory()
        results = mem.search(query, limit=limit)
        return jsonify({"results": results})

    @app.post("/api/v1/memory/store")
    def store_memory():
        data = request.get_json(force=True)
        key = data.get("key")
        value = data.get("value")
        tags = data.get("tags", [])
        from core.memory import get_memory
        mem = get_memory()
        mem.store(key, value, tags)
        return jsonify({"status": "stored"})

    return app


# Runtime singleton
_runtime = None


class AgentRuntime:
    """Singleton runtime."""

    @classmethod
    def get_runtime(cls) -> "AgentRuntime":
        global _runtime
        if _runtime is None:
            _runtime = cls()
        return _runtime

    def __init__(self):
        from core.agent import AgentRuntime as CoreRuntime
        self.core = CoreRuntime()

    def create_agent(self, ctx_id: str, profile: str = "default"):
        return self.core.create_agent(ctx_id, profile)

    def get_agent(self, ctx_id: str):
        return self.core.get_agent(ctx_id)


def main():
    """Run API server."""
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5000)
    args = parser.parse_args()
    app = create_app()
    app.run(host=args.host, port=args.port, debug=False)


if __name__ == "__main__":
    main()
