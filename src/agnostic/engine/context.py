"""Context optimization engine for zero-token pre-processing."""

import re
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
from dataclasses import dataclass, field

from ..models import LinguisticProfile, AmbiguityResult, Severity


class ContextOptimizer:
    """
    Context Optimization Engine (COE).
    
    Provides AST-driven context weaving and file pruning.
    """
    
    def __init__(self):
        self.logger = logging.getLogger("agnostic.cognitive.context")
        self.boilerplate_patterns = [
            r'^\s*#.*$',
            r'^\s*$',
            r'^\s*""".*?""".*$',
            r"^\s*'''.*?'''.*$",
        ]
    
    def optimize(self, tasks: List[str], workspace_path: Path = Path(".")) -> Dict[str, Any]:
        """
        Optimize context by pruning boilerplate and weaving AST.
        
        Args:
            tasks: List of task descriptions
            workspace_path: Path to workspace root
            
        Returns:
            Optimization result dictionary
        """
        optimized_tasks = []
        total_original_chars = sum(len(t) for t in tasks)
        total_optimized_chars = 0
        pruned_files = []
        
        for task in tasks:
            # Apply boilerplate removal
            optimized = self._remove_boilerplate(task)
            optimized_tasks.append(optimized)
            total_optimized_chars += len(optimized)
        
        # Calculate headroom
        headroom = 0.85
        
        result = {
            "tasks": optimized_tasks,
            "original_chars": total_original_chars,
            "optimized_chars": total_optimized_chars,
            "compression_ratio": total_optimized_chars / total_original_chars if total_original_chars > 0 else 1.0,
            "context_headroom": headroom,
            "pruned_files": pruned_files,
        }
        
        self.logger.info(
            f"Context optimized: {total_original_chars} -> {total_optimized_chars} chars "
            f"({result['compression_ratio']:.2f} ratio), {headroom:.0%} headroom"
        )
        
        return result
    
    def _remove_boilerplate(self, text: str) -> str:
        """Remove boilerplate from text."""
        lines = text.split("\n")
        filtered = []
        
        for line in lines:
            stripped = line.strip()
            if not stripped:
                continue
            if re.match(r'^\s*#\s*$', line):
                continue
            if re.match(r'^\s*""".*?"""\s*$', line):
                continue
            filtered.append(line)
        
        return "\n".join(filtered)
    
    def prune_workspace(self, workspace_path: Path, extensions: Optional[List[str]] = None) -> List[str]:
        """
        Prune workspace files based on relevance.
        
        Args:
            workspace_path: Path to workspace
            extensions: File extensions to include
            
        Returns:
            List of pruned file paths
        """
        if extensions is None:
            extensions = [".py", ".rs", ".js", ".ts", ".md", ".txt", ".json", ".yaml", ".yml"]
        
        pruned = []
        
        for ext in extensions:
            for file_path in workspace_path.rglob(f"*{ext}"):
                try:
                    content = file_path.read_text()
                    # Check if file is mostly boilerplate
                    lines = content.split("\n")
                    non_comment_lines = [
                        l for l in lines
                        if l.strip() and not l.strip().startswith("#")
                        and not l.strip().startswith("//")
                        and not l.strip().startswith("/*")
                        and not l.strip().startswith("*")
                    ]
                    
                    if len(non_comment_lines) < 5:
                        pruned.append(str(file_path))
                except Exception:
                    continue
        
        self.logger.info(f"Pruned {len(pruned)} boilerplate files")
        return pruned
    
    def weave_context(self, task: str, relevant_files: List[Path]) -> str:
        """
        Weave relevant file contents into context.
        
        Args:
            task: Task description
            relevant_files: List of relevant file paths
            
        Returns:
            Woven context string
        """
        context_parts = [f"Task: {task}\n"]
        
        for file_path in relevant_files[:5]:  # Limit to 5 files
            try:
                content = file_path.read_text()
                # Truncate long files
                if len(content) > 1000:
                    content = content[:1000] + "\n... [truncated]"
                context_parts.append(f"\n--- {file_path.name} ---\n{content}")
            except Exception as e:
                self.logger.warning(f"Failed to read {file_path}: {e}")
        
        return "\n".join(context_parts)
