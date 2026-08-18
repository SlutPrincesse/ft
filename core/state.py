"""Session state management (from Hermes Agent)."""
import logging
import sqlite3
import json
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime

logger = logging.getLogger("agent-wun.state")


class SessionDB:
    """SQLite-backed session store with FTS5."""

    def __init__(self, db_path: Path = None):
        self.db_path = db_path or Path("tmp/sessions.db")
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    profile TEXT DEFAULT 'default',
                    source TEXT DEFAULT 'web',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    metadata TEXT
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT,
                    role TEXT,
                    content TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (session_id) REFERENCES sessions(id)
                )
            """)
            conn.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(content, content=messages, content_rowid=id)
            """)

    def create_session(self, session_id: str, profile: str = "default", metadata: Dict = None) -> str:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT OR REPLACE INTO sessions (id, profile, metadata) VALUES (?, ?, ?)",
                (session_id, profile, json.dumps(metadata or {})),
            )
        return session_id

    def add_message(self, session_id: str, role: str, content: str):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("INSERT INTO messages (session_id, role, content) VALUES (?, ?, ?)", (session_id, role, content))
            conn.execute("UPDATE sessions SET updated_at = ? WHERE id = ?", (datetime.utcnow().isoformat(), session_id))

    def get_messages(self, session_id: str, limit: int = 100) -> List[Dict]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                "SELECT role, content, created_at FROM messages WHERE session_id = ? ORDER BY created_at ASC LIMIT ?",
                (session_id, limit),
            ).fetchall()
            return [dict(r) for r in rows]

    def search(self, query: str, limit: int = 20) -> List[Dict]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """SELECT m.session_id, m.role, m.content, m.created_at
                   FROM messages m JOIN messages_fts fts ON m.id = fts.rowid
                   WHERE messages_fts MATCH ? LIMIT ?""",
                (query, limit),
            ).fetchall()
            return [dict(r) for r in rows]


_state: Optional[SessionDB] = None


def get_state() -> SessionDB:
    global _state
    if _state is None:
        _state = SessionDB()
    return _state
