"""Git utilities."""

import subprocess
from pathlib import Path
from typing import List, Optional


class GitUtils:
    """Git utility functions."""
    
    def __init__(self, repo_path: Path = Path(".")):
        self.repo_path = repo_path
    
    def is_git_repo(self) -> bool:
        """Check if directory is a git repository."""
        return (self.repo_path / ".git").exists()
    
    def get_status(self) -> str:
        """Get git status."""
        try:
            result = subprocess.run(
                ["git", "status", "--short"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            return result.stdout
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return ""
    
    def get_log(self, limit: int = 10) -> List[str]:
        """Get recent git log."""
        try:
            result = subprocess.run(
                ["git", "log", "--oneline", f"-{limit}"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                return result.stdout.strip().split("\n")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        return []
    
    def get_diff(self, file_path: Optional[Path] = None) -> str:
        """Get git diff."""
        try:
            cmd = ["git", "diff"]
            if file_path:
                cmd.append(str(file_path))
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10,
            )
            return result.stdout
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return ""
    
    def create_worktree(self, path: Path, branch: str = "main") -> bool:
        """Create a git worktree."""
        try:
            subprocess.run(
                ["git", "worktree", "add", str(path), branch],
                capture_output=True,
                timeout=30,
                check=True,
            )
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def list_worktrees(self) -> List[str]:
        """List git worktrees."""
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
        except (subprocess.CalledProcessError, FileNotFoundError):
            return []
