"""Agent Router - Intelligent task routing (from AgenticSeek)."""
import logging
from typing import Optional, Dict, List
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger("agent-wun.router")


class AgentRole(Enum):
    CASUAL = "casual"
    CODER = "coder"
    FILE = "file"
    BROWSER = "browser"
    PLANNER = "planner"


@dataclass
class RouterResult:
    role: AgentRole
    confidence: float
    complexity: str
    reasoning: str


class AgentRouter:
    """Routes queries to the best specialized agent."""

    def __init__(self):
        self.keywords = {
            AgentRole.CASUAL: ["hello", "hi", "chat", "talk", "conversation", "how are you"],
            AgentRole.CODER: ["code", "python", "function", "debug", "program", "script", "implement"],
            AgentRole.FILE: ["file", "folder", "directory", "search", "find", "organize", "rename"],
            AgentRole.BROWSER: ["search", "web", "browse", "website", "url", "scrape", "google"],
            AgentRole.PLANNER: ["plan", "steps", "complex", "orchestrate", "workflow", "decompose", "multi"],
        }

    def route(self, message: str) -> RouterResult:
        """Classify message and return best agent role."""
        msg_lower = message.lower()
        scores = {}
        for role, keywords in self.keywords.items():
            score = sum(1 for kw in keywords if kw in msg_lower)
            scores[role] = score

        best_role = max(scores, key=scores.get)
        confidence = min(scores[best_role] / 3.0, 1.0)
        complexity = "high" if any(w in msg_lower for w in ["complex", "steps", "plan", "orchestrate"]) else "low"

        return RouterResult(
            role=best_role if scores[best_role] > 0 else AgentRole.CASUAL,
            confidence=confidence,
            complexity=complexity,
            reasoning=f"Matched {scores[best_role]} keywords for {best_role.value}",
        )
