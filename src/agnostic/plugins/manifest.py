"""Plugin manifest and metadata."""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class PluginManifest:
    """Plugin manifest entry."""
    name: str
    version: str = "0.1.0"
    description: str = ""
    author: str = ""
    path: Path = field(default_factory=Path)
    enabled: bool = True
    config: Dict[str, Any] = field(default_factory=dict)
    tools: List[str] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    entry_point: Optional[str] = None
