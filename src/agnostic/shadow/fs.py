"""ShadowFS - isolated filesystem for experimental code."""

import logging
import subprocess
import shutil
from pathlib import Path
from typing import List, Optional

from ..config import HarnessConfig


class ShadowFS:
    """
    Shadow filesystem isolation for experimental code.
    
    All shadow operations run in isolated git worktrees.
    """
    
    def __init__(self, config: HarnessConfig):
        self.config = config
        self.base_path = config.shadow_fs_dir
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.logger = logging.getLogger("agnostic.shadow.fs")
    
    def create_worktree(self, name: str, branch: str = "main") -> Optional[Path]:
        """Create an isolated shadow worktree."""
        worktree_path = self.base_path / name
        
        try:
            subprocess.run(
                ["git", "worktree", "add", str(worktree_path), branch],
                capture_output=True,
                timeout=30,
                check=True,
            )
            self.logger.info(f"Created shadow worktree: {worktree_path}")
            return worktree_path
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to create worktree: {e}")
            return None
    
    def remove_worktree(self, name: str):
        """Remove a shadow worktree."""
        worktree_path = self.base_path / name
        
        try:
            subprocess.run(
                ["git", "worktree", "remove", str(worktree_path), "--force"],
                capture_output=True,
                timeout=30,
                check=True,
            )
            self.logger.info(f"Removed shadow worktree: {worktree_path}")
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to remove worktree: {e}")
    
    def list_worktrees(self) -> List[str]:
        """List all shadow worktrees."""
        try:
            result = subprocess.run(
                ["git", "worktree", "list", "--porcelain"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            
            worktrees = []
            for line in result.stdout.split("\n"):
                if line.startswith("worktree "):
                    worktrees.append(line.split(" ", 1)[1])
            
            return worktrees
        except subprocess.CalledProcessError:
            return []
    
    def get_worktree_path(self, name: str) -> Optional[Path]:
        """Get path to a shadow worktree."""
        worktrees = self.list_worktrees()
        for wt in worktrees:
            if name in wt:
                return Path(wt)
        return None
    
    def cleanup(self):
        """Clean up all shadow worktrees."""
        for name in self.list_worktrees():
            self.remove_worktree(name)
