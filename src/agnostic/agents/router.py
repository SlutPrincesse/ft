"""Agent router for AGNOSTIC-HARVESTER."""

import importlib.util
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from ..config import HarnessConfig
from .profile import AgentProfile, save_default_profiles


class AgentRouter:
    """
    Routes tasks to appropriate agents based on profile and capabilities.
    """
    
    def __init__(self, config: HarnessConfig):
        self.config = config
        self.agents_dir = config.root_dir / "agents"
        self.profiles: Dict[str, AgentProfile] = {}
        self.logger = logging.getLogger("agnostic.agents.router")
        self._load_profiles()
    
    def _load_profiles(self):
        """Load agent profiles from disk."""
        if not self.agents_dir.exists():
            self.agents_dir.mkdir(parents=True, exist_ok=True)
            save_default_profiles(self.agents_dir)
        
        for profile_dir in self.agents_dir.iterdir():
            if not profile_dir.is_dir():
                continue
            
            profile_file = profile_dir / "profile.json"
            if profile_file.exists():
                try:
                    profile = AgentProfile.load(profile_file)
                    self.profiles[profile.name] = profile
                except (json.JSONDecodeError, KeyError) as e:
                    self.logger.warning(f"Failed to load profile {profile_dir}: {e}")
        
        self.logger.info(f"Loaded {len(self.profiles)} agent profiles")
    
    def get_profile(self, name: str) -> Optional[AgentProfile]:
        """Get agent profile by name."""
        return self.profiles.get(name)
    
    def list_profiles(self) -> List[Dict[str, Any]]:
        """List all available profiles."""
        return [profile.to_dict() for profile in self.profiles.values()]
    
    def route_task(self, task: Dict[str, Any]) -> Optional[str]:
        """
        Route a task to the most appropriate agent.
        
        Args:
            task: Task dictionary with description and metadata
            
        Returns:
            Agent name or None
        """
        description = task.get("description", "").lower()
        
        # Simple routing logic
        if "research" in description or "github" in description or "find" in description:
            return "shadow-broker"
        elif "error" in description or "fix" in description or "repair" in description:
            return "shadow-agent"
        elif "optimize" in description or "merge" in description or "best" in description:
            return "shadow-clones"
        
        return None
    
    def create_default_profiles(self):
        """Create default agent profiles."""
        save_default_profiles(self.agents_dir)
        self._load_profiles()
