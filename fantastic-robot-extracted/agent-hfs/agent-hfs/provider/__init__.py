"""Agent-Wun-Tu-Free unified LLM provider layer."""

from __future__ import annotations

import asyncio
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)

try:
    import httpx
    _HTTPX_AVAILABLE = True
except ImportError:
    _HTTPX_AVAILABLE = False


class LLMProvider:
    def __init__(self, config: dict[str, Any] | None = None):
        self.config = config or {}
        self.provider = self.config.get("provider", "ollama")
        self.base_url = self.config.get("base_url", os.getenv("LLM_BASE_URL", "http://localhost:11434"))
        self.api_key = self.config.get("api_key", os.getenv("LLM_API_KEY", ""))
        self.model = self.config.get("model", os.getenv("LLM_MODEL", "llama3"))
        self.timeout = self.config.get("timeout", 120)
        self._client = None
        if _HTTPX_AVAILABLE:
            self._client = httpx.AsyncClient(timeout=self.timeout)

    async def chat(self, messages: list[dict[str, str]], model: str | None = None, **kwargs: Any) -> str:
        model = model or self.model
        provider = kwargs.get("provider", self.provider)
        if provider == "ollama":
            return await self._ollama_chat(model, messages, **kwargs)
        if provider == "openrouter":
            return await self._openrouter_chat(model, messages, **kwargs)
        if provider == "groq":
            return await self._groq_chat(model, messages, **kwargs)
        if provider in ("openai", "openai_compatible"):
            return await self._openai_chat(model, messages, **kwargs)
        raise ValueError(f"Unsupported provider: {provider}")

    async def _ollama_chat(self, model: str, messages: list[dict], **kwargs) -> str:
        if not _HTTPX_AVAILABLE:
            return "[error] httpx required for ollama"
        try:
            resp = await self._client.post(f"{self.base_url}/api/chat", json={"model": model, "messages": messages, "stream": False})
            resp.raise_for_status()
            data = resp.json()
            return data.get("message", {}).get("content", "")
        except Exception as exc:
            logger.error("Ollama chat failed: %s", exc)
            return f"[error] Ollama request failed: {exc}"

    async def _openrouter_chat(self, model: str, messages: list[dict], **kwargs) -> str:
        if not _HTTPX_AVAILABLE:
            return "[error] httpx required for openrouter"
        base_url = "https://openrouter.ai/api/v1"
        headers = {"Authorization": f"Bearer {self.api_key}", "HTTP-Referer": "https://agent-wun.ai", "X-Title": "Agent-Wun-Tu-Free"}
        try:
            resp = await self._client.post(f"{base_url}/chat/completions", headers=headers, json={"model": model, "messages": messages})
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"]
        except Exception as exc:
            logger.error("OpenRouter chat failed: %s", exc)
            return f"[error] OpenRouter request failed: {exc}"

    async def _groq_chat(self, model: str, messages: list[dict], **kwargs) -> str:
        base_url = "https://api.groq.com/openai/v1"
        return await self._openai_chat(base_url, model, messages, **kwargs)

    async def _openai_chat(self, base_url: str, model: str, messages: list[dict], **kwargs) -> str:
        if not _HTTPX_AVAILABLE:
            return "[error] httpx required for openai"
        headers = {"Authorization": f"Bearer {self.api_key}"}
        try:
            resp = await self._client.post(f"{base_url}/chat/completions", headers=headers, json={"model": model, "messages": messages})
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"]
        except Exception as exc:
            logger.error("OpenAI chat failed: %s", exc)
            return f"[error] OpenAI request failed: {exc}"

    async def close(self) -> None:
        if self._client:
            await self._client.aclose()

    def is_available(self) -> bool:
        return True

    def list_models(self) -> list[str]:
        if self.provider == "ollama":
            return ["llama3", "mistral", "codellama", "phi3"]
        if self.provider == "openrouter":
            return ["meta-llama/llama-3.1-8b-instruct:free", "google/gemini-2.0-flash-exp:free"]
        if self.provider == "groq":
            return ["llama3-8b-8192", "mixtral-8x7b-32768"]
        return [self.model]
