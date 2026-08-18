"""Agent-Wun-Tu-Free agent runtime.

Provides the core Agent, AgentContext, and related classes needed by
helpers, tools, and plugins. Designed to work without the full Agent Zero
runtime while maintaining compatibility with the helper modules.
"""

from __future__ import annotations

import contextvars
import dataclasses
import logging
import threading
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional


logger = logging.getLogger(__name__)


class AgentContextType(str, Enum):
    USER = "user"
    BACKGROUND = "background"
    SYSTEM = "system"


@dataclass
class AgentConfig:
    id: str = ""
    name: str = ""
    profile: str = "default"
    model: str = ""
    temperature: float = 0.7
    max_tokens: int = 2048
    extra: dict[str, Any] = dataclasses.field(default_factory=dict)


class LogItem:
    """A single log entry."""

    def __init__(
        self,
        log: "Log",
        type: str = "info",
        heading: str = "",
        content: str = "",
        kvps: dict[str, Any] | None = None,
        id: str | None = None,
        **kwargs: Any,
    ):
        self.log = log
        self.type = type
        self.heading = heading
        self.content = content
        self.kvps = kvps or {}
        self.id = id or str(uuid.uuid4())
        self.created_at = time.time()
        self.extra = kwargs

    def update(self, **kwargs: Any) -> None:
        for key, value in kwargs.items():
            if hasattr(self, key):
                setattr(self, key, value)
        if self.log:
            self.log._items.append(self)


class Log:
    """Agent context log providing append-only event storage."""

    def __init__(self, context: Optional["AgentContext"] = None):
        self.context = context
        self.guid: str = str(uuid.uuid4())
        self.progress: str = ""
        self.progress_no: int = 0
        self.progress_active: bool = False
        self._items: list[LogItem] = []
        self._lock = threading.RLock()

    def log(
        self,
        type: str = "info",
        heading: str = "",
        content: str = "",
        kvps: dict[str, Any] | None = None,
        id: str | None = None,
        **kwargs: Any,
    ) -> LogItem:
        with self._lock:
            item = LogItem(
                log=self,
                type=type,
                heading=heading,
                content=content,
                kvps=kvps,
                id=id,
                **kwargs,
            )
            self._items.append(item)
            if item.heading:
                self.progress = item.heading
                self.progress_active = True
            return item

    def output(self, start: int = 0, end: int | None = None) -> list[dict[str, Any]]:
        items = self._items[start:end]
        return [
            {
                "type": item.type,
                "heading": item.heading,
                "content": item.content,
                "kvps": item.kvps,
                "id": item.id,
                "created_at": item.created_at,
            }
            for item in items
        ]

    def updates(self, start: int = 0, end: int | None = None) -> list[dict[str, Any]]:
        return self.output(start=start, end=end)

    def clear(self) -> None:
        with self._lock:
            self._items.clear()
            self.progress = ""
            self.progress_active = False


class AgentContext:
    """Agent execution context."""

    _registry: dict[str, AgentContext] = {}
    _current: contextvars.ContextVar[AgentContext | None] = contextvars.ContextVar(
        "agent_context", default=None
    )
    _lock = threading.RLock()

    def __init__(
        self,
        cfg: AgentConfig,
        type: AgentContextType = AgentContextType.USER,
        id: str | None = None,
    ):
        self.cfg = cfg
        self.type = type
        self.id = id or str(uuid.uuid4())
        self.name = cfg.name or self.id
        self.data: dict[str, Any] = {}
        self.output_data: dict[str, Any] = {}
        self.log = Log(context=self)
        self.paused: bool = False
        self.created_at = time.time()

        with AgentContext._lock:
            AgentContext._registry[self.id] = self

    @classmethod
    def get(cls, context_id: str) -> AgentContext | None:
        with cls._lock:
            return cls._registry.get(context_id)

    @classmethod
    def current(cls) -> AgentContext | None:
        return cls._current.get()

    @classmethod
    def set_current(cls, context_id: str) -> None:
        ctx = cls.get(context_id)
        if ctx:
            cls._current.set(ctx)

    @classmethod
    def remove(cls, context_id: str) -> None:
        with cls._lock:
            cls._registry.pop(context_id, None)

    @classmethod
    def all(cls) -> list[AgentContext]:
        with cls._lock:
            return list(cls._registry.values())


@dataclass
class UserMessage:
    content: str = ""
    role: str = "user"
    extra: dict[str, Any] = dataclasses.field(default_factory=dict)


class LoopData:
    def __init__(self, **kwargs: Any):
        self.params_temporary = kwargs.get("params_temporary", {})


class Agent:
    """Base Agent class providing runtime for Agent-Wun-Tu-Free."""

    def __init__(self, **kwargs: Any):
        self.agent_name = kwargs.get("agent_name", "agent0")
        self.config = kwargs.get("config") or AgentConfig()
        self.context = kwargs.get("context") or AgentContext(self.config)
        self._data: dict[str, Any] = {}
        self._tools: dict[str, Any] = {}

    def set_data(self, key: str, value: Any) -> None:
        self._data[key] = value

    def get_data(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, default)

    def read_prompt(self, name: str, **kwargs: Any) -> str:
        try:
            from helpers import files
            return files.read_prompt_file(name, **kwargs)
        except Exception:
            return f"[prompt:{name}]"

    def hist_add_tool_result(self, tool_name: str, result: str, **kwargs: Any) -> None:
        self.context.log.log(
            type="tool",
            heading=f"Tool {tool_name} result",
            content=result,
            kvps=kwargs,
        )

    def hist_add_message(self, role: str, content: str, **kwargs: Any) -> None:
        self.context.log.log(
            type="message",
            heading=f"{role} message",
            content=content,
            kvps=kwargs,
        )

    def register_tool(self, name: str, tool: Any) -> None:
        self._tools[name] = tool

    def get_tool(self, name: str) -> Any | None:
        return self._tools.get(name)

    def list_tools(self) -> list[str]:
        return list(self._tools.keys())
