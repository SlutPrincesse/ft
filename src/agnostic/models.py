"""Core data models for AGNOSTIC-HARVESTER."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional


class TaskStatus(str, Enum):
    """Task execution status."""
    PENDING = "pending"
    LOCKED = "locked"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    YIELDED = "yielded"
    CANCELLED = "cancelled"


class NeuroMode(str, Enum):
    """Cognitive neuro-modes."""
    OCD = "ocd"
    ADHD = "adhd"
    AUTISTIC = "autistic"
    BIPOLAR = "bipolar"
    SCHIZOPHRENIA = "schizophrenia"
    SHADOW_CLONES = "shadow-clones"
    NECRO = "necro"
    ORACLE = "oracle"
    DIRTYBOMB = "dirtybomb"


class Severity(str, Enum):
    """Issue severity levels."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass
class Task:
    """Atomic task unit in the Motor Cortex DAG."""
    id: str
    description: str
    status: TaskStatus = TaskStatus.PENDING
    dependencies: List[str] = field(default_factory=list)
    result: Optional[str] = None
    error: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    completed_at: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        """Serialize to dictionary."""
        return {
            "id": self.id,
            "description": self.description,
            "status": self.status.value,
            "dependencies": self.dependencies,
            "result": self.result,
            "error": self.error,
            "created_at": self.created_at,
            "completed_at": self.completed_at,
            "metadata": self.metadata,
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Task":
        """Deserialize from dictionary."""
        return cls(
            id=data["id"],
            description=data["description"],
            status=TaskStatus(data["status"]),
            dependencies=data.get("dependencies", []),
            result=data.get("result"),
            error=data.get("error"),
            created_at=data.get("created_at", datetime.utcnow().isoformat()),
            completed_at=data.get("completed_at"),
            metadata=data.get("metadata", {}),
        )


@dataclass
class ToolManifest:
    """Global tool registry entry."""
    name: str
    binary_path: str
    schema: Dict[str, Any] = field(default_factory=dict)
    source_repo: Optional[str] = None
    version: Optional[str] = None
    installed_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    last_verified: Optional[str] = None
    verified: bool = False


@dataclass
class RepoCandidate:
    """GitHub repository candidate for tool extraction."""
    url: str
    name: str
    description: str
    language: str
    stars: int
    updated_at: str
    relevance_score: float = 0.0
    selected: bool = False


@dataclass
class ToolPlan:
    """Tool creation plan from a GitHub repository."""
    repo_url: str
    functions: List[Dict[str, Any]] = field(default_factory=list)
    global_install: bool = False
    human_approved: bool = False
    status: str = "pending"  # pending, approved, rejected, installed


@dataclass
class AmbiguityResult:
    """Result of ambiguity detection."""
    term: str
    context: str
    suggestions: List[str]
    severity: Severity = Severity.MEDIUM


@dataclass
class LinguisticProfile:
    """Profile of processed linguistic input."""
    original: str
    normalized: str
    ambiguities: List[AmbiguityResult] = field(default_factory=list)
    corrections: List[Dict[str, str]] = field(default_factory=list)
    token_savings: float = 0.0


@dataclass
class ShadowDelta:
    """Shadow git state delta."""
    task_id: str
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    files_changed: List[str] = field(default_factory=list)
    diff_summary: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class AuditReport:
    """Post-queue audit report."""
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    total_tasks: int = 0
    completed: int = 0
    failed: int = 0
    yielded: int = 0
    integrity_checks: List[Dict[str, Any]] = field(default_factory=list)
    recommendations: List[Dict[str, Any]] = field(default_factory=list)
