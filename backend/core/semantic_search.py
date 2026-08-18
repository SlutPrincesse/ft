import logging
from typing import List, Dict, Any, Optional
from sentence_transformers import SentenceTransformer

logger = logging.getLogger(__name__)


class SemanticSearchEngine:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        self.model_name = model_name
        self._model: Optional[SentenceTransformer] = None
        self._index: Dict[str, Any] = {}

    @property
    def model(self) -> SentenceTransformer:
        if self._model is None:
            self._model = SentenceTransformer(self.model_name)
        return self._model

    def index_shard(self, shard_id: str, text: str, metadata: Dict[str, Any]) -> None:
        embedding = self.model.encode(text, convert_to_numpy=True).tolist()
        self._index[shard_id] = {
            "embedding": embedding,
            "text": text,
            "metadata": metadata,
        }

    def search(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        if not self._index:
            return []
        query_embedding = self.model.encode(query, convert_to_numpy=True)
        results = []
        for shard_id, data in self._index.items():
            score = self._cosine_similarity(query_embedding, data["embedding"])
            results.append({
                "shard_id": shard_id,
                "score": score,
                "text": data["text"],
                "metadata": data["metadata"],
            })
        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:top_k]

    def _cosine_similarity(self, a, b) -> float:
        import numpy as np
        a = np.array(a)
        b = np.array(b)
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

    def remove(self, shard_id: str) -> None:
        self._index.pop(shard_id, None)

    def clear(self) -> None:
        self._index.clear()
