"""Ollama provider for Agent-Wun (local, no API key required)."""
import os
import httpx
import logging
from typing import List, Dict, Any
from providers import LLMProvider, ProviderHealth

logger = logging.getLogger("agent-wun.providers.ollama")


class OllamaProvider(LLMProvider):
    name = "ollama"
    DEFAULT_BASE = "http://localhost:11434"

    def __init__(self, api_key: str = "", base_url: str = ""):
        self.api_key = api_key
        self.base_url = base_url or os.getenv("OLLAMA_BASE_URL", self.DEFAULT_BASE)
        self.health = ProviderHealth.HEALTHY

    async def chat(self, messages: List[Dict], model: str = "llama3.1", **kwargs) -> Dict[str, Any]:
        payload = {
            "model": model,
            "messages": messages,
            "stream": False,
            **kwargs,
        }
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(f"{self.base_url}/api/chat", json=payload)
            resp.raise_for_status()
            data = resp.json()
            return {
                "content": data.get("message", {}).get("content", ""),
                "model": model,
                "provider": self.name,
            }

    async def stream(self, messages: List[Dict], model: str = "llama3.1", **kwargs):
        payload = {
            "model": model,
            "messages": messages,
            "stream": True,
            **kwargs,
        }
        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream("POST", f"{self.base_url}/api/chat", json=payload) as resp:
                async for line in resp.aiter_lines():
                    if line:
                        yield line
