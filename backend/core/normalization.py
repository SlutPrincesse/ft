import re
import libcst as cst
from libcst import matchers as m
from typing import List, Dict, Optional
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class LexicalNormalizer(cst.CSTTransformer):
    def __init__(self, rules: Optional[Dict[str, str]] = None):
        self.rules = rules or {}
        self.replacements: List[tuple] = []

    def leave_Name(self, original_node: cst.Name, updated_node: cst.Name) -> cst.Name:
        new_name = self.rules.get(original_node.value, original_node.value)
        if new_name != original_node.value:
            return updated_node.with_changes(value=new_name)
        return updated_node

    def leave_Attribute(self, original_node: cst.Attribute, updated_node: cst.Attribute) -> cst.Attribute:
        return updated_node


class RegexNormalizer:
    PATTERNS = [
        (r"\bprint\s*\([^)]*\)", "# removed debug print"),
        (r"\bpprint\s*\([^)]*\)", "# removed debug pprint"),
        (r"console\.log\s*\([^)]*\)", "// removed debug log"),
        (r"debugger;", "// removed debugger"),
    ]

    def __init__(self, custom_patterns: Optional[List[tuple]] = None):
        self.patterns = custom_patterns or self.PATTERNS

    def normalize(self, source: str) -> str:
        for pattern, replacement in self.patterns:
            source = re.sub(pattern, replacement, source, flags=re.MULTILINE)
        return source

    def normalize_paths(self, source: str, old_root: str, new_root: str) -> str:
        source = source.replace(old_root, new_root)
        source = re.sub(r"(from|import)\s+\.{1,3}([a-zA-Z0-9_\.]+)", self._fix_relative_imports, source)
        return source

    def _fix_relative_imports(self, match: re.Match) -> str:
        import_type = match.group(1)
        path = match.group(2)
        parts = path.split(".")
        if len(parts) > 1:
            return f"{import_type} {'.'.join(parts[1:])}"
        return match.group(0)

    def snake_case_transform(self, source: str) -> str:
        def to_snake(match: re.Match) -> str:
            word = match.group(0)
            s1 = re.sub('(.)([A-Z][a-z]+)', r'\\1_\\2', word)
            return re.sub('([a-z0-9])([A-Z])', r'\\1_\\2', s1).lower()

        source = re.sub(r'\b[A-Z][a-z]+[A-Z][a-zA-Z0-9]*\b', to_snake, source)
        source = re.sub(r'\b[A-Z][A-Z0-9]*(?=[A-Z_])', lambda m: m.group(0).lower(), source)
        return source


class EnvironmentProvisioner:
    def __init__(self, output_dir: str = "/tmp/pyshard_env"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def generate_requirements(self, imports: List[str]) -> str:
        lines = ["# Auto-generated requirements.txt\n"]
        for imp in sorted(set(imports)):
            lines.append(f"{imp}\n")
        return "".join(lines)

    def generate_pyproject(self, package_name: str, python_version: str = ">=3.10", dependencies: Optional[List[str]] = None) -> str:
        deps = dependencies or []
        return f'''[build-system]
requires = ["setuptools>=68.0", "wheel"]
build-backend = "setuptools.backends.legacy:build"

[project]
name = "{package_name}"
version = "0.1.0"
description = "Auto-generated package"
requires-python = "{python_version}"
dependencies = [
{self._format_list(deps)}
]

[project.optional-dependencies]
dev = ["ruff>=0.1.0", "mypy>=1.0", "pytest>=7.0"]

[tool.ruff]
line-length = 100
select = ["E", "F", "I", "UP"]

[tool.mypy]
strict = true
'''

    def generate_env_template(self, vars: List[str]) -> str:
        lines = ["# Environment variables template\n"]
        for var in sorted(set(vars)):
            lines.append(f"{var}=\n")
        return "".join(lines)

    def generate_validation_script(self) -> str:
        return '''#!/usr/bin/env python3
"""Validation script for synthesized package."""
import sys
import subprocess
from pathlib import Path

def main():
    print("Running Ruff linting...")
    result = subprocess.run(["ruff", "check", "."], capture_output=True)
    if result.returncode != 0:
        print("Ruff failed:", result.stderr.decode())
        return 1

    print("Running type check (mypy)...")
    result = subprocess.run(["mypy", "."], capture_output=True)
    if result.returncode != 0:
        print("Mypy failed:", result.stderr.decode())
        return 1

    print("Running tests...")
    result = subprocess.run(["pytest", "tests/"], capture_output=True)
    if result.returncode != 0:
        print("Tests failed:", result.stderr.decode())
        return 1

    print("All validations passed!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
'''

    def _format_list(self, items: List[str]) -> str:
        return "\n".join(f'    "{item}",' for item in items)
