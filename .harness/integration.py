#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - Integration Layer
Connects the harness to existing plugins, MCP servers, and agent infrastructure.
"""

import sys
import json
from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field
import logging

sys.path.insert(0, str(Path(__file__).parent))

from harness_core import HarnessState, TaskDAG, Task, ToolRegistry
from harness_modules import AGNOSTIC_HARVESTER, LEDv3LinguisticEngine, ContextSplicer
from shadow_broker import ShadowBroker
from shadow_agent import ShadowAgent, ShadowNudge, ShadowFS


@dataclass
class PluginManifest:
    """Plugin manifest entry."""
    name: str
    path: Path
    enabled: bool = True
    config: Dict[str, Any] = field(default_factory=dict)


class HarnessPluginIntegration:
    """Integration layer between harness and existing plugins."""
    
    def __init__(self, plugins_dir: Path = Path("plugins")):
        self.plugins_dir = plugins_dir
        self.logger = logging.getLogger("harness.integration")
        self.loaded_plugins: Dict[str, PluginManifest] = {}
    
    def discover_plugins(self) -> List[PluginManifest]:
        """Discover available plugins in the codebase."""
        plugins = []
        
        if not self.plugins_dir.exists():
            return plugins
        
        for plugin_dir in self.plugins_dir.iterdir():
            if not plugin_dir.is_dir():
                continue
            
            # Check for plugin.json or similar manifest
            manifest_files = [
                plugin_dir / "plugin.json",
                plugin_dir / ".codex-plugin" / "plugin.json",
                plugin_dir / "SKILL.md",
            ]
            
            manifest_path = None
            for mf in manifest_files:
                if mf.exists():
                    manifest_path = mf
                    break
            
            if manifest_path:
                plugin = PluginManifest(
                    name=plugin_dir.name,
                    path=plugin_dir,
                )
                
                # Load manifest if JSON
                if manifest_path.suffix == ".json":
                    try:
                        config = json.loads(manifest_path.read_text())
                        plugin.config = config
                    except json.JSONDecodeError:
                        pass
                
                plugins.append(plugin)
        
        self.logger.info(f"Discovered {len(plugins)} plugins")
        return plugins
    
    def load_plugin(self, plugin: PluginManifest) -> bool:
        """Load a plugin into the harness."""
        try:
            # Check if plugin has Python entry points
            init_file = plugin.path / "__init__.py"
            if init_file.exists():
                # Dynamic import would go here
                self.loaded_plugins[plugin.name] = plugin
                self.logger.info(f"Loaded plugin: {plugin.name}")
                return True
        except Exception as e:
            self.logger.error(f"Failed to load plugin {plugin.name}: {e}")
        
        return False
    
    def get_plugin_tools(self, plugin_name: str) -> List[Dict[str, Any]]:
        """Get tools exposed by a plugin."""
        if plugin_name not in self.loaded_plugins:
            return []
        
        plugin = self.loaded_plugins[plugin_name]
        tools = []
        
        # Check for tools directory
        tools_dir = plugin.path / "tools"
        if tools_dir.exists():
            for tool_file in tools_dir.glob("*.py"):
                tool_info = {
                    "name": tool_file.stem,
                    "path": str(tool_file),
                    "plugin": plugin_name,
                }
                tools.append(tool_info)
        
        return tools
    
    def integrate_with_harness(self, harness: AGNOSTIC_HARVESTER):
        """Integrate discovered plugins with harness."""
        plugins = self.discover_plugins()
        
        for plugin in plugins:
            if self.load_plugin(plugin):
                tools = self.get_plugin_tools(plugin.name)
                self.logger.info(f"Plugin {plugin.name} provides {len(tools)} tools")
    
    def create_tool_from_plugin(self, plugin_name: str, tool_name: str) -> Optional[Path]:
        """Create a global tool from a plugin tool."""
        if plugin_name not in self.loaded_plugins:
            return None
        
        plugin = self.loaded_plugins[plugin_name]
        source_path = plugin.path / "tools" / f"{tool_name}.py"
        
        if not source_path.exists():
            return None
        
        # Copy to global tools directory
        from harness_core import TOOLS_DIR
        dest_path = TOOLS_DIR / "global" / f"{plugin_name}_{tool_name}.py"
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            dest_path.write_text(source_path.read_text())
            dest_path.chmod(0o755)
            self.logger.info(f"Created global tool: {dest_path}")
            return dest_path
        except Exception as e:
            self.logger.error(f"Failed to create tool: {e}")
            return None


class HarnessMCPIntegration:
    """Integration layer between harness and MCP servers."""
    
    def __init__(self):
        self.logger = logging.getLogger("harness.mcp")
        self.mcp_servers: Dict[str, Dict[str, Any]] = {}
    
    def discover_mcp_servers(self) -> List[Dict[str, Any]]:
        """Discover MCP servers in the codebase."""
        servers = []
        
        # Look for MCP server configurations
        patterns = [
            "**/.mcp.json",
            "**/mcp_server*.py",
            "**/mcp*.json",
        ]
        
        for pattern in patterns:
            for path in Path(".").glob(pattern):
                try:
                    if path.suffix == ".json":
                        config = json.loads(path.read_text())
                        servers.append({
                            "name": path.parent.name,
                            "config": config,
                            "path": str(path),
                        })
                    elif path.suffix == ".py":
                        servers.append({
                            "name": path.stem,
                            "path": str(path),
                            "type": "python",
                        })
                except Exception as e:
                    self.logger.warning(f"Failed to load MCP config from {path}: {e}")
        
        self.logger.info(f"Discovered {len(servers)} MCP servers")
        return servers
    
    def register_mcp_tool(self, server_name: str, tool_name: str, schema: Dict[str, Any]):
        """Register an MCP tool in the harness tool registry."""
        from harness_core import HarnessState, ToolRegistry
        
        state = HarnessState()
        registry = ToolRegistry(state)
        
        tool_name_full = f"mcp_{server_name}_{tool_name}"
        manifest = ToolManifest(
            name=tool_name_full,
            binary_path=f"mcp://{server_name}/{tool_name}",
            schema=schema,
            source_repo=server_name,
        )
        registry.register_tool(manifest)
        
        self.logger.info(f"Registered MCP tool: {tool_name_full}")
    
    def integrate_with_harness(self, harness: AGNOSTIC_HARVESTER):
        """Integrate MCP servers with harness."""
        servers = self.discover_mcp_servers()
        
        for server in servers:
            self.logger.info(f"Integrating MCP server: {server.get('name', 'unknown')}")


class HarnessAgentIntegration:
    """Integration layer between harness and existing agents."""
    
    def __init__(self, agents_dir: Path = Path("agents")):
        self.agents_dir = agents_dir
        self.logger = logging.getLogger("harness.agents")
    
    def discover_agents(self) -> List[Dict[str, Any]]:
        """Discover available agent profiles."""
        agents = []
        
        if not self.agents_dir.exists():
            return agents
        
        for agent_dir in self.agents_dir.iterdir():
            if not agent_dir.is_dir():
                continue
            
            agent_info = {
                "name": agent_dir.name,
                "path": str(agent_dir),
                "prompts": [],
                "tools": [],
            }
            
            # Discover prompts
            prompts_dir = agent_dir / "prompts"
            if prompts_dir.exists():
                for prompt_file in prompts_dir.glob("*.md"):
                    agent_info["prompts"].append(str(prompt_file))
            
            # Discover tools
            tools_dir = agent_dir / "tools"
            if tools_dir.exists():
                for tool_file in tools_dir.glob("*.py"):
                    agent_info["tools"].append(str(tool_file))
            
            agents.append(agent_info)
        
        self.logger.info(f"Discovered {len(agents)} agent profiles")
        return agents
    
    def create_shadow_agent_profile(self) -> Dict[str, Any]:
        """Create a shadow-agent profile for the harness."""
        profile = {
            "name": "shadow-agent",
            "description": "Background worker for auto-loadouts, error interception, and micro-tool generation",
            "type": "background",
            "functions": [
                "auto_loadout",
                "error_intercept",
                "micro_tool_gen",
                "background_research",
                "ctt_learning",
                "icrl_training",
            ],
            "config": {
                "auto_loadout_on_start": True,
                "error_intercept_enabled": True,
                "micro_tool_generation": True,
                "learning_enabled": True,
            },
        }
        
        # Save profile
        profile_path = Path("agents") / "shadow-agent" / "profile.json"
        profile_path.parent.mkdir(parents=True, exist_ok=True)
        profile_path.write_text(json.dumps(profile, indent=2))
        
        self.logger.info(f"Created shadow-agent profile: {profile_path}")
        return profile
    
    def create_shadow_broker_profile(self) -> Dict[str, Any]:
        """Create a shadow-broker agent profile for planning and research."""
        profile = {
            "name": "shadow-broker",
            "description": "Local-first planning and research specialist for GitHub repo discovery and tool installation",
            "type": "planner",
            "functions": [
                "github_repo_search",
                "tool_creation_planning",
                "global_rust_tool_install",
                "mcp_server_discovery",
                "cli_introspection",
            ],
            "config": {
                "search_language": "rust",
                "max_search_results": 10,
                "global_install_path": "~/.cargo/bin/",
                "require_human_confirmation": True,
            },
        }
        
        # Save profile
        profile_path = Path("agents") / "shadow-broker" / "profile.json"
        profile_path.parent.mkdir(parents=True, exist_ok=True)
        profile_path.write_text(json.dumps(profile, indent=2))
        
        self.logger.info(f"Created shadow-broker profile: {profile_path}")
        return profile
    
    def create_shadow_clones_profile(self) -> Dict[str, Any]:
        """Create a shadow-clones agent profile for convergent optimization."""
        profile = {
            "name": "shadow-clones",
            "description": "Convergent optimization profile - spawns multiple headless agents in isolated shadow-fs",
            "type": "optimizer",
            "functions": [
                "spawn_clones",
                "semantic_ast_merge",
                "best_of_best_selection",
                "shadow_fs_isolation",
            ],
            "config": {
                "clone_count": 5,
                "isolation_path": ".shadow-fs",
                "merge_strategy": "semantic_ast",
                "test_required": True,
            },
        }
        
        # Save profile
        profile_path = Path("agents") / "shadow-clones" / "profile.json"
        profile_path.parent.mkdir(parents=True, exist_ok=True)
        profile_path.write_text(json.dumps(profile, indent=2))
        
        self.logger.info(f"Created shadow-clones profile: {profile_path}")
        return profile


class HarnessIntegration:
    """Main integration class that ties everything together."""
    
    def __init__(self):
        self.logger = logging.getLogger("harness.integration")
        self.plugins = HarnessPluginIntegration()
        self.mcp = HarnessMCPIntegration()
        self.agents = HarnessAgentIntegration()
        self.harness = AGNOSTIC_HARVESTER()
    
    def full_integration(self) -> Dict[str, Any]:
        """Perform full integration with existing codebase."""
        self.logger.info("Starting full harness integration...")
        
        result = {
            "plugins": {"discovered": 0, "loaded": 0, "tools": 0},
            "mcp": {"discovered": 0, "registered": 0},
            "agents": {"discovered": 0, "profiles_created": 0},
        }
        
        # Plugin integration
        discovered_plugins = self.plugins.discover_plugins()
        result["plugins"]["discovered"] = len(discovered_plugins)
        
        for plugin in discovered_plugins:
            if self.plugins.load_plugin(plugin):
                result["plugins"]["loaded"] += 1
                tools = self.plugins.get_plugin_tools(plugin.name)
                result["plugins"]["tools"] += len(tools)
        
        self.plugins.integrate_with_harness(self.harness)
        
        # MCP integration
        discovered_mcp = self.mcp.discover_mcp_servers()
        result["mcp"]["discovered"] = len(discovered_mcp)
        
        for server in discovered_mcp:
            result["mcp"]["registered"] += 1
        
        self.mcp.integrate_with_harness(self.harness)
        
        # Agent profiles
        discovered_agents = self.agents.discover_agents()
        result["agents"]["discovered"] = len(discovered_agents)
        
        # Create shadow agent profiles
        self.agents.create_shadow_agent_profile()
        self.agents.create_shadow_broker_profile()
        self.agents.create_shadow_clones_profile()
        result["agents"]["profiles_created"] = 3
        
        self.logger.info("Full integration complete")
        return result
    
    def get_integration_summary(self) -> Dict[str, Any]:
        """Get summary of integration status."""
        return {
            "plugins": {
                "discovered": len(self.plugins.discover_plugins()),
                "loaded": len(self.plugins.loaded_plugins),
            },
            "mcp_servers": len(self.mcp.mcp_servers),
            "agent_profiles": len(self.agents.discover_agents()) + 3,
            "harness_ready": True,
        }


def initialize_harness() -> Dict[str, Any]:
    """Initialize and integrate the harness with the existing codebase."""
    integration = HarnessIntegration()
    
    # Perform full integration
    integration_result = integration.full_integration()
    
    # Initialize harness
    from harness_core import HarnessOrchestrator
    orchestrator = HarnessOrchestrator()
    orchestrator.initialize()
    
    # Get status
    status = orchestrator.get_status()
    
    return {
        "status": "initialized",
        "integration": integration_result,
        "harness": status,
    }
