#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - Shadow Agent Profile
Background worker for auto-loadouts, error interception, and micro-tool generation.
"""

import asyncio
import json
import os
import sys
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, field
from datetime import datetime
import logging

# Harness directories
from .harness_core import HARNESS_ROOT, TOOLS_DIR, MEMORY_DIR, STATE_DIR


@dataclass
class ShadowTask:
    """Background task for the shadow agent."""
    id: str
    type: str  # auto_loadout, error_intercept, micro_tool_gen, research
    payload: Dict[str, Any]
    status: str = "pending"
    result: Optional[Dict[str, Any]] = None
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())


class ShadowAgent:
    """
    Background worker for the shadow agent.
    
    Functions:
    - Auto-loadouts on session start
    - Error interception and micro-tool generation
    - Context-Time Training (CTT) and In-Context Reinforcement Learning (ICRL)
    - Background research and tool discovery
    """
    
    def __init__(self):
        self.logger = logging.getLogger("harness.shadow_agent")
        self.task_queue: List[ShadowTask] = []
        self.running = False
        self.learning_buffer: List[Dict[str, Any]] = []
    
    async def start(self):
        """Start the shadow agent background worker."""
        self.running = True
        self.logger.info("Shadow Agent started")
        
        # Auto-loadout on start
        await self._auto_loadout()
        
        # Main loop
        while self.running:
            await self._process_next_task()
            await asyncio.sleep(1)  # Prevent busy-waiting
    
    async def stop(self):
        """Stop the shadow agent."""
        self.running = False
        self.logger.info("Shadow Agent stopped")
    
    async def _auto_loadout(self):
        """Execute auto-loadout on session start."""
        self.logger.info("Running auto-loadout...")
        
        # Initialize .human/ directory structure
        human_dir = Path(".human")
        for subdir in ["tools", "skills", "memory", "config"]:
            (human_dir / subdir).mkdir(parents=True, exist_ok=True)
        
        # Load existing tools manifest
        manifest_path = human_dir / "tools" / "manifest.json"
        if manifest_path.exists():
            self.logger.info(f"Loaded {len(json.loads(manifest_path.read_text()).get('tools', {}))} tools from manifest")
        else:
            manifest_path.write_text(json.dumps({"tools": {}}, indent=2))
        
        self.logger.info("Auto-loadout complete")
    
    async def _process_next_task(self):
        """Process the next task in the queue."""
        if not self.task_queue:
            return
        
        task = self.task_queue.pop(0)
        self.logger.info(f"Processing shadow task: {task.type}")
        
        try:
            if task.type == "auto_loadout":
                result = await self._auto_loadout()
            elif task.type == "error_intercept":
                result = await self._intercept_error(task.payload)
            elif task.type == "micro_tool_gen":
                result = await self._generate_micro_tool(task.payload)
            elif task.type == "research":
                result = await self._background_research(task.payload)
            else:
                result = {"status": "unknown_task_type"}
            
            task.status = "completed"
            task.result = result
            
            # Record to learning buffer for ICRL
            self.learning_buffer.append({
                "task_id": task.id,
                "type": task.type,
                "result": result,
                "timestamp": datetime.utcnow().isoformat(),
            })
            
        except Exception as e:
            task.status = "failed"
            task.result = {"error": str(e)}
            self.logger.error(f"Shadow task failed: {e}")
    
    async def _intercept_error(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Intercept tool execution errors and attempt auto-recovery."""
        stderr = payload.get("stderr", "")
        task_id = payload.get("task_id", "unknown")
        
        self.logger.warning(f"Intercepting error for task {task_id}")
        
        # Match against known error patterns
        error_patterns = {
            "ModuleNotFoundError": "pip install",
            "ImportError": "pip install",
            "Command not found": "cargo install",
            "Permission denied": "chmod +x",
            "No such file or directory": "create file",
        }
        
        for pattern, action in error_patterns.items():
            if pattern in stderr:
                return {
                    "action": action,
                    "pattern": pattern,
                    "auto_fixable": True,
                }
        
        return {"action": "unknown", "auto_fixable": False}
    
    async def _generate_micro_tool(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Generate a micro-tool to handle a missing/failing tool."""
        task_id = payload.get("task_id", "unknown")
        error = payload.get("error", "")
        
        tool_path = TOOLS_DIR / f"micro_tool_{task_id}.py"
        
        content = f"""#!/usr/bin/env python3
\"\"\"
Micro-tool generated by Shadow Agent
Task: {task_id}
Error: {error[:100]}
\"\"\"

import subprocess
import sys

def main():
    print("Micro-tool placeholder - implement specific fix here")
    return 0

if __name__ == "__main__":
    sys.exit(main())
"""
        tool_path.write_text(content)
        tool_path.chmod(0o755)
        
        return {
            "tool_path": str(tool_path),
            "status": "generated",
        }
    
    async def _background_research(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Perform background research (placeholder for trend-forge integration)."""
        query = payload.get("query", "")
        self.logger.info(f"Background research: {query}")
        
        # Placeholder for trend-forge daily ingestion
        return {
            "status": "research_complete",
            "query": query,
            "results_count": 0,
        }
    
    def queue_task(self, task_type: str, payload: Dict[str, Any]) -> str:
        """Queue a new task for the shadow agent."""
        task_id = f"shadow_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"
        task = ShadowTask(
            id=task_id,
            type=task_type,
            payload=payload,
        )
        self.task_queue.append(task)
        self.logger.info(f"Queued shadow task: {task_type}")
        return task_id
    
    def get_learning_summary(self) -> Dict[str, Any]:
        """Get summary of learning from ICRL buffer."""
        return {
            "total_experiences": len(self.learning_buffer),
            "recent_experiences": self.learning_buffer[-10:],
        }


class ShadowNudge:
    """
    Native shadow-nudge: monitors I/O data flows and tool execution timing.
    Automatically interrupts and nudges LLM to pivot on hung processes.
    """
    
    def __init__(self, timeout_seconds: int = 600):
        self.timeout = timeout_seconds
        self.last_activity = datetime.utcnow()
        self.logger = logging.getLogger("harness.shadow_nudge")
    
    def update_activity(self):
        """Update last activity timestamp."""
        self.last_activity = datetime.utcnow()
    
    def check_hung(self) -> bool:
        """Check if execution has hung."""
        elapsed = (datetime.utcnow() - self.last_activity).total_seconds()
        return elapsed >= self.timeout
    
    def nudge(self) -> Dict[str, Any]:
        """Trigger a nudge to the LLM."""
        self.logger.warning("[SHADOW-NUDGE] Tool execution hung (>10m zero I/O)")
        return {
            "action": "abort",
            "reason": "hung_process",
            "elapsed_seconds": (datetime.utcnow() - self.last_activity).total_seconds(),
        }


class ShadowFS:
    """
    Shadow filesystem isolation for experimental code.
    All shadow operations run in isolated worktrees.
    """
    
    def __init__(self, base_path: Path = Path(".shadow-fs")):
        self.base_path = base_path
        self.base_path.mkdir(exist_ok=True)
        self.logger = logging.getLogger("harness.shadow_fs")
    
    def create_worktree(self, name: str, branch: str = "main") -> Optional[Path]:
        """Create an isolated shadow worktree."""
        worktree_path = self.base_path / name
        
        try:
            subprocess.run(
                ["git", "worktree", "add", str(worktree_path), branch],
                capture_output=True,
                timeout=30,
                check=True,
            )
            self.logger.info(f"Created shadow worktree: {worktree_path}")
            return worktree_path
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to create worktree: {e}")
            return None
    
    def remove_worktree(self, name: str):
        """Remove a shadow worktree."""
        worktree_path = self.base_path / name
        
        try:
            subprocess.run(
                ["git", "worktree", "remove", str(worktree_path), "--force"],
                capture_output=True,
                timeout=30,
                check=True,
            )
            self.logger.info(f"Removed shadow worktree: {worktree_path}")
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to remove worktree: {e}")
    
    def list_worktrees(self) -> List[str]:
        """List all shadow worktrees."""
        try:
            result = subprocess.run(
                ["git", "worktree", "list", "--porcelain"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            
            worktrees = []
            for line in result.stdout.split("\n"):
                if line.startswith("worktree "):
                    worktrees.append(line.split(" ", 1)[1])
            
            return worktrees
        except subprocess.CalledProcessError:
            return []
