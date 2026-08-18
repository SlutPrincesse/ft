"""Task DAG (Motor Cortex) - Directed Acyclic Graph for task management."""

import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
from collections import deque

from ..models import Task, TaskStatus


class TaskDAG:
    """
    Motor Cortex - Directed Acyclic Graph for task management.
    
    Manages task dependencies, execution order, and state tracking.
    """
    
    def __init__(self, state_dir: Path):
        self.state_dir = state_dir
        self.tasks: Dict[str, Task] = {}
        self.logger = logging.getLogger("agnostic.engine.task_dag")
        self._adjacency: Dict[str, Set[str]] = {}
        self._reverse_adjacency: Dict[str, Set[str]] = {}
    
    def add_task(self, description: str, dependencies: Optional[List[str]] = None) -> Task:
        """
        Add a new atomic task to the DAG.
        
        Args:
            description: Task description
            dependencies: List of task IDs this task depends on
            
        Returns:
            Created Task
        """
        task_id = self._generate_task_id()
        task = Task(
            id=task_id,
            description=description,
            dependencies=dependencies or [],
        )
        
        self.tasks[task_id] = task
        self._adjacency[task_id] = set()
        self._reverse_adjacency[task_id] = set()
        
        # Register dependencies
        for dep_id in (dependencies or []):
            if dep_id not in self._adjacency:
                self._adjacency[dep_id] = set()
                self._reverse_adjacency[dep_id] = set()
            self._adjacency[dep_id].add(task_id)
            self._reverse_adjacency[task_id].add(dep_id)
        
        self.logger.info(f"Added task {task_id}: {description[:80]}")
        return task
    
    def _generate_task_id(self) -> str:
        """Generate unique task ID."""
        return f"task_{len(self.tasks) + 1:04d}"
    
    def get_task(self, task_id: str) -> Optional[Task]:
        """Get task by ID."""
        return self.tasks.get(task_id)
    
    def get_next_ready_task(self) -> Optional[Task]:
        """
        Get the next task that is pending with all dependencies completed.
        
        Returns:
            Next ready task or None
        """
        for task in self.tasks.values():
            if task.status != TaskStatus.PENDING:
                continue
            
            # Check if all dependencies are completed
            deps_met = all(
                self.tasks.get(dep_id, Task(id=dep_id, description="")).status == TaskStatus.COMPLETED
                for dep_id in task.dependencies
            )
            
            if deps_met:
                return task
        
        return None
    
    def mark_completed(self, task_id: str, result: str):
        """Mark a task as completed with result."""
        if task_id in self.tasks:
            task = self.tasks[task_id]
            task.status = TaskStatus.COMPLETED
            task.result = result
            task.completed_at = datetime.utcnow().isoformat()
            self.logger.info(f"Task {task_id} completed")
    
    def mark_failed(self, task_id: str, error: str):
        """Mark a task as failed with error."""
        if task_id in self.tasks:
            task = self.tasks[task_id]
            task.status = TaskStatus.FAILED
            task.error = error
            self.logger.error(f"Task {task_id} failed: {error}")
    
    def yield_task(self, task_id: str):
        """Yield a task waiting for human input."""
        if task_id in self.tasks:
            task = self.tasks[task_id]
            task.status = TaskStatus.YIELDED
            self.logger.info(f"Task {task_id} yielded for human input")
    
    def cancel_task(self, task_id: str):
        """Cancel a task and its dependents."""
        if task_id not in self.tasks:
            return
        
        # Cancel this task
        self.tasks[task_id].status = TaskStatus.CANCELLED
        
        # Cancel all dependent tasks (BFS)
        queue = deque(self._adjacency.get(task_id, set()))
        while queue:
            dependent_id = queue.popleft()
            if dependent_id in self.tasks and self.tasks[dependent_id].status == TaskStatus.PENDING:
                self.tasks[dependent_id].status = TaskStatus.CANCELLED
                queue.extend(self._adjacency.get(dependent_id, set()))
        
        self.logger.info(f"Task {task_id} and dependents cancelled")
    
    def get_ready_tasks(self) -> List[Task]:
        """Get all tasks that are ready to execute."""
        ready = []
        for task in self.tasks.values():
            if task.status != TaskStatus.PENDING:
                continue
            
            deps_met = all(
                self.tasks.get(dep_id, Task(id=dep_id, description="")).status == TaskStatus.COMPLETED
                for dep_id in task.dependencies
            )
            
            if deps_met:
                ready.append(task)
        
        return ready
    
    def get_failed_tasks(self) -> List[Task]:
        """Get all failed tasks."""
        return [t for t in self.tasks.values() if t.status == TaskStatus.FAILED]
    
    def get_yielded_tasks(self) -> List[Task]:
        """Get all yielded tasks."""
        return [t for t in self.tasks.values() if t.status == TaskStatus.YIELDED]
    
    def get_stats(self) -> Dict[str, int]:
        """Get task statistics."""
        stats = {status: 0 for status in TaskStatus}
        for task in self.tasks.values():
            stats[task.status] += 1
        return {k.value: v for k, v in stats.items()}
    
    def clear(self):
        """Clear all tasks."""
        self.tasks.clear()
        self._adjacency.clear()
        self._reverse_adjacency.clear()
        self.logger.info("Task DAG cleared")
    
    def to_dict(self) -> Dict[str, Any]:
        """Serialize DAG to dictionary."""
        return {
            "tasks": {tid: task.to_dict() for tid, task in self.tasks.items()},
            "stats": self.get_stats(),
        }
    
    def from_dict(self, data: Dict[str, Any]):
        """Deserialize DAG from dictionary."""
        self.tasks = {
            tid: Task.from_dict(task_data)
            for tid, task_data in data.get("tasks", {}).items()
        }
        
        # Rebuild adjacency
        self._adjacency = {tid: set() for tid in self.tasks}
        self._reverse_adjacency = {tid: set() for tid in self.tasks}
        
        for task in self.tasks.values():
            for dep_id in task.dependencies:
                if dep_id in self._adjacency:
                    self._adjacency[dep_id].add(task.id)
                    self._reverse_adjacency[task.id].add(dep_id)
    
    def save(self):
        """Persist DAG state to disk."""
        dag_file = self.state_dir / "task_dag.json"
        dag_file.write_text(json.dumps(self.to_dict(), indent=2))
    
    def load(self):
        """Load DAG state from disk."""
        dag_file = self.state_dir / "task_dag.json"
        if dag_file.exists():
            data = json.loads(dag_file.read_text())
            self.from_dict(data)
            self.logger.info(f"Loaded DAG with {len(self.tasks)} tasks")
