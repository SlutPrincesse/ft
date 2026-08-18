"""Agent-Wun LLM Provider Layer.

Embeds FreeRideV3's multi-provider failover and health-aware routing
into the unified agent framework.
"""
import os
import httpx
import logging
from typing import List, Optional, Dict, Any
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger("agent-wun.providers")


class ProviderHealth(Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    COOLDOWN = "cooldown"
    FAILED = "failed"


@dataclass
class ProviderConfig:
    name: str
    api_key: str = ""
    api_base: str = ""
    models: List[str] = field(default_factory=list)
    priority: int = 10
    timeout: int = 30
    kwargs: Dict[str, Any] = field(default_factory=dict)


class LLMProvider:
    """Base provider interface."""
    name: str = "base"
    health: ProviderHealth = ProviderHealth.HEALTHY

    async def chat(self, messages: List[Dict], model: str, **kwargs) -> Dict[str, Any]:
        raise NotImplementedError

    async def stream(self, messages: List[Dict], model: str, **kwargs):
        raise NotImplementedError


class ProviderManager:
    """Manages multiple LLM providers with failover (FreeRideV3 architecture)."""

    def __init__(self):
        self.providers: Dict[str, LLMProvider] = {}
        self.health_stats: Dict[str, Dict] = {}
        self._load_providers()

    def _load_providers(self):
        """Load providers from environment and provider modules."""
        # OpenRouter
        if os.getenv("OPENROUTER_API_KEY"):
            self._register_openrouter()
        # Groq
        if os.getenv("GROQ_API_KEY"):
            self._register_groq()
        # Cerebras
        if os.getenv("CEREBRAS_API_KEY"):
            self._register_cerebras()
        # Ollama (local, always available)
        self._register_ollama()

    def _register_openrouter(self):
        try:
            from providers.openrouter import OpenRouterProvider
            key = os.getenv("OPENROUTER_API_KEY", "")
            keys = [k.strip() for k in key.split(",") if k.strip()]
            self.providers["openrouter"] = OpenRouterProvider(keys[0] if keys else "")
        except Exception as e:
            logger.warning(f"OpenRouter provider unavailable: {e}")

    def _register_groq(self):
        try:
            from providers.groq import GroqProvider
            self.providers["groq"] = GroqProvider(os.getenv("GROQ_API_KEY", ""))
        except Exception as e:
            logger.warning(f"Groq provider unavailable: {e}")

    def _register_cerebras(self):
        try:
            from providers.cerebras import CerebrasProvider
            self.providers["cerebras"] = CerebrasProvider(os.getenv("CEREBRAS_API_KEY", ""))
        except Exception as e:
            logger.warning(f"Cerebras provider unavailable: {e}")

    def _register_ollama(self):
        try:
            from providers.ollama import OllamaProvider
            base = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
            self.providers["ollama"] = OllamaProvider("", base)
        except Exception as e:
            logger.warning(f"Ollama provider unavailable: {e}")

    async def chat(self, messages: List[Dict], model: str = "auto", **kwargs) -> Dict[str, Any]:
        """Route chat request with failover across providers."""
        # Sort providers by health/popularity
        provider_order = self._rank_providers(model)
        last_error = None
        for name in provider_order:
            prov = self.providers.get(name)
            if not prov or prov.health == ProviderHealth.COOLDOWN:
                continue
            try:
                result = await prov.chat(messages, model, **kwargs)
                self._record_success(name)
                return result
            except Exception as e:
                last_error = e
                self._record_failure(name, e)
                continue
        raise RuntimeError(f"All providers failed. Last error: {last_error}")

    def _rank_providers(self, model: str) -> List[str]:
        """Rank providers by health score."""
        scored = []
        for name, prov in self.providers.items():
            stats = self.health_stats.get(name, {"success_rate": 0.5, "latency_p50": 1000})
            score = stats.get("success_rate", 0.5) * 100 - stats.get("latency_p50", 1000) / 100
            scored.append((score, name))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [n for _, n in scored]

    def _record_success(self, name: str):
        stats = self.health_stats.setdefault(name, {"successes": 0, "failures": 0, "latencies": []})
        stats["successes"] = stats.get("successes", 0) + 1

    def _record_failure(self, name: str, error: Exception):
        stats = self.health_stats.setdefault(name, {"successes": 0, "failures": 0, "latencies": []})
        stats["failures"] = stats.get("failures", 0) + 1
        error_str = str(error).lower()
        if "rate" in error_str or "429" in error_str:
            self.providers[name].health = ProviderHealth.COOLDOWN
        elif "auth" in error_str or "401" in error_str or "403" in error_str:
            self.providers[name].health = ProviderHealth.FAILED


# Global provider manager
_manager: Optional[ProviderManager] = None


def get_provider_manager() -> ProviderManager:
    global _manager
    if _manager is None:
        _manager = ProviderManager()
    return _manager
