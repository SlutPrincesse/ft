import ast
import re
from typing import Optional, Dict, Any, List
import logging

logger = logging.getLogger(__name__)

BUILTIN_TYPES = {
    "int": "int",
    "float": "float",
    "str": "str",
    "bool": "bool",
    "list": "list",
    "dict": "dict",
    "set": "set",
    "tuple": "tuple",
    "None": "None",
    "True": "bool",
    "False": "bool",
}

RETURN_TYPE_PATTERNS = [
    (r"return\s+(\d+)", "int"),
    (r"return\s+([\d.]+)", "float"),
    (r"return\s+['\"](.*?)['\"]", "str"),
    (r"return\s+True|False", "bool"),
    (r"return\s+\[", "list"),
    (r"return\s+\{", "dict"),
    (r"return\s+\(.*?,.*?\)", "tuple"),
    (r"return\s+None", "None"),
]


class TypeInferenceEngine:
    def infer_function_return(self, source_code: str) -> Optional[str]:
        for pattern, typ in RETURN_TYPE_PATTERNS:
            if re.search(pattern, source_code):
                return typ
        return None

    def infer_variable_type(self, source_code: str, var_name: str) -> Optional[str]:
        pattern = rf"{var_name}\s*=\s*([^\n]+)"
        match = re.search(pattern, source_code)
        if not match:
            return None
        value = match.group(1).strip()
        if value in ("True", "False"):
            return "bool"
        if value in ("None",):
            return "None"
        if re.match(r"^-?\d+$", value):
            return "int"
        if re.match(r"^-?\d+\.\d+$", value):
            return "float"
        if re.match(r"^['\"]", value):
            return "str"
        if value.startswith("[") or value.startswith("list("):
            return "list"
        if value.startswith("{") or value.startswith("dict("):
            return "dict"
        if value.startswith("("):
            return "tuple"
        if value.startswith("set("):
            return "set"
        return None

    def infer_from_usage(self, source_code: str) -> Dict[str, str]:
        tree = ast.parse(source_code)
        hints = {}
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                ret_type = self.infer_function_return(ast.unparse(node))
                if ret_type:
                    hints[node.name] = ret_type
        return hints

    def augment_ast_with_hints(self, source: str) -> str:
        try:
            tree = ast.parse(source)
        except SyntaxError:
            return source

        hints = self.infer_from_usage(source)
        transformer = TypeHintInjector(hints)
        new_tree = transformer.visit(tree)
        ast.fix_missing_locations(new_tree)
        return ast.unparse(new_tree)


class TypeHintInjector(ast.NodeTransformer):
    def __init__(self, hints: Dict[str, str]):
        self.hints = hints

    def visit_FunctionDef(self, node: ast.FunctionDef) -> ast.AST:
        ret_type = self.hints.get(node.name)
        if ret_type and not node.returns:
            try:
                node.returns = ast.Name(id=ret_type, ctx=ast.Load())
            except Exception:
                pass
        self.generic_visit(node)
        return node

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> ast.AST:
        ret_type = self.hints.get(node.name)
        if ret_type and not node.returns:
            try:
                node.returns = ast.Name(id=ret_type, ctx=ast.Load())
            except Exception:
                pass
        self.generic_visit(node)
        return node
