"""Memory management (from Hermes Agent)."""
import logging
import sqlite3
import json
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime

logger = logging.getLogger("agent-wun.memory")


class MemoryManager:
    """Persistent memory with FTS5 search."""

    def __init__(self, db_path: Path = None):
        self.db_path = db_path or Path("tmp/memory.db")
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS memories (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    key TEXT UNIQUE,
                    value TEXT,
                    tags TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(key, value, tags, content=memories, content_rowid=id)
            """)
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
                    INSERT INTO memories_fts(rowid, key, value, tags) VALUES (new.id, new.key, new.value, new.tags);
                END
            """)
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
                    INSERT INTO memories_fts(memories_fts, rowid, key, value, tags) VALUES ('delete', old.id, old.key, old.value, old.tags);
                END
            """)

    def store(self, key: str, value: str, tags: List[str] = None):
        """Store a memory."""
        tags_json = json.dumps(tags or [])
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT OR REPLACE INTO memories (key, value, tags) VALUES (?, ?, ?)",
                (key, value, tags_json),
            )

    def search(self, query: str, limit: int = 10) -> List[Dict]:
        """Full-text search across memories."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                "SELECT m.key, m.value, m.tags FROM memories m JOIN memories_fts fts ON m.id = fts.rowid WHERE memories_fts MATCH ? LIMIT ?",
                (query, limit),
            ).fetchall()
            return [dict(r) for r in rows]

    def get(self, key: str) -> Optional[str]:
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute("SELECT value FROM memories WHERE key = ?", (key,)).fetchone()
            return row[0] if row else None

    def all(self, limit: int = 100) -> List[Dict]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT key, value, tags, created_at FROM memories ORDER BY created_at DESC LIMIT ?", (limit,)).fetchall()
            return [dict(r) for r in rows]


_memory: Optional[MemoryManager] = None


def get_memory() -> MemoryManager:
    global _memory
    if _memory is None:
        _memory = MemoryManager()
    return _memory
