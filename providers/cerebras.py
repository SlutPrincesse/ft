"""Cerebras provider for Agent-Wun."""
import os
import httpx
import logging
from typing import List, Dict, Any
from providers import LLMProvider, ProviderHealth

logger = logging.getLogger("agent-wun.providers.cerebras")


class CerebrasProvider(LLMProvider):
    name = "cerebras"
    DEFAULT_BASE = "https://api.cerebras.ai/v1"

    def __init__(self, api_key: str, base_url: str = ""):
        self.api_key = api_key
        self.base_url = base_url or self.DEFAULT_BASE
        self.health = ProviderHealth.HEALTHY

    async def chat(self, messages: List[Dict], model: str = "llama3.1-8b", **kwargs) -> Dict[str, Any]:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": model,
            "messages": messages,
            "stream": False,
            **kwargs,
        }
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(f"{self.base_url}/chat/completions", json=payload, headers=headers)
            resp.raise_for_status()
            data = resp.json()
            return {
                "content": data["choices"][0]["message"]["content"],
                "model": data.get("model", model),
                "provider": self.name,
            }

    async def stream(self, messages: List[Dict], model: str = "llama3.1-8b", **kwargs):
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": model,
            "messages": messages,
            "stream": True,
            **kwargs,
        }
        async with httpx.AsyncClient(timeout=60) as client:
            async with client.stream("POST", f"{self.base_url}/chat/completions", json=payload, headers=headers) as resp:
                async for line in resp.aiter_lines():
                    if line.startswith("data: "):
                        yield line[6:]
