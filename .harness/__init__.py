#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - Package Initialization
Zero-cost LLM pre-processing and context optimization framework.
"""

from .harness_core import (
    HarnessState,
    TaskDAG,
    Task,
    ToolRegistry,
    ToolManifest,
    ShadowGitEngine,
    HarnessOrchestrator,
)

from .harness_modules import (
    LEDv3LinguisticEngine,
    ContextSplicer,
    ContextOptimizer,
    ErrorRecoveryEngine,
    NeuralMemory,
    PostQueueAuditor,
    AGNOSTIC_HARVESTER,
)

from .shadow_broker import ShadowBroker, RepoCandidate, ToolPlan
from .shadow_agent import ShadowAgent, ShadowNudge, ShadowFS, ShadowTask

__version__ = "1.0.0"
__all__ = [
    # Core
    "HarnessState",
    "TaskDAG",
    "Task",
    "ToolRegistry",
    "ToolManifest",
    "ShadowGitEngine",
    "HarnessOrchestrator",
    # Modules
    "LEDv3LinguisticEngine",
    "ContextSplicer",
    "ContextOptimizer",
    "ErrorRecoveryEngine",
    "NeuralMemory",
    "PostQueueAuditor",
    "AGNOSTIC_HARVESTER",
    # Shadow
    "ShadowBroker",
    "RepoCandidate",
    "ToolPlan",
    "ShadowAgent",
    "ShadowNudge",
    "ShadowFS",
    "ShadowTask",
]
