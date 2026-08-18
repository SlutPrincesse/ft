"""Spatial Memory Engine adapter for Agent-Wun.

Exposes a thin, unified interface to the SME spatial memory system.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

try:
    from .sme.engine import SpatialMemoryEngine
    from .sme.config import SMEConfig
    from .sme.models import Memory, Region, SearchHit, ScoreBreakdown
    from .sme.retrieval.retriever import Retriever
    from .sme.storage import StorageBackend
    _sme_available = True
except Exception as exc:  # pragma: no cover
    logger.warning("sme modules failed to import: %s", exc)
    _sme_available = False


def is_available() -> bool:
    return _sme_available


def create_engine(
    config_path: str | Path | None = None,
    storage_path: str | Path | None = None,
    **kwargs: Any,
) -> SpatialMemoryEngine | None:
    if not _sme_available:
        return None
    try:
        cfg = SMEConfig()
        if config_path:
            cfg.load(Path(config_path))
        engine = SpatialMemoryEngine(config=cfg, storage_path=storage_path, **kwargs)
        return engine
    except Exception as exc:
        logger.error("sme create_engine failed: %s", exc)
        return None


def add_memory(
    engine: SpatialMemoryEngine,
    content: str,
    metadata: dict[str, Any] | None = None,
    **kwargs: Any,
) -> Memory | None:
    if not _sme_available or engine is None:
        return None
    try:
        return engine.add_memory(content=content, metadata=metadata or {}, **kwargs)
    except Exception as exc:
        logger.error("sme add_memory failed: %s", exc)
        return None


def search(
    engine: SpatialMemoryEngine,
    query: str,
    top_k: int = 10,
    **kwargs: Any,
) -> list[SearchHit]:
    if not _sme_available or engine is None:
        return []
    try:
        retriever = Retriever(engine)
        return retriever.search(query, top_k=top_k, **kwargs)
    except Exception as exc:
        logger.error("sme search failed: %s", exc)
        return []


def get_regions(engine: SpatialMemoryEngine) -> list[Region]:
    if not _sme_available or engine is None:
        return []
    try:
        return engine.get_regions()
    except Exception as exc:
        logger.error("sme get_regions failed: %s", exc)
        return []


def get_memory_graph(engine: SpatialMemoryEngine) -> Any:
    if not _sme_available or engine is None:
        return None
    try:
        return engine.get_memory_graph()
    except Exception as exc:
        logger.error("sme get_memory_graph failed: %s", exc)
        return None
