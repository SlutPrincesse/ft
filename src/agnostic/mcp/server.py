"""MCP server implementation."""

import json
import logging
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional


class MCPServer:
    """
    Model Context Protocol server implementation.
    
    Provides standardized interface for LLM tool invocation.
    """
    
    def __init__(self):
        self.logger = logging.getLogger("agnostic.mcp.server")
        self.tools: Dict[str, Dict[str, Any]] = {}
    
    def register_tool(self, name: str, schema: Dict[str, Any], handler: Any):
        """Register a tool with the MCP server."""
        self.tools[name] = {
            "schema": schema,
            "handler": handler,
        }
        self.logger.info(f"Registered MCP tool: {name}")
    
    def list_tools(self) -> List[Dict[str, Any]]:
        """List all registered tools."""
        return [
            {
                "name": name,
                "schema": tool["schema"],
            }
            for name, tool in self.tools.items()
        ]
    
    def invoke_tool(self, name: str, arguments: Dict[str, Any]) -> Any:
        """Invoke a tool by name."""
        if name not in self.tools:
            raise ValueError(f"Unknown tool: {name}")
        
        tool = self.tools[name]
        handler = tool["handler"]
        
        try:
            result = handler(**arguments)
            return result
        except Exception as e:
            self.logger.error(f"Tool {name} failed: {e}")
            raise
    
    def to_json(self) -> str:
        """Export MCP server configuration to JSON."""
        return json.dumps({
            "tools": [
                {
                    "name": name,
                    "schema": tool["schema"],
                }
                for name, tool in self.tools.items()
            ]
        }, indent=2)
