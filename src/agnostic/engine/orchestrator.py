"""Main orchestrator for AGNOSTIC-HARVESTER."""

import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, Optional

from ..config import HarnessConfig
from ..models import TaskStatus, NeuroMode, AuditReport
from ..engine.task_dag import TaskDAG
from ..engine.context import ContextOptimizer
from ..engine.pipeline import ExecutionPipeline
from ..cognitive.context import LEDv3LinguisticEngine
from ..cognitive.modes import NeuroModeManager
from ..cognitive.memory import SevenLayerMemory
from ..shadow.broker import ShadowBroker
from ..shadow.agent import ShadowAgent
from ..shadow.nudge import ShadowNudge
from ..shadow.fs import ShadowFS
from ..tools.registry import ToolRegistry
from ..tools.synthesizer import ToolSynthesizer


class HarnessOrchestrator:
    """
    Main orchestrator for the AGNOSTIC-HARVESTER harness.
    
    Coordinates all modules: cognitive, shadow, tools, engine, and UI.
    """
    
    def __init__(self, config: Optional[HarnessConfig] = None):
        self.config = config or HarnessConfig.from_file()
        self.config.ensure_directories()
        
        self._setup_logging()
        self.logger = logging.getLogger("agnostic.orchestrator")
        
        # Initialize core components
        self.task_dag = TaskDAG(self.config.harness_dir / "state")
        self.task_dag.load()
        
        self.led = LEDv3LinguisticEngine()
        self.optimizer = ContextOptimizer()
        self.memory = SevenLayerMemory(self.config.harness_dir / "memory")
        self.mode_manager = NeuroModeManager()
        
        # Tool system
        self.tool_registry = ToolRegistry(self.config.harness_dir / "state")
        self.tool_synthesizer = ToolSynthesizer(self.config.harness_dir / "tools")
        
        # Shadow system
        self.shadow_broker = ShadowBroker(self.config)
        self.shadow_agent = ShadowAgent(self.config)
        self.shadow_nudge = ShadowNudge(self.config.nudge_timeout_seconds)
        self.shadow_fs = ShadowFS(self.config.shadow_fs_dir)
        
        # Pipeline
        self.pipeline = ExecutionPipeline(
            task_dag=self.task_dag,
            led=self.led,
            optimizer=self.optimizer,
            tool_registry=self.tool_registry,
            tool_synthesizer=self.tool_synthesizer,
        ).build_default_pipeline()
        
        self.logger.info("AGNOSTIC-HARVESTER Harness initialized")
    
    def _setup_logging(self):
        """Configure logging."""
        log_dir = self.config.harness_dir / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        
        log_file = log_dir / "harness.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout),
            ],
        )
    
    async def process_prompt(self, prompt: str, model: str = "local") -> Dict[str, Any]:
        """
        Process a prompt through the full harness pipeline.
        
        Args:
            prompt: User prompt
            model: Model identifier
            
        Returns:
            Processing result
        """
        self.logger.info(f"Processing prompt: {prompt[:100]}...")
        
        context = {
            "prompt": prompt,
            "model": model,
        }
        
        result = await self.pipeline.execute(context)
        
        # Record to memory
        self.memory.record_execution(result)
        
        return result
    
    def get_status(self) -> Dict[str, Any]:
        """Get current harness status."""
        return {
            "version": "2.0.0",
            "active_mode": self.mode_manager.current_mode.value,
            "task_stats": self.task_dag.get_stats(),
            "tool_count": len(self.tool_registry.list_tools()),
            "shadow_deltas": len(self.memory.get_recent_deltas(limit=10)),
            "memory_records": len(self.memory.get_recent_tasks(limit=10)),
            "shadow_worktrees": len(self.shadow_fs.list_worktrees()),
        }
    
    def run_audit(self) -> AuditReport:
        """Run post-queue audit."""
        return self.memory.audit(self.task_dag)
    
    async def shadow_broker_research(self, query: str) -> Dict[str, Any]:
        """Run shadow broker research."""
        return await self.shadow_broker.research_and_plan(query)
    
    def switch_mode(self, mode: NeuroMode):
        """Switch cognitive neuro-mode."""
        self.mode_manager.set_mode(mode)
        self.config.active_mode = mode.value
        self.config.to_file()
        self.logger.info(f"Switched to mode: {mode.value}")
    
    def compact_memory(self):
        """Compact neural memory."""
        self.memory.compact()
        self.logger.info("Memory compacted")
    
    async def shutdown(self):
        """Graceful shutdown."""
        self.task_dag.save()
        self.tool_registry.save()
        self.memory.compact()
        self.logger.info("Harness shutdown complete")
