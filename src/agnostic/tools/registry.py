"""Tool registry for global tool management."""

import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional

from ..models import ToolManifest


class ToolRegistry:
    """
    Global registry for dynamically installed Rust tools and MCP servers.
    """
    
    def __init__(self, state_dir: Path):
        self.state_dir = state_dir
        self.manifest_file = state_dir / "tool_manifest.json"
        self.tools: Dict[str, ToolManifest] = {}
        self.logger = logging.getLogger("agnostic.tools.registry")
        self._load_manifest()
    
    def _load_manifest(self):
        """Load tool manifest from disk."""
        if self.manifest_file.exists():
            try:
                data = json.loads(self.manifest_file.read_text())
                for name, entry in data.get("tools", {}).items():
                    self.tools[name] = ToolManifest(
                        name=name,
                        binary_path=entry["binary_path"],
                        schema=entry.get("schema", {}),
                        source_repo=entry.get("source_repo"),
                        version=entry.get("version"),
                        installed_at=entry.get("installed_at", ""),
                        last_verified=entry.get("last_verified"),
                        verified=entry.get("verified", False),
                    )
            except (json.JSONDecodeError, KeyError) as e:
                self.logger.warning(f"Failed to load tool manifest: {e}")
    
    def register_tool(self, manifest: ToolManifest):
        """Register a new tool in the global manifest."""
        self.tools[manifest.name] = manifest
        self.save()
        self.logger.info(f"Registered tool: {manifest.name}")
    
    def unregister_tool(self, name: str) -> bool:
        """Unregister a tool."""
        if name in self.tools:
            del self.tools[name]
            self.save()
            self.logger.info(f"Unregistered tool: {name}")
            return True
        return False
    
    def get_tool(self, name: str) -> Optional[ToolManifest]:
        """Get tool by name."""
        return self.tools.get(name)
    
    def list_tools(self) -> List[Dict[str, Any]]:
        """List all registered tools."""
        return [
            {
                "name": name,
                "binary_path": tool.binary_path,
                "source_repo": tool.source_repo,
                "version": tool.version,
                "verified": tool.verified,
            }
            for name, tool in self.tools.items()
        ]
    
    def verify_tool(self, name: str) -> bool:
        """Verify that a tool is still available."""
        tool = self.tools.get(name)
        if not tool:
            return False
        
        binary_path = Path(tool.binary_path)
        if not binary_path.exists():
            return False
        
        tool.verified = True
        tool.last_verified = datetime.utcnow().isoformat()
        self.save()
        return True
    
    def save(self):
        """Persist tool manifest to disk."""
        data = {
            "tools": {
                name: {
                    "binary_path": t.binary_path,
                    "schema": t.schema,
                    "source_repo": t.source_repo,
                    "version": t.version,
                    "installed_at": t.installed_at,
                    "last_verified": t.last_verified,
                    "verified": t.verified,
                }
                for name, t in self.tools.items()
            }
        }
        self.manifest_file.write_text(json.dumps(data, indent=2))
