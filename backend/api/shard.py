import json
import logging

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional

from backend.core import PythonParser, SRPSharder, ShardFilestore, SemanticSearchEngine
from backend.core.ingestion import IngestionEngine

logger = logging.getLogger(__name__)
router = APIRouter()

parser = PythonParser()
sharder = SRPSharder()
filestore = ShardFilestore()
ingestion = IngestionEngine()
search_engine = SemanticSearchEngine()


class ShardResponse(BaseModel):
    shard_id: str
    category: str
    shard_type: str
    source_repo: str
    source_file: str
    name: str
    description: str
    cyclomatic_complexity: int
    import_dependencies: List[str]
    tags: List[str]


@router.post("/parse/{repo_url:path}")
async def parse_repo(repo_url: str):
    files = ingestion.get_python_files(repo_url)
    total_shards = []
    for file_path in files:
        parsed = parser.parse_file(file_path)
        shards = sharder.shard_file(parsed, source_repo=repo_url)
        for item in shards:
            shard_obj = item["shard"]
            category = item["category"]
            shard_type = item["shard_type"]
            description = (shard_obj.docstring or "")[:200] or f"{shard_type}: {shard_obj.name}"
            metadata = ShardMetadata(
                shard_id=shard_obj.shard_id,
                category=category,
                shard_type=shard_type,
                source_repo=repo_url,
                source_file=shard_obj.source_file,
                name=shard_obj.name,
                description=description,
                cyclomatic_complexity=getattr(shard_obj, "complexity", 0),
                import_dependencies=getattr(shard_obj, "imports", []),
                tags=[category],
                created_at="2026-08-18T18:00:00Z",
            )
            filestore.store_shard(shard_obj, metadata)
            search_text = f"{shard_obj.name} {description} {' '.join(getattr(shard_obj, 'imports', []))}"
            search_engine.index_shard(shard_obj.shard_id, search_text, {
                "name": shard_obj.name,
                "category": category,
                "shard_type": shard_type,
            })
            total_shards.append({
                "shard_id": metadata.shard_id,
                "category": category,
                "shard_type": shard_type,
                "name": shard_obj.name,
                "source_file": shard_obj.source_file,
            })
    return {"repo_url": repo_url, "shards_count": len(total_shards), "shards": total_shards}


@router.get("/", response_model=List[ShardResponse])
async def list_shards(
    category: Optional[str] = None,
    shard_type: Optional[str] = None,
    name_contains: Optional[str] = None,
):
    records = filestore.search_shards(category=category, shard_type=shard_type, name_contains=name_contains)
    return [
        ShardResponse(
            shard_id=r["shard_id"],
            category=r["category"],
            shard_type=r["shard_type"],
            source_repo=r["source_repo"],
            source_file=r["source_file"],
            name=r["name"],
            description=r["description"],
            cyclomatic_complexity=r["cyclomatic_complexity"],
            import_dependencies=json.loads(r["import_dependencies"] or "[]"),
            tags=json.loads(r["tags"] or "[]"),
        )
        for r in records
    ]


@router.get("/categories")
async def list_categories():
    return {"categories": filestore.list_categories()}


@router.get("/{shard_id}")
async def get_shard(shard_id: str):
    record = filestore.get_shard(shard_id)
    if not record:
        raise HTTPException(status_code=404, detail="Shard not found")
    return record


@router.post("/semantic-search")
async def semantic_search(query: str, top_k: int = 5):
    results = search_engine.search(query, top_k=top_k)
    return {"query": query, "results": results}
