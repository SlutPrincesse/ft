import hashlib
import logging
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class FileHash:
    path: str
    content_hash: str
    size: int


class IncrementalIngestion:
    def __init__(self):
        self.file_hashes: Dict[str, FileHash] = {}

    def compute_file_hash(self, path: Path) -> FileHash:
        content = path.read_bytes()
        return FileHash(
            path=str(path),
            content_hash=hashlib.sha256(content).hexdigest(),
            size=len(content),
        )

    def is_changed(self, path: Path) -> bool:
        file_hash = self.compute_file_hash(path)
        prev = self.file_hashes.get(file_hash.path)
        if prev is None:
            return True
        return prev.content_hash != file_hash.content_hash

    def update(self, path: Path) -> FileHash:
        file_hash = self.compute_file_hash(path)
        self.file_hashes[file_hash.path] = file_hash
        return file_hash

    def get_changed_files(self, files: List[Path]) -> List[Path]:
        return [f for f in files if self.is_changed(f)]

    def get_unchanged_files(self, files: List[Path]) -> List[Path]:
        return [f for f in files if not self.is_changed(f)]
