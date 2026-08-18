#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - Core Orchestrator
Zero-cost LLM pre-processing and context optimization framework.
"""

import json
import os
import sys
from pathlib import Path
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, field, asdict
from datetime import datetime
import logging

# Harness root directory
HARNESS_ROOT = Path(".harness")
STATE_DIR = HARNESS_ROOT / "state"
MEMORY_DIR = HARNESS_ROOT / "memory"
TOOLS_DIR = HARNESS_ROOT / "tools"
STEERING_DIR = HARNESS_ROOT / "steering"
LOGS_DIR = HARNESS_ROOT / "logs"

# Ensure directories exist
for d in [STATE_DIR, MEMORY_DIR, TOOLS_DIR, STEERING_DIR, LOGS_DIR]:
    d.mkdir(parents=True, exist_ok=True)


@dataclass
class Task:
    """Atomic task unit in the Motor Cortex DAG."""
    id: str
    description: str
    status: str = "pending"  # pending, locked, running, completed, failed, yielded
    dependencies: List[str] = field(default_factory=list)
    result: Optional[str] = None
    error: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    completed_at: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ToolManifest:
    """Global tool registry entry."""
    name: str
    binary_path: str
    schema: Dict[str, Any]
    installed_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    source_repo: Optional[str] = None
    version: Optional[str] = None


class HarnessState:
    """Persistent state manager for the harness."""
    
    def __init__(self):
        self.state_file = STATE_DIR / "harness_state.json"
        self.state = self._load_state()
    
    def _load_state(self) -> Dict[str, Any]:
        if self.state_file.exists():
            return json.loads(self.state_file.read_text())
        return {
            "version": "1.0.0",
            "initialized_at": datetime.utcnow().isoformat(),
            "task_counter": 0,
            "active_mode": "ocd",
            "neuro_modes": ["ocd", "adhd", "autistic", "bipolar", "schizophrenia", "shadow-clones"],
            "tools": {},
            "shadow_git_enabled": True,
            "stealth_enabled": False,
        }
    
    def save(self):
        self.state_file.write_text(json.dumps(self.state, indent=2))
    
    def get_next_task_id(self) -> str:
        self.state["task_counter"] += 1
        self.save()
        return f"task_{self.state['task_counter']:04d}"


class TaskDAG:
    """Motor Cortex - Directed Acyclic Graph for task management."""
    
    def __init__(self, state: HarnessState):
        self.state = state
        self.tasks: Dict[str, Task] = {}
        self.logger = logging.getLogger("harness.dag")
    
    def add_task(self, description: str, dependencies: Optional[List[str]] = None) -> Task:
        """Add a new atomic task to the DAG."""
        task_id = self.state.get_next_task_id()
        task = Task(
            id=task_id,
            description=description,
            dependencies=dependencies or [],
        )
        self.tasks[task_id] = task
        self.logger.info(f"Added task {task_id}: {description[:80]}")
        return task
    
    def get_next_ready_task(self) -> Optional[Task]:
        """Get the next task that is pending with all dependencies completed."""
        for task in self.tasks.values():
            if task.status != "pending":
                continue
            if task.status == "yielded":
                continue
            deps_met = all(
                self.tasks.get(dep_id, Task(id=dep_id, description="")).status == "completed"
                for dep_id in task.dependencies
            )
            if deps_met:
                return task
        return None
    
    def mark_completed(self, task_id: str, result: str):
        """Mark a task as completed with result."""
        if task_id in self.tasks:
            task = self.tasks[task_id]
            task.status = "completed"
            task.result = result
            task.completed_at = datetime.utcnow().isoformat()
            self.logger.info(f"Task {task_id} completed")
    
    def mark_failed(self, task_id: str, error: str):
        """Mark a task as failed with error."""
        if task_id in self.tasks:
            task = self.tasks[task_id]
            task.status = "failed"
            task.error = error
            self.logger.error(f"Task {task_id} failed: {error}")
    
    def yield_task(self, task_id: str):
        """Yield a task waiting for human input."""
        if task_id in self.tasks:
            task = self.tasks[task_id]
            task.status = "yielded"
            self.logger.info(f"Task {task_id} yielded for human input")
    
    def to_dict(self) -> Dict[str, Any]:
        """Serialize DAG to dictionary."""
        return {
            "tasks": {
                tid: {
                    "id": t.id,
                    "description": t.description,
                    "status": t.status,
                    "dependencies": t.dependencies,
                    "result": t.result,
                    "error": t.error,
                    "created_at": t.created_at,
                    "completed_at": t.completed_at,
                    "metadata": t.metadata,
                }
                for tid, t in self.tasks.items()
            }
        }
    
    def save(self):
        """Persist DAG state to disk."""
        dag_file = STATE_DIR / "task_dag.json"
        dag_file.write_text(json.dumps(self.to_dict(), indent=2))


class ToolRegistry:
    """Global registry for dynamically installed Rust tools and MCP servers."""
    
    def __init__(self, state: HarnessState):
        self.state = state
        self.manifest_file = STATE_DIR / "tool_manifest.json"
        self.tools: Dict[str, ToolManifest] = {}
        self._load_manifest()
    
    def _load_manifest(self):
        if self.manifest_file.exists():
            data = json.loads(self.manifest_file.read_text())
            for name, entry in data.get("tools", {}).items():
                self.tools[name] = ToolManifest(
                    name=name,
                    binary_path=entry["binary_path"],
                    schema=entry.get("schema", {}),
                    source_repo=entry.get("source_repo"),
                    version=entry.get("version"),
                    installed_at=entry.get("installed_at", datetime.utcnow().isoformat()),
                )
    
    def register_tool(self, manifest: ToolManifest):
        """Register a new tool in the global manifest."""
        self.tools[manifest.name] = manifest
        self.state.state["tools"][manifest.name] = {
            "binary_path": manifest.binary_path,
            "schema": manifest.schema,
            "source_repo": manifest.source_repo,
            "version": manifest.version,
            "installed_at": manifest.installed_at,
        }
        self.state.save()
        self._save_manifest()
        logging.getLogger("harness.tools").info(f"Registered tool: {manifest.name}")
    
    def _save_manifest(self):
        data = {
            "tools": {
                name: {
                    "binary_path": t.binary_path,
                    "schema": t.schema,
                    "source_repo": t.source_repo,
                    "version": t.version,
                    "installed_at": t.installed_at,
                }
                for name, t in self.tools.items()
            }
        }
        self.manifest_file.write_text(json.dumps(data, indent=2))
    
    def list_tools(self) -> List[Dict[str, Any]]:
        """List all registered tools."""
        return [
            {
                "name": name,
                "binary_path": t.binary_path,
                "source_repo": t.source_repo,
                "version": t.version,
            }
            for name, t in self.tools.items()
        ]


class ShadowGitEngine:
    """Shadow state tracking via parallel git delta graph."""
    
    def __init__(self, state: HarnessState):
        self.state = state
        self.logger = logging.getLogger("harness.shadow_git")
    
    def record_delta(self, task_id: str, files_changed: List[str], diff_summary: str):
        """Record a code state delta for a completed task."""
        delta = {
            "task_id": task_id,
            "timestamp": datetime.utcnow().isoformat(),
            "files_changed": files_changed,
            "diff_summary": diff_summary,
        }
        delta_file = STATE_DIR / "shadow_deltas.jsonl"
        with open(delta_file, "a") as f:
            f.write(json.dumps(delta) + "\n")
        self.logger.debug(f"Recorded shadow delta for task {task_id}")
    
    def get_recent_deltas(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent shadow git deltas."""
        delta_file = STATE_DIR / "shadow_deltas.jsonl"
        if not delta_file.exists():
            return []
        with open(delta_file, "r") as f:
            lines = f.readlines()
        deltas = [json.loads(line) for line in lines if line.strip()]
        return deltas[-limit:]
    
    def compact(self):
        """Compress shadow git history during idle time."""
        self.logger.info("Compacting shadow git history...")
        deltas = self.get_recent_deltas(limit=1000)
        # Keep last 1000 deltas, discard older ones
        if len(deltas) > 1000:
            delta_file = STATE_DIR / "shadow_deltas.jsonl"
            with open(delta_file, "w") as f:
                for delta in deltas[-1000:]:
                    f.write(json.dumps(delta) + "\n")
            self.logger.info(f"Compacted shadow git to {len(deltas[-1000:])} entries")


class HarnessOrchestrator:
    """Main orchestrator for the AGNOSTIC-HARVESTER harness."""
    
    def __init__(self):
        self.state = HarnessState()
        self.dag = TaskDAG(self.state)
        self.tools = ToolRegistry(self.state)
        self.shadow_git = ShadowGitEngine(self.state)
        self._setup_logging()
    
    def _setup_logging(self):
        """Configure logging for the harness."""
        log_file = LOGS_DIR / "harness.log"
        logging.basicConfig(
            level=logging.INFO,
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout),
            ],
        )
        self.logger = logging.getLogger("harness")
        self.logger.info("AGNOSTIC-HARVESTER Harness initialized")
    
    def initialize(self):
        """Initialize harness directories and state."""
        self.logger.info("Initializing harness directories...")
        # Create required files if missing
        dataset_file = MEMORY_DIR / "dataset.jsonl"
        if not dataset_file.exists():
            dataset_file.write_text("")
        
        synthesized_tools_dir = TOOLS_DIR / "synthesized"
        synthesized_tools_dir.mkdir(exist_ok=True)
        
        self.logger.info("Harness initialization complete")
        return self
    
    def get_status(self) -> Dict[str, Any]:
        """Get current harness status."""
        return {
            "state": self.state.state,
            "dag": self.dag.to_dict(),
            "tools": self.tools.list_tools(),
            "shadow_deltas_count": len(self.shadow_git.get_recent_deltas()),
        }
    
    def run_pipeline(self, prompt: str, model: str = "local") -> Dict[str, Any]:
        """Run the full harness pipeline on a prompt."""
        self.logger.info(f"Running pipeline with prompt: {prompt[:100]}...")
        
        # Module 1: LED v3.0 Linguistic Engine
        standardized = self._led_v3_process(prompt)
        
        # Module 2: Context Splicer
        tasks = self._context_splice(standardized)
        
        # Module 3: Context Optimizer
        optimized_context = self._context_optimize(tasks)
        
        # Module 4: Execute via LLM
        results = self._execute_llm_loop(optimized_context, model)
        
        # Module 5: Neural Memory & Shadow Git
        self._record_memory(results)
        
        # Module 6: Post-Queue Audit
        audit_report = self._post_queue_audit()
        
        return {
            "status": "complete",
            "tasks_processed": len(results),
            "audit": audit_report,
        }
    
    def _led_v3_process(self, prompt: str) -> str:
        """Module 1: Zero-cost linguistic pre-processing."""
        # Placeholder for SymSpell, regex normalization, ambiguity detection
        # Zero LLM tokens consumed
        return prompt.strip()
    
    def _context_splice(self, prompt: str) -> List[str]:
        """Module 2: Grammar-based text splicing into atomic tasks."""
        # Simple heuristic splitting by newlines and semicolons
        tasks = []
        for line in prompt.split("\n"):
            line = line.strip()
            if not line:
                continue
            # Split by semicolons
            for clause in line.split(";"):
                clause = clause.strip()
                if clause:
                    tasks.append(clause)
        return tasks
    
    def _context_optimize(self, tasks: List[str]) -> Dict[str, Any]:
        """Module 3: AST-driven context weaving and pruning."""
        # Placeholder for AST analysis and context optimization
        return {"tasks": tasks, "pruned_files": [], "context_headroom": 0.85}
    
    def _execute_llm_loop(self, context: Dict[str, Any], model: str) -> List[Dict[str, Any]]:
        """Module 4: LLM execution loop with reactive error handling."""
        results = []
        for task in context.get("tasks", []):
            task_id = self.dag.add_task(task)
            self.dag.tasks[task_id].status = "running"
            
            # Placeholder: actual LLM invocation would go here
            # For now, simulate completion
            self.dag.mark_completed(task_id, f"Executed: {task}")
            results.append({"task_id": task_id, "result": f"Executed: {task}"})
        
        return results
    
    def _record_memory(self, results: List[Dict[str, Any]]):
        """Module 5: Neural memory and shadow git recording."""
        dataset_file = MEMORY_DIR / "dataset.jsonl"
        with open(dataset_file, "a") as f:
            for result in results:
                f.write(json.dumps(result) + "\n")
        
        # Record shadow git delta
        self.shadow_git.record_delta(
            task_id=results[-1]["task_id"] if results else "unknown",
            files_changed=[],
            diff_summary="Pipeline execution",
        )
    
    def _post_queue_audit(self) -> Dict[str, Any]:
        """Module 6: Post-queue audit and recommendations."""
        audit = {
            "timestamp": datetime.utcnow().isoformat(),
            "total_tasks": len(self.dag.tasks),
            "completed": sum(1 for t in self.dag.tasks.values() if t.status == "completed"),
            "failed": sum(1 for t in self.dag.tasks.values() if t.status == "failed"),
            "recommendations": [
                "Add unit tests for updated modules",
                "Refactor import statements",
                "Run linter on modified files",
            ],
        }
        return audit


def main():
    """Main entry point for the harness."""
    orchestrator = HarnessOrchestrator()
    orchestrator.initialize()
    
    if len(sys.argv) > 1:
        prompt = " ".join(sys.argv[1:])
    else:
        prompt = "Initialize harness and perform system check."
    
    result = orchestrator.run_pipeline(prompt)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
