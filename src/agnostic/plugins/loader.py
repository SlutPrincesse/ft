"""Plugin loader for AGNOSTIC-HARVESTER."""

import importlib.util
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from .manifest import PluginManifest


class PluginLoader:
    """
    Discovers and loads plugins from the plugins directory.
    """
    
    def __init__(self, plugins_dir: Path):
        self.plugins_dir = plugins_dir
        self.logger = logging.getLogger("agnostic.plugins.loader")
        self.loaded_plugins: Dict[str, PluginManifest] = {}
    
    def discover(self) -> List[PluginManifest]:
        """Discover available plugins."""
        plugins = []
        
        if not self.plugins_dir.exists():
            return plugins
        
        for plugin_dir in self.plugins_dir.iterdir():
            if not plugin_dir.is_dir():
                continue
            
            manifest_path = plugin_dir / "plugin.json"
            if not manifest_path.exists():
                continue
            
            try:
                data = json.loads(manifest_path.read_text())
                manifest = PluginManifest(
                    name=data.get("name", plugin_dir.name),
                    version=data.get("version", "0.1.0"),
                    description=data.get("description", ""),
                    author=data.get("author", ""),
                    path=plugin_dir,
                    enabled=data.get("enabled", True),
                    config=data.get("config", {}),
                    tools=data.get("tools", []),
                    dependencies=data.get("dependencies", []),
                    entry_point=data.get("entry_point"),
                )
                plugins.append(manifest)
            except (json.JSONDecodeError, KeyError) as e:
                self.logger.warning(f"Failed to load plugin manifest {plugin_dir}: {e}")
        
        self.logger.info(f"Discovered {len(plugins)} plugins")
        return plugins
    
    def load(self, manifest: PluginManifest) -> bool:
        """Load a plugin."""
        if not manifest.enabled:
            return False
        
        try:
            if manifest.entry_point:
                spec = importlib.util.spec_from_file_location(
                    manifest.name,
                    manifest.path / manifest.entry_point
                )
                if spec and spec.loader:
                    module = importlib.util.module_from_spec(spec)
                    sys.modules[manifest.name] = module
                    spec.loader.exec_module(module)
            
            self.loaded_plugins[manifest.name] = manifest
            self.logger.info(f"Loaded plugin: {manifest.name}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to load plugin {manifest.name}: {e}")
            return False
    
    def load_all(self) -> List[str]:
        """Discover and load all plugins."""
        manifests = self.discover()
        loaded = []
        
        for manifest in manifests:
            if self.load(manifest):
                loaded.append(manifest.name)
        
        return loaded
    
    def get_plugin(self, name: str) -> Optional[PluginManifest]:
        """Get loaded plugin by name."""
        return self.loaded_plugins.get(name)
    
    def get_plugin_tools(self, name: str) -> List[Dict[str, Any]]:
        """Get tools exposed by a plugin."""
        plugin = self.loaded_plugins.get(name)
        if not plugin:
            return []
        
        tools = []
        for tool_name in plugin.tools:
            tools.append({
                "name": tool_name,
                "plugin": name,
                "path": str(plugin.path / "tools" / f"{tool_name}.py"),
            })
        
        return tools
