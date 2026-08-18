from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import logging

from backend.core import IngestionEngine

logger = logging.getLogger(__name__)
router = APIRouter()

engine = IngestionEngine()


class RepoIngestRequest(BaseModel):
    repo_urls: List[str]


class RepoStatusResponse(BaseModel):
    repo_url: str
    local_path: str
    status: str
    files_count: int
    error: Optional[str] = None


@router.post("/", response_model=List[RepoStatusResponse])
async def ingest_repos(request: RepoIngestRequest):
    results = await engine.ingest_repos(request.repo_urls)
    return [
        {
            "repo_url": r.repo_url,
            "local_path": r.local_path,
            "status": r.status,
            "files_count": r.files_count,
            "error": r.error,
        }
        for r in results
    ]


@router.get("/status", response_model=List[RepoStatusResponse])
async def get_status():
    return [
        {
            "repo_url": r.repo_url,
            "local_path": r.local_path,
            "status": r.status,
            "files_count": r.files_count,
            "error": r.error,
        }
        for r in engine.repos.values()
    ]


@router.get("/files/{repo_url:path}")
async def list_files(repo_url: str):
    files = engine.get_python_files(repo_url)
    return {"repo_url": repo_url, "files": [str(f.relative_to(engine.sandbox_dir)) for f in files]}
