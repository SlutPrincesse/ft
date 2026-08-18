import ast
import libcst as cst
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)


@dataclass
class FunctionShard:
    shard_id: str
    name: str
    source_file: str
    lineno: int
    end_lineno: int
    source_code: str
    docstring: Optional[str]
    args: List[str]
    returns: Optional[str]
    decorators: List[str]
    complexity: int
    imports: List[str]
    body: str


@dataclass
class ClassShard:
    shard_id: str
    name: str
    source_file: str
    lineno: int
    end_lineno: int
    source_code: str
    docstring: Optional[str]
    methods: List[Dict[str, Any]]
    bases: List[str]
    decorators: List[str]
    complexity: int
    imports: List[str]


@dataclass
class ModuleShard:
    shard_id: str
    name: str
    source_file: str
    source_code: str
    imports: List[str]
    top_level_defs: List[str]
    docstring: Optional[str]


class PythonParser:
    def __init__(self):
        self._shard_counter = 0

    def _next_id(self) -> str:
        self._shard_counter += 1
        return f"shard_{self._shard_counter:06d}"

    def parse_file(self, file_path: Path) -> Dict[str, Any]:
        try:
            source = file_path.read_text(encoding="utf-8")
        except Exception as e:
            logger.error(f"Failed to read {file_path}: {e}")
            return {"functions": [], "classes": [], "modules": [], "errors": [str(e)]}

        try:
            tree = ast.parse(source)
        except SyntaxError as e:
            logger.error(f"AST parse error in {file_path}: {e}")
            return {"functions": [], "classes": [], "modules": [], "errors": [str(e)]}

        rel_path = str(file_path)
        functions = self._extract_functions(tree, rel_path, source)
        classes = self._extract_classes(tree, rel_path, source)
        modules = [self._extract_module(tree, rel_path, source)]

        return {"functions": functions, "classes": classes, "modules": modules, "errors": []}

    def _extract_functions(self, tree: ast.AST, source_file: str, source: str) -> List[FunctionShard]:
        functions = []
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) or isinstance(node, ast.AsyncFunctionDef):
                func_source = ast.get_source_segment(source, node) or ""
                args = [arg.arg for arg in node.args.args]
                returns = ast.unparse(node.returns) if node.returns else None
                decorators = [self._decorator_name(d) for d in node.decorator_list]
                docstring = ast.get_docstring(node)
                complexity = self._compute_complexity(node)
                imports = self._collect_imports(tree, node.lineno)

                shard = FunctionShard(
                    shard_id=self._next_id(),
                    name=node.name,
                    source_file=source_file,
                    lineno=node.lineno,
                    end_lineno=node.end_lineno or node.lineno,
                    source_code=func_source,
                    docstring=docstring,
                    args=args,
                    returns=returns,
                    decorators=decorators,
                    complexity=complexity,
                    imports=imports,
                    body=ast.unparse(node),
                )
                functions.append(shard)
        return functions

    def _extract_classes(self, tree: ast.AST, source_file: str, source: str) -> List[ClassShard]:
        classes = []
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                class_source = ast.get_source_segment(source, node) or ""
                bases = [ast.unparse(b) for b in node.bases]
                decorators = [self._decorator_name(d) for d in node.decorator_list]
                docstring = ast.get_docstring(node)
                methods = []
                for item in node.body:
                    if isinstance(item, ast.FunctionDef) or isinstance(item, ast.AsyncFunctionDef):
                        methods.append({
                            "name": item.name,
                            "lineno": item.lineno,
                            "args": [arg.arg for arg in item.args.args],
                            "returns": ast.unparse(item.returns) if item.returns else None,
                        })
                complexity = sum(self._compute_complexity(m) for m in node.body if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef)))
                imports = self._collect_imports(tree, node.lineno)

                shard = ClassShard(
                    shard_id=self._next_id(),
                    name=node.name,
                    source_file=source_file,
                    lineno=node.lineno,
                    end_lineno=node.end_lineno or node.lineno,
                    source_code=class_source,
                    docstring=docstring,
                    methods=methods,
                    bases=bases,
                    decorators=decorators,
                    complexity=complexity,
                    imports=imports,
                )
                classes.append(shard)
        return classes

    def _extract_module(self, tree: ast.AST, source_file: str, source: str) -> ModuleShard:
        docstring = ast.get_docstring(tree)
        imports = []
        top_level_defs = []
        for node in tree.body:
            if isinstance(node, ast.Import) or isinstance(node, ast.ImportFrom):
                imports.append(ast.unparse(node))
            elif isinstance(node, ast.FunctionDef) or isinstance(node, ast.AsyncFunctionDef) or isinstance(node, ast.ClassDef):
                top_level_defs.append(node.name)
        return ModuleShard(
            shard_id=self._next_id(),
            name=Path(source_file).name,
            source_file=source_file,
            source_code=source,
            imports=imports,
            top_level_defs=top_level_defs,
            docstring=docstring,
        )

    def _compute_complexity(self, node: ast.AST) -> int:
        complexity = 1
        for child in ast.walk(node):
            if isinstance(child, (ast.If, ast.For, ast.While, ast.AsyncFor, ast.AsyncWith, ast.With)):
                complexity += 1
            elif isinstance(child, ast.BoolOp):
                complexity += len(child.values) - 1
            elif isinstance(child, (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
                complexity += 1
        return complexity

    def _collect_imports(self, tree: ast.AST, upto_lineno: int) -> List[str]:
        imports = []
        for node in tree.body:
            if hasattr(node, "lineno") and node.lineno > upto_lineno:
                break
            if isinstance(node, ast.Import) or isinstance(node, ast.ImportFrom):
                imports.append(ast.unparse(node))
        return imports

    def _decorator_name(self, node: ast.expr) -> str:
        if isinstance(node, ast.Name):
            return node.id
        if isinstance(node, ast.Attribute):
            return f"{self._decorator_name(node.value)}.{node.attr}"
        if isinstance(node, ast.Call):
            return self._decorator_name(node.func)
        return ast.unparse(node)
