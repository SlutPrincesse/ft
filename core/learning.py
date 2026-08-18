"""Agent-Wun Learning Loop (from Hermes Agent)."""
import logging
import json
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime

logger = logging.getLogger("agent-wun.learning")


class LearningLoop:
    """Self-improving learning loop for skills and knowledge."""

    def __init__(self, storage_path: Path = None):
        self.storage_path = storage_path or Path("tmp/learning")
        self.storage_path.mkdir(parents=True, exist_ok=True)
        self.skills: Dict[str, Dict] = {}
        self.experiences: List[Dict] = []

    def record_experience(self, task: str, outcome: str, metadata: Dict = None):
        """Record an experience for learning."""
        exp = {
            "task": task,
            "outcome": outcome,
            "timestamp": datetime.utcnow().isoformat(),
            "metadata": metadata or {},
        }
        self.experiences.append(exp)
        self._persist()

    def create_skill(self, name: str, steps: List[str], triggers: List[str] = None):
        """Create a new skill from learned experience."""
        skill = {
            "name": name,
            "steps": steps,
            "triggers": triggers or [],
            "created_at": datetime.utcnow().isoformat(),
            "usage_count": 0,
            "success_rate": 1.0,
        }
        self.skills[name] = skill
        self._persist()

    def suggest_skill(self, task: str) -> Optional[str]:
        """Suggest an existing skill for a task."""
        task_lower = task.lower()
        for name, skill in self.skills.items():
            if any(trigger in task_lower for trigger in skill.get("triggers", [])):
                return name
        return None

    def _persist(self):
        """Persist learning state."""
        try:
            with open(self.storage_path / "skills.json", "w") as f:
                json.dump(self.skills, f, indent=2)
            with open(self.storage_path / "experiences.json", "w") as f:
                json.dump(self.experiences, f, indent=2)
        except Exception as e:
            logger.error(f"Failed to persist learning state: {e}")


_learning: Optional[LearningLoop] = None


def get_learning_loop() -> LearningLoop:
    global _learning
    if _learning is None:
        _learning = LearningLoop()
    return _learning
