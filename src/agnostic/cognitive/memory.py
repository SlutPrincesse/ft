"""Seven-layer memory system for AGNOSTIC-HARVESTER."""

import json
import logging
import hashlib
from pathlib import Path
from typing import Any, Dict, List, Optional
from datetime import datetime
from dataclasses import dataclass, field

from ..models import Task, TaskStatus, ShadowDelta, AuditReport
from ..engine.task_dag import TaskDAG


class SevenLayerMemory:
    """
    7-Layer Memory System (Bio-Neural Architecture).
    
    Layers:
    1. Cerebral Cortex (Long-Term Memory) - Persistent vector storage
    2. Hippocampus (Short-Term Memory) - Active context window
    3. Basal Ganglia (LLM Cache) - Semantic caching
    4. Pineal Generation (The Spark) - Self-prompting engine
    5. Motor Cortex (Task DAG) - Permanent task queue
    6. Prefrontal Cortex (Self) - Meta-awareness
    7. Wernicke's Area (Vocabulary) - Dynamic context expansion
    """
    
    def __init__(self, memory_dir: Path):
        self.memory_dir = memory_dir
        self.memory_dir.mkdir(parents=True, exist_ok=True)
        
        # Layer files
        self.cortex_file = memory_dir / "cortex.jsonl"  # Long-term memory
        self.hippocampus_file = memory_dir / "hippocampus.json"  # Short-term
        self.basal_file = memory_dir / "basal_ganglia.json"  # LLM cache
        self.pineal_file = memory_dir / "pineal.jsonl"  # Self-prompting
        self.wernicke_file = memory_dir / "wernicke.json"  # Vocabulary
        
        self.logger = logging.getLogger("agnostic.cognitive.memory")
        
        # Initialize files if missing
        for f in [self.cortex_file, self.hippocampus_file, self.basal_file, self.pineal_file, self.wernicke_file]:
            if not f.exists():
                f.write_text("[]" if f.suffix == ".json" else "")
    
    def record_execution(self, result: Dict[str, Any]):
        """Record execution result to long-term memory."""
        record = {
            "timestamp": datetime.utcnow().isoformat(),
            "type": "execution",
            "data": result,
            "hash": self._compute_hash(result),
        }
        
        with open(self.cortex_file, "a") as f:
            f.write(json.dumps(record) + "\n")
        
        self.logger.debug("Recorded execution to cerebral cortex")
    
    def get_recent_tasks(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent tasks from hippocampus."""
        try:
            data = json.loads(self.hippocampus_file.read_text())
            return data[-limit:] if data else []
        except (json.JSONDecodeError, FileNotFoundError):
            return []
    
    def record_to_hippocampus(self, task: Task):
        """Record task to short-term memory."""
        try:
            data = json.loads(self.hippocampus_file.read_text())
        except (json.JSONDecodeError, FileNotFoundError):
            data = []
        
        data.append(task.to_dict())
        
        # Keep only recent tasks
        if len(data) > 100:
            data = data[-100:]
        
        self.hippocampus_file.write_text(json.dumps(data, indent=2))
    
    def get_cortex_cache(self, key: str) -> Optional[Any]:
        """Get cached result from basal ganglia."""
        try:
            data = json.loads(self.basal_file.read_text())
            return data.get(key)
        except (json.JSONDecodeError, FileNotFoundError):
            return None
    
    def set_cortex_cache(self, key: str, value: Any):
        """Set cached result in basal ganglia."""
        try:
            data = json.loads(self.basal_file.read_text())
        except (json.JSONDecodeError, FileNotFoundError):
            data = {}
        
        data[key] = {
            "value": value,
            "timestamp": datetime.utcnow().isoformat(),
        }
        
        self.basal_file.write_text(json.dumps(data, indent=2))
    
    def record_pineal_generation(self, hypothesis: str, query: str):
        """Record self-prompting hypothesis."""
        record = {
            "timestamp": datetime.utcnow().isoformat(),
            "hypothesis": hypothesis,
            "query": query,
        }
        
        with open(self.pineal_file, "a") as f:
            f.write(json.dumps(record) + "\n")
        
        self.logger.debug(f"Recorded pineal generation: {hypothesis[:50]}")
    
    def get_wernicke_context(self, term: str) -> Optional[str]:
        """Get context expansion from Wernicke's area."""
        try:
            data = json.loads(self.wernicke_file.read_text())
            return data.get(term)
        except (json.JSONDecodeError, FileNotFoundError):
            return None
    
    def set_wernicke_context(self, term: str, context: str):
        """Set context expansion in Wernicke's area."""
        try:
            data = json.loads(self.wernicke_file.read_text())
        except (json.JSONDecodeError, FileNotFoundError):
            data = {}
        
        data[term] = context
        self.wernicke_file.write_text(json.dumps(data, indent=2))
    
    def record_shadow_delta(self, delta: ShadowDelta):
        """Record shadow git delta."""
        delta_file = self.memory_dir / "shadow_deltas.jsonl"
        with open(delta_file, "a") as f:
            f.write(json.dumps({
                "task_id": delta.task_id,
                "timestamp": delta.timestamp,
                "files_changed": delta.files_changed,
                "diff_summary": delta.diff_summary,
                "metadata": delta.metadata,
            }) + "\n")
        
        self.logger.debug(f"Recorded shadow delta for task {delta.task_id}")
    
    def get_recent_deltas(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent shadow deltas."""
        delta_file = self.memory_dir / "shadow_deltas.jsonl"
        if not delta_file.exists():
            return []
        
        try:
            with open(delta_file, "r") as f:
                lines = f.readlines()
            return [json.loads(line) for line in lines if line.strip()][-limit:]
        except (json.JSONDecodeError, IOError):
            return []
    
    def audit(self, task_dag: TaskDAG) -> AuditReport:
        """
        Run comprehensive audit on task DAG.
        
        Args:
            task_dag: Task DAG to audit
            
        Returns:
            Audit report
        """
        report = AuditReport(
            total_tasks=len(task_dag.tasks),
            completed=sum(1 for t in task_dag.tasks.values() if t.status == TaskStatus.COMPLETED),
            failed=sum(1 for t in task_dag.tasks.values() if t.status == TaskStatus.FAILED),
            yielded=sum(1 for t in task_dag.tasks.values() if t.status == TaskStatus.YIELDED),
        )
        
        # Run integrity checks
        report.integrity_checks = self._run_integrity_checks()
        
        # Generate recommendations
        report.recommendations = self._generate_recommendations(report)
        
        return report
    
    def _run_integrity_checks(self) -> List[Dict[str, Any]]:
        """Run local integrity checks."""
        checks = []
        
        # Check for syntax errors in Python files
        for py_file in Path(".").rglob("*.py"):
            if len(checks) >= 10:
                break
            try:
                with open(py_file, "r") as f:
                    compile(f.read(), py_file, "exec")
                checks.append({
                    "file": str(py_file),
                    "status": "passed",
                    "check": "syntax",
                })
            except SyntaxError as e:
                checks.append({
                    "file": str(py_file),
                    "status": "failed",
                    "check": "syntax",
                    "error": str(e),
                })
        
        return checks
    
    def _generate_recommendations(self, report: AuditReport) -> List[Dict[str, Any]]:
        """Generate follow-up recommendations."""
        recommendations = []
        
        if report.failed > 0:
            recommendations.append({
                "action": "retry_failed",
                "description": f"Retry {report.failed} failed tasks",
                "priority": "high",
            })
        
        if report.yielded > 0:
            recommendations.append({
                "action": "resolve_yielded",
                "description": f"Resolve {report.yielded} tasks waiting for human input",
                "priority": "high",
            })
        
        recommendations.extend([
            {
                "action": "add_tests",
                "description": "Add unit tests for updated modules",
                "priority": "medium",
            },
            {
                "action": "refactor_imports",
                "description": "Refactor import statements",
                "priority": "low",
            },
            {
                "action": "run_linter",
                "description": "Run linter on modified files",
                "priority": "medium",
            },
        ])
        
        return recommendations
    
    def compact(self):
        """Compact memory during idle time."""
        self.logger.info("Compacting neural memory...")
        
        # Compact cortex - keep last 1000 records
        if self.cortex_file.exists():
            lines = self.cortex_file.read_text().strip().split("\n")
            if len(lines) > 1000:
                self.cortex_file.write_text("\n".join(lines[-1000:]))
        
        # Compact hippocampus
        try:
            data = json.loads(self.hippocampus_file.read_text())
            if len(data) > 100:
                self.hippocampus_file.write_text(json.dumps(data[-100:], indent=2))
        except (json.JSONDecodeError, FileNotFoundError):
            pass
        
        self.logger.info("Memory compaction complete")
    
    def _compute_hash(self, data: Any) -> str:
        """Compute hash for data integrity."""
        return hashlib.sha256(str(data).encode()).hexdigest()[:16]
