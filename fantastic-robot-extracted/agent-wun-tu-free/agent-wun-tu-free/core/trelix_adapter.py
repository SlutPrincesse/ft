"""Trelix adapter for Agent-Wun.

Exposes a thin, unified interface to the trelix code indexing and retrieval system.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

try:
    from .trelix.indexing.indexer import Indexer
    from .trelix.retrieval.retriever import Retriever
    from .trelix.core.config import IndexConfig, EmbedderConfig
    from .trelix.store.sqlite_store import SQLiteStore
    _trelix_available = True
except Exception as exc:  # pragma: no cover
    logger.warning("trelix modules failed to import: %s", exc)
    _trelix_available = False


def is_available() -> bool:
    return _trelix_available


def index_repo(
    repo_path: str | Path,
    store_path: str | Path | None = None,
    **kwargs: Any,
) -> dict[str, Any]:
    if not _trelix_available:
        return {"ok": False, "error": "trelix not available"}
    try:
        config = IndexConfig(repo_path=str(repo_path))
        indexer = Indexer(config)
        result = indexer.index()
        return {"ok": True, "result": result}
    except Exception as exc:
        logger.error("trelix index_repo failed: %s", exc)
        return {"ok": False, "error": str(exc)}


def search(
    repo_path: str | Path,
    query: str,
    top_k: int = 10,
    expand_call_graph: bool = False,
    **kwargs: Any,
) -> dict[str, Any]:
    if not _trelix_available:
        return {"ok": False, "error": "trelix not available", "context": ""}
    try:
        config = IndexConfig(repo_path=str(repo_path))
        retriever = Retriever(config)
        result = retriever.retrieve(query, top_k=top_k, expand_call_graph=expand_call_graph, **kwargs)
        return {
            "ok": True,
            "context_text": getattr(result, "context_text", ""),
            "chunks": getattr(result, "chunks", []),
            "score": getattr(result, "score", 0.0),
        }
    except Exception as exc:
        logger.error("trelix search failed: %s", exc)
        return {"ok": False, "error": str(exc), "context": ""}


def create_store(store_path: str | Path) -> SQLiteStore | None:
    if not _trelix_available:
        return None
    try:
        return SQLiteStore(str(store_path))
    except Exception as exc:
        logger.error("trelix create_store failed: %s", exc)
        return None
