# PyShard-P9

Python-centric reverse-engineering, SRP sharding, and synthesis engine.

## Architecture

```
pyshard-p9/
├── backend/
│   ├── main.py                 # FastAPI entry point
│   ├── requirements.txt
│   └── core/
│       ├── __init__.py
│       ├── ingestion.py        # Async Git worker pool
│       ├── parser.py           # AST/CST parsing layer
│       ├── sharding.py         # SRP shard extraction & categorization
│       ├── filestore.py        # SQLite-backed metadata + shard storage
│       ├── synthesis.py        # Monolithic & package synthesis
│       ├── normalization.py    # Lexical normalization & path rewiring
│       ├── typing_inference.py # AI-driven type hint injection
│       ├── incremental.py      # Incremental ingestion with file hashing
│       └── semantic_search.py  # Embedding-based semantic shard search
│   └── api/
│       ├── __init__.py
│       ├── ingest.py           # Ingestion endpoints
│       ├── shard.py            # Shard management endpoints
│       └── synthesize.py       # Synthesis & blueprint endpoints
├── frontend/
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── pages/
│   │   │   ├── IngestionPage.tsx
│   │   │   ├── ShardExplorerPage.tsx
│   │   │   ├── IdeationPage.tsx
│   │   │   └── SynthesisPage.tsx
│   │   ├── components/
│   │   │   └── Layout.tsx
│   │   ├── hooks/
│   │   │   └── useIngestion.ts
│   │   ├── utils/
│   │   │   └── api.ts
│   │   └── types/
│   │       └── index.ts
│   ├── index.html
│   ├── package.json
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   ├── postcss.config.js
│   └── tsconfig.json
├── py_filestore/
│   ├── shards/
│   │   ├── functions/
│   │   ├── classes/
│   │   └── modules/
│   └── metadata/
│       └── metadata.db
└── README.md
```

## Quick Start

### Prerequisites
- Python 3.10+
- Node.js 18+
- Git

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

### Docker Compose (optional)

```bash
docker-compose up
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/ingest/` | Ingest repositories |
| GET | `/api/v1/ingest/status` | Get ingestion status |
| GET | `/api/v1/ingest/files/{repo_url}` | List Python files |
| POST | `/api/v1/shards/parse/{repo_url}` | Parse repo into shards |
| GET | `/api/v1/shards/` | List shards with filters |
| GET | `/api/v1/shards/categories` | List categories |
| GET | `/api/v1/shards/{shard_id}` | Get shard details |
| POST | `/api/v1/synthesize/monolithic` | Generate monolithic code |
| POST | `/api/v1/synthesize/package` | Generate consolidated package |
| POST | `/api/v1/synthesize/blueprint` | Generate architectural blueprint |
| POST | `/api/v1/synthesize/compatibility` | Check shard compatibility |
| POST | `/api/v1/synthesize/normalize` | Normalize code |
| POST | `/api/v1/synthesize/env` | Generate env files |
| POST | `/api/v1/shard/semantic-search` | Semantic search over shards |

## Optimization Strategies

1. **Concurrent Ingestion:** Async git clone with a worker pool.
2. **Lazy Parsing:** Parse files on-demand during shard extraction.
3. **Incremental Ingestion:** SHA-256 file hashing to skip unchanged files on re-ingest.
4. **Incremental Filestore:** SQLite indexes for fast category/type filtering.
5. **Topological Sort with Cycle Detection:** Tarjan-inspired SCC detection to prevent circular imports during synthesis.
6. **Deduplication:** SHA-256 based source code fingerprinting.
7. **Regex + CST Hybrid:** Fast regex pass first, surgical CST rewrite when needed.
8. **Semantic Search:** Sentence-transformers embeddings for meaning-based shard discovery.
9. **Type Inference:** AI-driven type hint injection for untyped legacy codebases.
10. **Docker Support:** Multi-stage Dockerfiles and docker-compose for one-command deployment.

## License

MIT
