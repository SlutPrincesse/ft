"""AGNOSTIC-HARVESTER - Zero-cost LLM pre-processing and context optimization framework."""

__version__ = "2.0.0"
__author__ = "AGNOSTIC-HARVESTER Team"
__description__ = "Zero-cost LLM pre-processing and context optimization framework"

from .config import HarnessConfig
from .engine.orchestrator import HarnessOrchestrator
from .engine.task_dag import TaskDAG, Task
from .engine.context import ContextOptimizer
from .cognitive.context import LEDv3LinguisticEngine
from .cognitive.modes import NeuroModeManager
from .cognitive.memory import SevenLayerMemory
from .shadow.broker import ShadowBroker
from .shadow.agent import ShadowAgent
from .shadow.nudge import ShadowNudge
from .shadow.fs import ShadowFS
from .tools.registry import ToolRegistry
from .tools.synthesizer import ToolSynthesizer
from .ui.tui import HarnessTUI

__all__ = [
    "HarnessConfig",
    "HarnessOrchestrator",
    "TaskDAG",
    "Task",
    "ContextOptimizer",
    "LEDv3LinguisticEngine",
    "NeuroModeManager",
    "SevenLayerMemory",
    "ShadowBroker",
    "ShadowAgent",
    "ShadowNudge",
    "ShadowFS",
    "ToolRegistry",
    "ToolSynthesizer",
    "HarnessTUI",
]
