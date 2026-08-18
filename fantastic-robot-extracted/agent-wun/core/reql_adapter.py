"""ReQL adapter for Agent-Wun.

Exposes a thin, unified interface to the reql property graph memory engine.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

try:
    from .reql.memory import (
        BlockGraphStore,
        REQLConfig,
        load_config,
        QueryResult,
        REQLError,
        REQLSyntaxError,
        REQLEvaluationError,
    )
    from .reql.memory.domain.models import MemoryNode, MemoryEdge, MemoryQuery
    from .reql.memory.query import QueryResult as QueryResultType
    _reql_available = True
except Exception as exc:  # pragma: no cover
    logger.warning("reql modules failed to import: %s", exc)
    _reql_available = False


def is_available() -> bool:
    return _reql_available


def create_store(
    config_path: str | Path | None = None,
    **kwargs: Any,
) -> BlockGraphStore | None:
    if not _reql_available:
        return None
    try:
        if config_path:
            config = load_config(Path(config_path))
        else:
            config = REQLConfig()
        store = BlockGraphStore(config=config, **kwargs)
        store.initialize()
        return store
    except Exception as exc:
        logger.error("reql create_store failed: %s", exc)
        return None


def query(
    store: BlockGraphStore,
    query_string: str,
    parameters: dict[str, Any] | None = None,
    **kwargs: Any,
) -> QueryResultType | None:
    if not _reql_available or store is None:
        return None
    try:
        return store.query(query_string, parameters=parameters or {}, **kwargs)
    except Exception as exc:
        logger.error("reql query failed: %s", exc)
        return None


def add_node(
    store: BlockGraphStore,
    node_id: str,
    labels: list[str] | None = None,
    properties: dict[str, Any] | None = None,
    **kwargs: Any,
) -> MemoryNode | None:
    if not _reql_available or store is None:
        return None
    try:
        node = MemoryNode(id=node_id, labels=labels or [], properties=properties or {})
        result, _ = store.upsert_node(node, **kwargs)
        return result
    except Exception as exc:
        logger.error("reql add_node failed: %s", exc)
        return None


def add_edge(
    store: BlockGraphStore,
    source_id: str,
    target_id: str,
    edge_type: str,
    properties: dict[str, Any] | None = None,
    **kwargs: Any,
) -> MemoryEdge | None:
    if not _reql_available or store is None:
        return None
    try:
        edge = MemoryEdge(
            id=f"{source_id}->{target_id}",
            source_id=source_id,
            target_id=target_id,
            type=edge_type,
            properties=properties or {},
        )
        result, _ = store.upsert_edge(edge, **kwargs)
        return result
    except Exception as exc:
        logger.error("reql add_edge failed: %s", exc)
        return None


def get_mcp_server(**kwargs: Any) -> Any:
    if not _reql_available:
        return None
    try:
        from mcp.server import create_server
        return create_server(**kwargs)
    except Exception as exc:
        logger.error("reql get_mcp_server failed: %s", exc)
        return None
