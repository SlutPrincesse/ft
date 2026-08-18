"""Agent profile definitions."""

import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class AgentProfile:
    """Agent profile definition."""
    name: str
    description: str
    agent_type: str  # background, planner, optimizer, executor
    functions: List[str] = field(default_factory=list)
    config: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        """Serialize to dictionary."""
        return {
            "name": self.name,
            "description": self.description,
            "type": self.agent_type,
            "functions": self.functions,
            "config": self.config,
        }
    
    def save(self, path: Path):
        """Save profile to disk."""
        path.write_text(json.dumps(self.to_dict(), indent=2))
    
    @classmethod
    def load(cls, path: Path) -> "AgentProfile":
        """Load profile from disk."""
        data = json.loads(path.read_text())
        return cls(
            name=data["name"],
            description=data["description"],
            agent_type=data["type"],
            functions=data.get("functions", []),
            config=data.get("config", {}),
        )


def create_shadow_agent_profile() -> AgentProfile:
    """Create the shadow-agent profile."""
    return AgentProfile(
        name="shadow-agent",
        description="Background worker for auto-loadouts, error interception, and micro-tool generation",
        agent_type="background",
        functions=[
            "auto_loadout",
            "error_intercept",
            "micro_tool_gen",
            "background_research",
            "ctt_learning",
            "icrl_training",
        ],
        config={
            "auto_loadout_on_start": True,
            "error_intercept_enabled": True,
            "micro_tool_generation": True,
            "learning_enabled": True,
        },
    )


def create_shadow_broker_profile() -> AgentProfile:
    """Create the shadow-broker profile."""
    return AgentProfile(
        name="shadow-broker",
        description="Local-first planning and research specialist for GitHub repo discovery and tool installation",
        agent_type="planner",
        functions=[
            "github_repo_search",
            "tool_creation_planning",
            "global_rust_tool_install",
            "mcp_server_discovery",
            "cli_introspection",
        ],
        config={
            "search_language": "rust",
            "max_search_results": 10,
            "global_install_path": "~/.cargo/bin/",
            "require_human_confirmation": True,
        },
    )


def create_shadow_clones_profile() -> AgentProfile:
    """Create the shadow-clones profile."""
    return AgentProfile(
        name="shadow-clones",
        description="Convergent optimization profile - spawns multiple headless agents in isolated shadow-fs",
        agent_type="optimizer",
        functions=[
            "spawn_clones",
            "semantic_ast_merge",
            "best_of_best_selection",
            "shadow_fs_isolation",
        ],
        config={
            "clone_count": 5,
            "isolation_path": ".shadow-fs",
            "merge_strategy": "semantic_ast",
            "test_required": True,
        },
    )


def save_default_profiles(agents_dir: Path):
    """Save default agent profiles to disk."""
    profiles = [
        create_shadow_agent_profile(),
        create_shadow_broker_profile(),
        create_shadow_clones_profile(),
    ]
    
    for profile in profiles:
        profile_path = agents_dir / profile.name / "profile.json"
        profile_path.parent.mkdir(parents=True, exist_ok=True)
        profile.save(profile_path)
