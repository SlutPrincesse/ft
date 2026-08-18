"""Provider router for AGNOSTIC-HARVESTER."""

import logging
from typing import Any, Dict, List, Optional

from .base import BaseProvider


class ProviderRouter:
    """
    Routes LLM requests to appropriate providers.
    
    Supports multiple providers with fallback logic.
    """
    
    def __init__(self):
        self.providers: Dict[str, BaseProvider] = {}
        self.default_provider: Optional[str] = None
        self.logger = logging.getLogger("agnostic.providers.router")
    
    def register_provider(self, name: str, provider: BaseProvider, is_default: bool = False):
        """Register a provider."""
        self.providers[name] = provider
        if is_default or not self.default_provider:
            self.default_provider = name
        self.logger.info(f"Registered provider: {name}")
    
    def get_provider(self, name: Optional[str] = None) -> Optional[BaseProvider]:
        """Get provider by name or default."""
        if name is None:
            name = self.default_provider
        return self.providers.get(name)
    
    def list_providers(self) -> List[str]:
        """List all registered providers."""
        return list(self.providers.keys())
    
    async def generate(self, prompt: str, provider: Optional[str] = None, **kwargs) -> str:
        """Generate response using specified or default provider."""
        prov = self.get_provider(provider)
        if not prov:
            raise ValueError(f"Provider not found: {provider}")
        return await prov.generate(prompt, **kwargs)
    
    async def stream(self, prompt: str, provider: Optional[str] = None, **kwargs):
        """Stream response using specified or default provider."""
        prov = self.get_provider(provider)
        if not prov:
            raise ValueError(f"Provider not found: {provider}")
        async for chunk in prov.stream(prompt, **kwargs):
            yield chunk
