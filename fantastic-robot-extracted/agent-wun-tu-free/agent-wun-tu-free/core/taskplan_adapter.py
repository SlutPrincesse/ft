"""TaskPlan adapter for Agent-Wun.

Exposes a thin, unified interface to the taskplan task management system.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

try:
    from .taskplan.client import TaskClient
    from .taskplan.selector import next_bundle, SelectorConfig, DEEP, SURFACE
    from .taskplan.workflows import TASKSOLVER, TASKWRITER, MAINTAINER, get_workflow_prompt
    _taskplan_available = True
except Exception as exc:  # pragma: no cover
    logger.warning("taskplan modules failed to import: %s", exc)
    _taskplan_available = False


def is_available() -> bool:
    return _taskplan_available


def init(db_path: str | None = None, agent_id: str = "default") -> TaskClient | None:
    if not _taskplan_available:
        return None
    try:
        return TaskClient(db_path=db_path, agent_id=agent_id)
    except Exception as exc:
        logger.error("taskplan init failed: %s", exc)
        return None


def add_task(
    title: str,
    description: str = "",
    priority: str = "medium",
    tags: str = "",
    effort: str = "",
    scope: str = "local",
    project_path: str = "",
    root_id: str = "",
    source: str = "",
    db_path: str | None = None,
) -> dict[str, Any]:
    if not _taskplan_available:
        return {"ok": False, "error": "taskplan not available"}
    try:
        client = init(db_path=db_path)
        if client is None:
            return {"ok": False, "error": "taskplan init failed"}
        result = client.add(
            title=title,
            description=description,
            priority=priority,
            tags=tags,
            effort=effort,
            scope=scope,
            project_path=project_path,
            root_id=root_id,
            source=source,
        )
        return {"ok": True, "task": result}
    except Exception as exc:
        logger.error("taskplan add_task failed: %s", exc)
        return {"ok": False, "error": str(exc)}


def list_tasks(
    status: str | None = None,
    priority: str | None = None,
    effort: str | None = None,
    scope: str | None = None,
    project_path: str | None = None,
    root_id: str | None = None,
    include_done: bool = False,
    limit: int = 50,
    db_path: str | None = None,
) -> list[dict[str, Any]]:
    if not _taskplan_available:
        return []
    try:
        client = init(db_path=db_path)
        if client is None:
            return []
        return client.list(
            status=status,
            priority=priority,
            effort=effort,
            scope=scope,
            project_path=project_path,
            root_id=root_id,
            include_done=include_done,
            limit=limit,
        )
    except Exception as exc:
        logger.error("taskplan list_tasks failed: %s", exc)
        return []


def get_next_bundle(
    role: str = "tasksolver",
    projects: list[Any] | None = None,
    db_path: str | None = None,
) -> dict[str, Any] | None:
    if not _taskplan_available:
        return None
    try:
        client = init(db_path=db_path)
        if client is None:
            return None
        config = SelectorConfig(projects=projects or [])
        bundle = next_bundle(config=config, store=client, locks=client, role=role)
        if bundle is None:
            return None
        return {
            "mode": bundle.mode,
            "effort": bundle.effort,
            "root_id": bundle.root_id,
            "project_path": bundle.project_path,
            "tasks": bundle.tasks,
        }
    except Exception as exc:
        logger.error("taskplan get_next_bundle failed: %s", exc)
        return None


def get_workflow(workflow_name: str) -> str | None:
    if not _taskplan_available:
        return None
    try:
        return get_workflow_prompt(workflow_name)
    except Exception as exc:
        logger.error("taskplan get_workflow failed: %s", exc)
        return None
