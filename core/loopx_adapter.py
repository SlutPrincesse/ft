"""LoopX adapter for Agent-Wun.

Exposes a thin, unified interface to the loopx goal-state and todo system.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

try:
    from .loopx.todos import add_goal_todo, list_goal_todos, update_goal_todo
    from .loopx.state_refresh import resolve_goal_state
    from .loopx.quota import goal_quota_config, quota_status
    from .loopx.feedback import record_feedback
    from .loopx.worker_bridge import build_worker_bridge_install_contract
    _loopx_available = True
except Exception as exc:  # pragma: no cover
    logger.warning("loopx modules failed to import: %s", exc)
    _loopx_available = False


def is_available() -> bool:
    return _loopx_available


def add_todo(
    goal_id: str,
    text: str,
    role: str = "agent",
    status: str | None = None,
    registry_path: Path | None = None,
    **kwargs: Any,
) -> dict[str, Any]:
    if not _loopx_available:
        return {"ok": False, "error": "loopx not available"}
    try:
        return add_goal_todo(
            goal_id=goal_id,
            text=text,
            role=role,
            status=status,
            registry_path=registry_path or Path(".loopx/registry.json"),
            **kwargs,
        )
    except Exception as exc:
        logger.error("loopx add_todo failed: %s", exc)
        return {"ok": False, "error": str(exc)}


def list_todos(
    goal_id: str,
    registry_path: Path | None = None,
    **kwargs: Any,
) -> dict[str, Any]:
    if not _loopx_available:
        return {"ok": False, "error": "loopx not available", "todos": []}
    try:
        return list_goal_todos(
            goal_id=goal_id,
            registry_path=registry_path or Path(".loopx/registry.json"),
            **kwargs,
        )
    except Exception as exc:
        logger.error("loopx list_todos failed: %s", exc)
        return {"ok": False, "error": str(exc), "todos": []}


def update_todo(
    goal_id: str,
    todo_id: str,
    registry_path: Path | None = None,
    **kwargs: Any,
) -> dict[str, Any]:
    if not _loopx_available:
        return {"ok": False, "error": "loopx not available"}
    try:
        return update_goal_todo(
            goal_id=goal_id,
            todo_id=todo_id,
            registry_path=registry_path or Path(".loopx/registry.json"),
            **kwargs,
        )
    except Exception as exc:
        logger.error("loopx update_todo failed: %s", exc)
        return {"ok": False, "error": str(exc)}


def get_quota(goal: dict[str, Any] | None = None) -> dict[str, Any]:
    if not _loopx_available:
        return {"state": "unknown", "error": "loopx not available"}
    try:
        config = goal_quota_config(goal)
        return quota_status(goal)
    except Exception as exc:
        logger.error("loopx get_quota failed: %s", exc)
        return {"state": "error", "error": str(exc)}


def record_evidence(
    goal_id: str,
    evidence: str,
    evidence_type: str = "feedback",
    **kwargs: Any,
) -> dict[str, Any]:
    if not _loopx_available:
        return {"ok": False, "error": "loopx not available"}
    try:
        return record_feedback(
            goal_id=goal_id,
            feedback=evidence,
            feedback_type=evidence_type,
            **kwargs,
        )
    except Exception as exc:
        logger.error("loopx record_evidence failed: %s", exc)
        return {"ok": False, "error": str(exc)}


def build_bridge_contract(**kwargs: Any) -> dict[str, Any]:
    if not _loopx_available:
        return {"ok": False, "error": "loopx not available"}
    try:
        return build_worker_bridge_install_contract(**kwargs)
    except Exception as exc:
        logger.error("loopx build_bridge_contract failed: %s", exc)
        return {"ok": False, "error": str(exc)}
