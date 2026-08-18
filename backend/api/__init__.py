from fastapi import APIRouter
from .ingest import router as ingest_router
from .shard import router as shard_router
from .synthesize import router as synthesize_router

api_router = APIRouter()
api_router.include_router(ingest_router, prefix="/ingest", tags=["ingestion"])
api_router.include_router(shard_router, prefix="/shards", tags=["shards"])
api_router.include_router(synthesize_router, prefix="/synthesize", tags=["synthesis"])
