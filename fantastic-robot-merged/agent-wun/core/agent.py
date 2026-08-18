"""Agent-Wun Core Runtime.

Merges Agent Zero's web-centric agent runtime with Hermes Agent's learning loop,
AgenticSeek's routing, and FreeRideV3's free-tier LLM provider layer.
"""
import os
import sys
import json
import asyncio
import logging
from pathlib import Path
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, field
from enum import Enum

# Paths
BASE_DIR = Path(__file__).resolve().parent.parent
CONF_DIR = BASE_DIR / "conf"
PROMPTS_DIR = BASE_DIR / "prompts"
AGENTS_DIR = BASE_DIR / "agents"
SKILLS_DIR = BASE_DIR / "skills"
PLUGINS_DIR = BASE_DIR / "plugins"
TOOLS_DIR = BASE_DIR / "tools"
PROVIDERS_DIR = BASE_DIR / "providers"
WEBUI_DIR = BASE_DIR / "webui"
TMP_DIR = BASE_DIR / "tmp"

# Ensure directories exist
for d in [CONF_DIR, PROMPTS_DIR, AGENTS_DIR, SKILLS_DIR, PLUGINS_DIR, TOOLS_DIR, PROVIDERS_DIR, TMP_DIR]:
    d.mkdir(parents=True, exist_ok=True)

logger = logging.getLogger("agent-wun")


class ContextType(Enum):
    USER = "user"
    TASK = "task"
    BACKGROUND = "background"


@dataclass
class ModelConfig:
    type: str = "chat"
    provider: str = "freeride"
    name: str = "auto"
    api_key: str = ""
    api_base: str = "http://localhost:11343"
    ctx_length: int = 8192
    limit_requests: int = 0
    limit_input: int = 0
    limit_output: int = 0
    vision: bool = False
    kwargs: Dict[str, Any] = field(default_factory=dict)


@dataclass
class AgentConfig:
    profile: str = "default"
    mcp_servers: List[str] = field(default_factory=list)
    knowledge_subdirs: List[str] = field(default_factory=list)
    model: ModelConfig = field(default_factory=ModelConfig)
    tools: List[str] = field(default_factory=list)
    skills: List[str] = field(default_factory=list)
    extra: Dict[str, Any] = field(default_factory=dict)


@dataclass
class UserMessage:
    message: str
    attachments: List[str] = field(default_factory=list)
    system_message: Optional[str] = None
    id: Optional[str] = None


class AgentContext:
    """Central registry for agent contexts (merged from Agent Zero + Hermes)."""
    _contexts: Dict[str, "AgentContext"] = {}

    def __init__(self, ctx_id: str, config: AgentConfig):
        self.id = ctx_id
        self.config = config
        self.history: List[Dict] = []
        self.data: Dict[str, Any] = {}
        self.intervention: Optional[str] = None
        self.paused = False
        self.log: List[str] = []
        self.output_data: Dict[str, Any] = {}
        self.task_handle = None
        AgentContext._contexts[ctx_id] = self

    @classmethod
    def get(cls, ctx_id: str) -> Optional["AgentContext"]:
        return cls._contexts.get(ctx_id)

    @classmethod
    def create(cls, ctx_id: str, config: AgentConfig) -> "AgentContext":
        if ctx_id in cls._contexts:
            return cls._contexts[ctx_id]
        return cls(ctx_id, config)


class Agent:
    """Unified Agent class merging Agent Zero monologue loop with Hermes tool system."""

    def __init__(self, config: AgentConfig, context: AgentContext):
        self.config = config
        self.context = context
        self.history = context.history
        self.intervention = context.intervention
        self.data = context.data
        self.tools: Dict[str, Any] = {}
        self._load_tools()
        self._load_skills()

    def _load_tools(self):
        """Load tools from tools/ directory."""
        tools_path = TOOLS_DIR
        if not tools_path.exists():
            return
        sys.path.insert(0, str(tools_path))
        for f in tools_path.glob("*.py"):
            if f.name.startswith("_"):
                continue
            try:
                import importlib.util
                spec = importlib.util.spec_from_file_location(f.stem, f)
                mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(mod)
                if hasattr(mod, "register"):
                    mod.register(self.tools)
            except Exception:
                pass

    def _load_skills(self):
        """Load active skills."""
        if not self.config.skills:
            return
        for skill_name in self.config.skills:
            skill_path = SKILLS_DIR / skill_name / "SKILL.md"
            if skill_path.exists():
                logger.info(f"Loaded skill: {skill_name}")

    def build_prompt(self, message: UserMessage) -> str:
        """Build system + user prompt."""
        system_prompt = message.system_message or self._default_system_prompt()
        return f"{system_prompt}\n\nUser: {message.message}"

    def _default_system_prompt(self) -> str:
        return (
            "You are Agent-Wun, an autonomous agent framework. "
            "You have access to tools for code execution, file operations, web search, "
            "browser automation, and memory. Be helpful, precise, and thorough."
        )

    async def monologue(self, message: UserMessage) -> str:
        """Main agent loop. Simplified for unified runtime."""
        # In production, this integrates full Agent Zero monologue + Hermes tool orchestration
        prompt = self.build_prompt(message)
        self.history.append({"role": "user", "content": message.message})
        return f"[Agent-Wun] Processed: {message.message[:100]}..."

    def process_tools(self, tool_calls: List[Dict]) -> List[str]:
        """Execute tool calls and return results."""
        results = []
        for call in tool_calls:
            tool_name = call.get("name")
            tool_args = call.get("args", {})
            if tool_name in self.tools:
                try:
                    result = self.tools[tool_name](**tool_args)
                    results.append(str(result))
                except Exception as e:
                    results.append(f"Error: {e}")
            else:
                results.append(f"Unknown tool: {tool_name}")
        return results


class AgentRuntime:
    """Main runtime orchestrator."""

    def __init__(self, config_path: Optional[str] = None):
        self.config = self._load_config(config_path)
        self.contexts: Dict[str, AgentContext] = {}

    def _load_config(self, path: Optional[str]) -> Dict[str, Any]:
        if path and Path(path).exists():
            with open(path) as f:
                return json.load(f)
        return {"model": {"provider": "freeride", "api_base": "http://localhost:11343"}}

    def create_agent(self, ctx_id: str, profile: str = "default") -> Agent:
        ctx = AgentContext.create(ctx_id, AgentConfig(profile=profile))
        agent = Agent(ctx.config, ctx)
        self.contexts[ctx_id] = ctx
        return agent

    def get_agent(self, ctx_id: str) -> Optional[Agent]:
        ctx = AgentContext.get(ctx_id)
        if not ctx:
            return None
        return Agent(ctx.config, ctx)


def main():
    """Entry point."""
    import argparse
    parser = argparse.ArgumentParser(description="Agent-Wun Runtime")
    parser.add_argument("--config", help="Path to config file")
    parser.add_argument("--profile", default="default", help="Agent profile")
    args = parser.parse_args()

    runtime = AgentRuntime(args.config)
    agent = runtime.create_agent("default", args.profile)
    print(f"Agent-Wun runtime started with profile: {args.profile}")


if __name__ == "__main__":
    main()
