"""Neuro-mode management for AGNOSTIC-HARVESTER."""

import asyncio
import logging
import random
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional

from ..models import NeuroMode


class NeuroModeManager:
    """
    Manages cognitive neuro-modes.
    
    Each mode changes how the harness processes tasks and makes decisions.
    """
    
    def __init__(self):
        self.current_mode = NeuroMode.OCD
        self.mode_stack: List[NeuroMode] = []
        self.logger = logging.getLogger("agnostic.cognitive.modes")
    
    def set_mode(self, mode: NeuroMode):
        """Set active neuro-mode."""
        self.current_mode = mode
        self.logger.info(f"Neuro-mode switched to: {mode.value}")
    
    def cycle_mode(self) -> NeuroMode:
        """Cycle to next neuro-mode."""
        modes = list(NeuroMode)
        current_idx = modes.index(self.current_mode)
        next_idx = (current_idx + 1) % len(modes)
        self.current_mode = modes[next_idx]
        self.logger.info(f"Neuro-mode cycled to: {self.current_mode.value}")
        return self.current_mode
    
    def get_mode_params(self) -> Dict[str, Any]:
        """Get parameters for current mode."""
        params = {
            NeuroMode.OCD: {
                "perfectionism": True,
                "test_coverage_required": True,
                "lint_required": True,
                "retry_on_failure": True,
                "max_retries": 10,
            },
            NeuroMode.ADHD: {
                "rapid_triage": True,
                "parallel_search": True,
                "easy_tasks_first": True,
                "max_parallel": 10,
            },
            NeuroMode.AUTISTIC: {
                "hyper_focus": True,
                "zero_context_switching": True,
                "single_task": True,
                "completion_required": True,
            },
            NeuroMode.BIPOLAR: {
                "dual_agent": True,
                "agent_a_temperature": 0.0,
                "agent_b_temperature": 1.0,
                "consensus_required": True,
            },
            NeuroMode.SCHIZOPHRENIA: {
                "free_random_projection": True,
                "divergent_exploration": True,
                "shadow_fs_isolation": True,
                "max_clones": 5,
            },
            NeuroMode.SHADOW_CLONES: {
                "convergent_optimization": True,
                "clone_count": 5,
                "semantic_merge": True,
                "shadow_fs_isolation": True,
            },
            NeuroMode.NECRO: {
                "legacy_exploitation": True,
                "old_repo_scan": True,
                "min_repo_age_years": 5,
            },
            NeuroMode.ORACLE: {
                "predictive_exploitation": True,
                "cve_analysis": True,
                "trending_analysis": True,
            },
            NeuroMode.DIRTYBOMB: {
                "maximum_chaos": True,
                "cascade_failure": True,
                "stealth_mode": True,
            },
        }
        return params.get(self.current_mode, {})
    
    def apply_mode_to_task(self, task: Any) -> Any:
        """Apply current mode modifications to a task."""
        params = self.get_mode_params()
        
        if self.current_mode == NeuroMode.OCD:
            task.metadata["perfectionism"] = True
            task.metadata["test_coverage_required"] = True
        elif self.current_mode == NeuroMode.ADHD:
            task.metadata["priority"] = "low"  # Easy tasks first
        elif self.current_mode == NeuroMode.AUTISTIC:
            task.metadata["exclusive_focus"] = True
        elif self.current_mode == NeuroMode.BIPOLAR:
            task.metadata["dual_agent"] = True
        elif self.current_mode == NeuroMode.SCHIZOPHRENIA:
            task.metadata["frp_enabled"] = True
        elif self.current_mode == NeuroMode.SHADOW_CLONES:
            task.metadata["clone_count"] = params.get("clone_count", 5)
        
        return task
    
    def get_mode_description(self) -> str:
        """Get human-readable description of current mode."""
        descriptions = {
            NeuroMode.OCD: "Perfectionism - Non-stop until 100% test coverage",
            NeuroMode.ADHD: "Rapid triage - Easiest tasks first, parallel searches",
            NeuroMode.AUTISTIC: "Hyper-focus - Single-task, zero switching",
            NeuroMode.BIPOLAR: "Dual-agent consensus - Low-temp logic + high-temp creativity",
            NeuroMode.SCHIZOPHRENIA: "Divergent exploration - Free-Random-Projection context distortion",
            NeuroMode.SHADOW_CLONES: "Convergent optimization - Semantic merge of best AST nodes",
            NeuroMode.NECRO: "Legacy exploitation - Scans dead repos for forgotten APIs",
            NeuroMode.ORACLE: "Predictive exploitation - Time-series CVE analysis",
            NeuroMode.DIRTYBOMB: "Maximum chaos - Cascade failure for distraction",
        }
        return descriptions.get(self.current_mode, "Unknown mode")
