import asyncio
import os
import subprocess
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, field
import aiofiles
import logging

logger = logging.getLogger(__name__)


@dataclass
class RepoStatus:
    repo_url: str
    local_path: str
    status: str = "pending"
    files_count: int = 0
    error: Optional[str] = None


class IngestionEngine:
    def __init__(self, sandbox_dir: str = "/tmp/pyshard_sandbox"):
        self.sandbox_dir = Path(sandbox_dir)
        self.sandbox_dir.mkdir(parents=True, exist_ok=True)
        self.repos: Dict[str, RepoStatus] = {}

    async def clone_repo(self, repo_url: str, repo_name: Optional[str] = None) -> RepoStatus:
        if repo_name is None:
            repo_name = repo_url.rstrip("/").split("/")[-1].replace(".git", "")
        
        local_path = self.sandbox_dir / repo_name
        status = RepoStatus(repo_url=repo_url, local_path=str(local_path))
        self.repos[repo_url] = status

        try:
            if local_path.exists():
                await asyncio.to_thread(
                    subprocess.run,
                    ["git", "-C", str(local_path), "pull", "--ff-only"],
                    capture_output=True,
                    check=True,
                )
                status.status = "updated"
            else:
                proc = await asyncio.create_subprocess_exec(
                    "git", "clone", "--depth=1", repo_url, str(local_path),
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                stdout, stderr = await proc.communicate()
                if proc.returncode != 0:
                    raise subprocess.CalledProcessError(proc.returncode, "git", stderr.decode())
                status.status = "cloned"

            py_files = list(local_path.rglob("*.py"))
            status.files_count = len(py_files)
            status.status = "ready"
            logger.info(f"Ingested {repo_url}: {len(py_files)} Python files")
        except Exception as e:
            status.status = "error"
            status.error = str(e)
            logger.error(f"Failed to ingest {repo_url}: {e}")

        return status

    async def ingest_repos(self, repo_urls: List[str]) -> List[RepoStatus]:
        tasks = [self.clone_repo(url) for url in repo_urls]
        return list(await asyncio.gather(*tasks))

    def get_python_files(self, repo_url: str) -> List[Path]:
        status = self.repos.get(repo_url)
        if not status or status.status not in ("cloned", "updated", "ready"):
            return []
        base = Path(status.local_path)
        return [
            p for p in base.rglob("*.py")
            if "__pycache__" not in str(p) and ".venv" not in str(p) and "venv" not in str(p)
        ]
