import json
import hashlib
from pathlib import Path
from typing import List, Optional, Dict, Any
from dataclasses import dataclass, field, asdict
import ast
import logging
import sqlite3

logger = logging.getLogger(__name__)


@dataclass
class ShardMetadata:
    shard_id: str
    category: str
    shard_type: str  # function, class, module
    source_repo: str
    source_file: str
    name: str
    description: str
    cyclomatic_complexity: int
    import_dependencies: List[str]
    tags: List[str] = field(default_factory=list)
    created_at: str = ""


class ShardFilestore:
    def __init__(self, filestore_root: str = "/workspace/fb56b5e0-e79f-401c-ab9a-b089802077df/sessions/agent_7d57fcd3-cff4-4c4c-a0e7-52036b0c18d6/py_filestore"):
        self.root = Path(filestore_root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.shards_dir = self.root / "shards"
        for d in ["functions", "classes", "modules"]:
            (self.shards_dir / d).mkdir(parents=True, exist_ok=True)
        self.metadata_dir = self.root / "metadata"
        self.metadata_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.metadata_dir / "metadata.db"
        self._init_db()

    def _init_db(self):
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS shards (
                shard_id TEXT PRIMARY KEY,
                category TEXT,
                shard_type TEXT,
                source_repo TEXT,
                source_file TEXT,
                name TEXT,
                description TEXT,
                cyclomatic_complexity INTEGER,
                import_dependencies TEXT,
                tags TEXT,
                created_at TEXT
            )
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_category ON shards(category)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_type ON shards(shard_type)")
        conn.commit()
        conn.close()

    def store_shard(self, shard: Any, metadata: ShardMetadata) -> str:
        shard_type = metadata.shard_type
        shard_dir = self.shards_dir / shard_type / metadata.category
        shard_dir.mkdir(parents=True, exist_ok=True)

        file_path = shard_dir / f"{metadata.shard_id}.py"
        source_code = getattr(shard, "source_code", getattr(shard, "body", ""))
        file_path.write_text(source_code, encoding="utf-8")

        sidecar_path = shard_dir / f"{metadata.shard_id}.json"
        record = {
            "shard_id": metadata.shard_id,
            "category": metadata.category,
            "shard_type": metadata.shard_type,
            "source_repo": metadata.source_repo,
            "source_file": metadata.source_file,
            "name": metadata.name,
            "description": metadata.description,
            "cyclomatic_complexity": metadata.cyclomatic_complexity,
            "import_dependencies": metadata.import_dependencies,
            "tags": metadata.tags,
            "created_at": metadata.created_at,
            "source_code": source_code,
        }
        sidecar_path.write_text(json.dumps(record, indent=2), encoding="utf-8")

        conn = sqlite3.connect(self.db_path)
        conn.execute(
            "INSERT OR REPLACE INTO shards VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (
                metadata.shard_id,
                metadata.category,
                metadata.shard_type,
                metadata.source_repo,
                metadata.source_file,
                metadata.name,
                metadata.description,
                metadata.cyclomatic_complexity,
                json.dumps(metadata.import_dependencies),
                json.dumps(metadata.tags),
                metadata.created_at,
            ),
        )
        conn.commit()
        conn.close()
        return metadata.shard_id

    def get_shard(self, shard_id: str) -> Optional[Dict[str, Any]]:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.execute("SELECT * FROM shards WHERE shard_id = ?", (shard_id,))
        row = cursor.fetchone()
        conn.close()
        if not row:
            return None
        columns = ["shard_id", "category", "shard_type", "source_repo", "source_file", "name",
                   "description", "cyclomatic_complexity", "import_dependencies", "tags", "created_at"]
        return dict(zip(columns, row))

    def search_shards(self, category: Optional[str] = None, shard_type: Optional[str] = None, name_contains: Optional[str] = None) -> List[Dict[str, Any]]:
        conn = sqlite3.connect(self.db_path)
        query = "SELECT * FROM shards WHERE 1=1"
        params = []
        if category:
            query += " AND category = ?"
            params.append(category)
        if shard_type:
            query += " AND shard_type = ?"
            params.append(shard_type)
        if name_contains:
            query += " AND name LIKE ?"
            params.append(f"%{name_contains}%")
        cursor = conn.execute(query, params)
        columns = ["shard_id", "category", "shard_type", "source_repo", "source_file", "name",
                   "description", "cyclomatic_complexity", "import_dependencies", "tags", "created_at"]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        conn.close()
        return results

    def list_categories(self) -> List[str]:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.execute("SELECT DISTINCT category FROM shards")
        cats = [row[0] for row in cursor.fetchall()]
        conn.close()
        return cats
