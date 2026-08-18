"""File operation tools."""
import os
import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger("agent-wun.tools.files")


def read_file(path: str, limit: int = 5000) -> str:
    """Read a file safely."""
    try:
        p = Path(path)
        if not p.exists():
            return f"File not found: {path}"
        text = p.read_text(encoding="utf-8", errors="replace")
        if len(text) > limit:
            return text[:limit] + f"\n... [truncated, total {len(text)} chars]"
        return text
    except Exception as e:
        return f"Error reading file: {e}"


def write_file(path: str, content: str) -> str:
    """Write content to a file."""
    try:
        p = Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        return f"Written {len(content)} bytes to {path}"
    except Exception as e:
        return f"Error writing file: {e}"


def list_dir(path: str) -> str:
    """List directory contents."""
    try:
        p = Path(path)
        if not p.exists():
            return f"Path not found: {path}"
        items = []
        for item in sorted(p.iterdir()):
            prefix = "[DIR]" if item.is_dir() else "[FILE]"
            items.append(f"{prefix} {item.name}")
        return "\n".join(items) if items else "(empty)"
    except Exception as e:
        return f"Error listing directory: {e}"
