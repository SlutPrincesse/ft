"""Agent-Wun-Tu-Free memory abstraction layer.

Provides unified interface for:
- Short-term conversation memory
- Long-term vector memory (ChromaDB/FAISS)
- Spatial memory engine integration
- Graph-based memory (ReQL)
"""

from __future__ import annotations

import logging
import threading
import time
import uuid
from typing import Any, Optional

logger = logging.getLogger(__name__)


class MemoryStore:
    """Simple in-memory key-value store for agent memory."""

    def __init__(self):
        self._store: dict[str, Any] = {}
        self._lock = threading.RLock()

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        with self._lock:
            self._store[key] = {
                "value": value,
                "created_at": time.time(),
                "ttl": ttl,
                "id": str(uuid.uuid4()),
            }

    def get(self, key: str, default: Any = None) -> Any:
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return default
            if entry.get("ttl") and time.time() - entry["created_at"] > entry["ttl"]:
                del self._store[key]
                return default
            return entry["value"]

    def delete(self, key: str) -> None:
        with self._lock:
            self._store.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._store.clear()

    def keys(self) -> list[str]:
        with self._lock:
            return list(self._store.keys())


class ConversationMemory:
    """Conversation history memory."""

    def __init__(self, max_messages: int = 100):
        self.max_messages = max_messages
        self._messages: list[dict[str, Any]] = []

    def add_message(self, role: str, content: str, **kwargs: Any) -> None:
        self._messages.append({
            "role": role,
            "content": content,
            "timestamp": time.time(),
            **kwargs,
        })
        if len(self._messages) > self.max_messages:
            self._messages = self._messages[-self.max_messages:]

    def get_history(self, limit: int = 10) -> list[dict[str, Any]]:
        return self._messages[-limit:]

    def clear(self) -> None:
        self._messages.clear()


# Global memory instances
memory_store = MemoryStore()
conversation_memory = ConversationMemory()
