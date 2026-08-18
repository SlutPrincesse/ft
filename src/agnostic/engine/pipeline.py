"""Execution pipeline for AGNOSTIC-HARVESTER."""

import asyncio
import json
import logging
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Callable, Awaitable

from ..models import Task, TaskStatus, LinguisticProfile
from ..engine.task_dag import TaskDAG
from ..cognitive.context import LEDv3LinguisticEngine
from ..engine.context import ContextOptimizer
from ..tools.registry import ToolRegistry
from ..tools.synthesizer import ToolSynthesizer


PipelineStep = Callable[[Dict[str, Any]], Awaitable[Dict[str, Any]]]


class ExecutionPipeline:
    """
    Execution pipeline for processing prompts through the harness.
    
    Coordinates the flow: LED v3.0 -> Context Splicer -> Context Optimizer -> LLM -> Audit
    """
    
    def __init__(
        self,
        task_dag: TaskDAG,
        led: LEDv3LinguisticEngine,
        optimizer: ContextOptimizer,
        tool_registry: ToolRegistry,
        tool_synthesizer: ToolSynthesizer,
    ):
        self.task_dag = task_dag
        self.led = led
        self.optimizer = optimizer
        self.tool_registry = tool_registry
        self.tool_synthesizer = tool_synthesizer
        self.logger = logging.getLogger("agnostic.engine.pipeline")
        self.steps: List[PipelineStep] = []
    
    def add_step(self, step: PipelineStep):
        """Add a pipeline step."""
        self.steps.append(step)
        return self
    
    async def execute(self, initial_context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute the full pipeline.
        
        Args:
            initial_context: Initial execution context
            
        Returns:
            Pipeline result
        """
        context = initial_context
        
        for idx, step in enumerate(self.steps):
            self.logger.info(f"Executing pipeline step {idx + 1}/{len(self.steps)}")
            try:
                context = await step(context)
            except Exception as e:
                self.logger.error(f"Pipeline step {idx + 1} failed: {e}")
                context["error"] = str(e)
                context["failed_step"] = idx
                break
        
        return context
    
    async def step_led(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Module 1: LED v3.0 linguistic processing."""
        raw_prompt = context.get("prompt", "")
        profile = self.led.process(raw_prompt)
        
        context["linguistic_profile"] = profile
        context["normalized_prompt"] = profile.normalized
        
        self.logger.info(
            f"LED processed: {len(profile.corrections)} corrections, "
            f"{len(profile.ambiguities)} ambiguities"
        )
        
        return context
    
    async def step_splice(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Module 2: Context splicing into atomic tasks."""
        text = context.get("normalized_prompt", "")
        
        # Split by newlines, semicolons, and bullets
        tasks = []
        for line in text.split("\n"):
            line = line.strip()
            if not line:
                continue
            for clause in line.split(";"):
                clause = clause.strip()
                if clause and not clause.startswith("#"):
                    tasks.append(clause)
        
        context["spliced_tasks"] = tasks
        self.logger.info(f"Spliced {len(tasks)} atomic tasks")
        
        return context
    
    async def step_optimize(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Module 3: Context optimization."""
        tasks = context.get("spliced_tasks", [])
        
        optimized = self.optimizer.optimize(tasks)
        context["optimized_context"] = optimized
        
        return context
    
    async def step_execute_llm(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Module 4: LLM execution loop (placeholder)."""
        tasks = context.get("optimized_context", {}).get("tasks", [])
        results = []
        
        for task_desc in tasks:
            task = self.task_dag.add_task(task_desc)
            self.task_dag.tasks[task.id].status = TaskStatus.RUNNING
            self.task_dag.save()
            
            # Placeholder: actual LLM invocation would go here
            # For now, simulate completion
            self.task_dag.mark_completed(task.id, f"Processed: {task_desc}")
            results.append({
                "task_id": task.id,
                "task": task_desc,
                "result": f"Processed: {task_desc}",
            })
        
        context["execution_results"] = results
        return context
    
    async def step_record_memory(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Module 5: Neural memory recording."""
        results = context.get("execution_results", [])
        
        # Placeholder for memory recording
        context["memory_records"] = len(results)
        
        return context
    
    async def step_audit(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Module 6: Post-queue audit."""
        from ..cognitive.memory import SevenLayerMemory
        
        memory = SevenLayerMemory(Path(".harness/memory"))
        audit = memory.audit(self.task_dag)
        
        context["audit"] = audit
        
        return context
    
    def build_default_pipeline(self) -> "ExecutionPipeline":
        """Build the default execution pipeline."""
        return (
            self
            .add_step(self.step_led)
            .add_step(self.step_splice)
            .add_step(self.step_optimize)
            .add_step(self.step_execute_llm)
            .add_step(self.step_record_memory)
            .add_step(self.step_audit)
        )
