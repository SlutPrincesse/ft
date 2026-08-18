"""Configuration management for AGNOSTIC-HARVESTER."""

import os
import json
from pathlib import Path
from dataclasses import dataclass, field
from typing import Dict, Any, Optional


@dataclass
class HarnessConfig:
    """Main configuration for the harness."""
    
    # Paths
    root_dir: Path = field(default_factory=lambda: Path.cwd())
    harness_dir: Path = field(init=False)
    human_dir: Path = field(init=False)
    shadow_fs_dir: Path = field(init=False)
    
    # Harness settings
    active_mode: str = "ocd"
    shadow_git_enabled: bool = True
    stealth_enabled: bool = False
    auto_loadout: bool = True
    
    # Tool settings
    global_bin_dir: Path = field(default_factory=lambda: Path.home() / ".cargo" / "bin")
    human_bin_dir: Path = field(default_factory=lambda: Path.home() / ".human" / "bin")
    max_global_tools: int = 100
    
    # Shadow broker settings
    broker_max_results: int = 10
    broker_language: str = "rust"
    broker_pushed_after: str = ">2025"
    require_human_confirmation: bool = True
    
    # Shadow nudge settings
    nudge_timeout_seconds: int = 600
    nudge_check_interval_seconds: int = 10
    
    # Memory settings
    memory_max_records: int = 1000
    memory_compaction_threshold: int = 500
    
    # Context optimization
    target_context_headroom: float = 0.85
    max_task_queue_size: int = 100
    
    def __post_init__(self):
        self.harness_dir = self.root_dir / ".harness"
        self.human_dir = self.root_dir / ".human"
        self.shadow_fs_dir = self.root_dir / ".shadow-fs"
    
    @classmethod
    def from_file(cls, config_path: Optional[Path] = None) -> "HarnessConfig":
        """Load configuration from file."""
        if config_path is None:
            config_path = Path.cwd() / ".harness" / "config.json"
        
        if config_path.exists():
            data = json.loads(config_path.read_text())
            return cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})
        
        return cls()
    
    def to_file(self, config_path: Optional[Path] = None):
        """Save configuration to file."""
        if config_path is None:
            config_path = self.harness_dir / "config.json"
        
        config_path.parent.mkdir(parents=True, exist_ok=True)
        
        data = {
            "active_mode": self.active_mode,
            "shadow_git_enabled": self.shadow_git_enabled,
            "stealth_enabled": self.stealth_enabled,
            "auto_loadout": self.auto_loadout,
            "global_bin_dir": str(self.global_bin_dir),
            "human_bin_dir": str(self.human_bin_dir),
            "max_global_tools": self.max_global_tools,
            "broker_max_results": self.broker_max_results,
            "broker_language": self.broker_language,
            "broker_pushed_after": self.broker_pushed_after,
            "require_human_confirmation": self.require_human_confirmation,
            "nudge_timeout_seconds": self.nudge_timeout_seconds,
            "nudge_check_interval_seconds": self.nudge_check_interval_seconds,
            "memory_max_records": self.memory_max_records,
            "memory_compaction_threshold": self.memory_compaction_threshold,
            "target_context_headroom": self.target_context_headroom,
            "max_task_queue_size": self.max_task_queue_size,
        }
        
        config_path.write_text(json.dumps(data, indent=2))
    
    def ensure_directories(self):
        """Create required directories."""
        dirs = [
            self.harness_dir,
            self.harness_dir / "tools" / "synthesized",
            self.harness_dir / "tools" / "global",
            self.harness_dir / "memory",
            self.harness_dir / "steering",
            self.harness_dir / "logs",
            self.harness_dir / "state",
            self.human_dir,
            self.human_dir / "tools",
            self.human_dir / "skills",
            self.human_dir / "memory",
            self.human_dir / "config",
            self.shadow_fs_dir,
        ]
        
        for d in dirs:
            d.mkdir(parents=True, exist_ok=True)
