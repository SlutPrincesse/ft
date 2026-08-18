import ast
import re
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from pathlib import Path
import logging
from .parser import FunctionShard, ClassShard, ModuleShard

logger = logging.getLogger(__name__)

CATEGORY_PATTERNS = {
    "asyncio": ["async", "await", "asyncio", "coroutine", "event_loop", "aiohttp"],
    "data_processing": ["pandas", "numpy", "json", "csv", "dataframe", "transform", "clean", "parse"],
    "crypto": ["hash", "encrypt", "decrypt", "cipher", "sha", "aes", "rsa", "crypto"],
    "api_routing": ["route", "endpoint", "handler", "middleware", "request", "response", "fastapi", "flask", "router"],
    "database": ["sql", "query", "db", "database", "cursor", "transaction", "orm", "model"],
    "validation": ["valid", "schema", "pydantic", "type", "check", "verify", "assert"],
    "logging": ["log", "logger", "debug", "info", "warning", "error", "audit"],
    "utils": ["util", "helper", "common", "shared", "misc", "tool"],
}


class SRPSharder:
    def __init__(self):
        self._shard_counter = 0

    def categorize(self, name: str, source_code: str, imports: List[str], docstring: Optional[str]) -> str:
        text = f"{name} {source_code} {' '.join(imports)} {docstring or ''}".lower()
        scores = {}
        for category, patterns in CATEGORY_PATTERNS.items():
            score = sum(1 for p in patterns if p in text)
            if score > 0:
                scores[category] = score
        if not scores:
            return "utils"
        return max(scores, key=scores.get)

    def shard_file(self, parsed: Dict[str, Any], source_repo: str) -> List[Dict[str, Any]]:
        shards = []
        for func in parsed.get("functions", []):
            category = self.categorize(func.name, func.source_code, func.imports, func.docstring)
            shards.append({
                "shard": func,
                "category": category,
                "shard_type": "function",
                "source_repo": source_repo,
            })
        for cls in parsed.get("classes", []):
            category = self.categorize(cls.name, cls.source_code, cls.imports, cls.docstring)
            shards.append({
                "shard": cls,
                "category": category,
                "shard_type": "class",
                "source_repo": source_repo,
            })
        for mod in parsed.get("modules", []):
            category = self.categorize(mod.name, mod.source_code, mod.imports, mod.docstring)
            shards.append({
                "shard": mod,
                "category": category,
                "shard_type": "module",
                "source_repo": source_repo,
            })
        return shards

    def split_large_shard(self, shard: Any, max_complexity: int = 15) -> List[Any]:
        if hasattr(shard, "complexity") and shard.complexity <= max_complexity:
            return [shard]
        if not hasattr(shard, "body") or not hasattr(shard, "source_code"):
            return [shard]
        try:
            tree = ast.parse(shard.source_code)
            sub_shards = []
            for node in tree.body:
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    sub = ast.Module(body=[node], type_ignores=[])
                    ast.fix_missing_locations(sub)
                    sub_code = ast.unparse(sub)
                    sub_shards.append(type(shard)(
                        shard_id=f"{shard.shard_id}_sub_{len(sub_shards)}",
                        name=node.name,
                        source_file=shard.source_file,
                        lineno=node.lineno,
                        end_lineno=node.end_lineno or node.lineno,
                        source_code=sub_code,
                        docstring=ast.get_docstring(node),
                        args=[arg.arg for arg in node.args.args] if hasattr(shard, "args") else [],
                        returns=ast.unparse(node.returns) if node.returns else None if hasattr(shard, "returns") else None,
                        decorators=[] if not hasattr(shard, "decorators") else shard.decorators,
                        complexity=self._compute_complexity(node),
                        imports=[] if not hasattr(shard, "imports") else shard.imports,
                        body=sub_code if hasattr(shard, "body") else "",
                    ))
            return sub_shards if sub_shards else [shard]
        except Exception:
            return [shard]

    def _compute_complexity(self, node: ast.AST) -> int:
        complexity = 1
        for child in ast.walk(node):
            if isinstance(child, (ast.If, ast.For, ast.While, ast.AsyncFor, ast.AsyncWith, ast.With)):
                complexity += 1
            elif isinstance(child, ast.BoolOp):
                complexity += len(child.values) - 1
        return complexity
