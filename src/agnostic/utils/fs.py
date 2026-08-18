"""Filesystem utilities."""

import hashlib
import os
import shutil
from pathlib import Path
from typing import List, Optional


class FileUtils:
    """Filesystem utility functions."""
    
    @staticmethod
    def ensure_dir(path: Path):
        """Ensure directory exists."""
        path.mkdir(parents=True, exist_ok=True)
    
    @staticmethod
    def compute_hash(file_path: Path, algorithm: str = "sha256") -> str:
        """Compute file hash."""
        h = hashlib.new(algorithm)
        with open(file_path, "rb") as f:
            while chunk := f.read(8192):
                h.update(chunk)
        return h.hexdigest()
    
    @staticmethod
    def copy_file(src: Path, dst: Path, overwrite: bool = False):
        """Copy file with optional overwrite."""
        if not overwrite and dst.exists():
            return False
        shutil.copy2(src, dst)
        return True
    
    @staticmethod
    def remove_path(path: Path):
        """Remove file or directory."""
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()
    
    @staticmethod
    def list_files(directory: Path, extensions: Optional[List[str]] = None) -> List[Path]:
        """List files in directory with optional extension filter."""
        files = []
        for f in directory.rglob("*"):
            if f.is_file():
                if extensions is None or f.suffix in extensions:
                    files.append(f)
        return files
