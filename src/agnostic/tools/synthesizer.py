"""Tool synthesizer for automatic micro-tool generation."""

import logging
import re
from pathlib import Path
from typing import Any, Dict, Optional


class ToolSynthesizer:
    """
    Generates micro-tools to handle missing/failing tools.
    """
    
    def __init__(self, tools_dir: Path):
        self.tools_dir = tools_dir
        self.tools_dir.mkdir(parents=True, exist_ok=True)
        self.logger = logging.getLogger("agnostic.tools.synthesizer")
    
    def synthesize(self, task_id: str, error: str, context: Optional[str] = None) -> Optional[Path]:
        """
        Synthesize a tool to handle an error.
        
        Args:
            task_id: Task ID that failed
            error: Error message or stderr
            context: Additional context
            
        Returns:
            Path to synthesized tool or None
        """
        tool_path = self.tools_dir / f"synthesized_tool_{task_id}.py"
        
        # Analyze error pattern
        error_type = self._classify_error(error)
        
        # Generate tool based on error type
        content = self._generate_tool_content(task_id, error_type, error, context)
        
        tool_path.write_text(content)
        tool_path.chmod(0o755)
        
        self.logger.info(f"Synthesized tool: {tool_path}")
        return tool_path
    
    def _classify_error(self, error: str) -> str:
        """Classify error type."""
        error_lower = error.lower()
        
        if "modulenotfound" in error_lower or "importerror" in error_lower:
            return "missing_module"
        elif "command not found" in error_lower:
            return "missing_command"
        elif "permission denied" in error_lower:
            return "permission"
        elif "no such file" in error_lower:
            return "missing_file"
        elif "connection refused" in error_lower or "timeout" in error_lower:
            return "network"
        elif "syntax" in error_lower or "indentation" in error_lower:
            return "syntax"
        else:
            return "unknown"
    
    def _generate_tool_content(self, task_id: str, error_type: str, error: str, context: Optional[str]) -> str:
        """Generate tool content based on error type."""
        
        templates = {
            "missing_module": self._template_missing_module,
            "missing_command": self._template_missing_command,
            "permission": self._template_permission,
            "missing_file": self._template_missing_file,
            "network": self._template_network,
            "syntax": self_template_syntax,
            "unknown": self._template_unknown,
        }
        
        template_func = templates.get(error_type, self._template_unknown)
        return template_func(task_id, error, context)
    
    def _template_missing_module(self, task_id: str, error: str, context: Optional[str]) -> str:
        """Template for missing module errors."""
        return f'''#!/usr/bin/env python3
"""
Synthesized tool for task {task_id}
Error: Missing Python module
Original error: {error[:100]}
"""

import subprocess
import sys

def main():
    print("Synthesized tool: Install missing Python module")
    # TODO: Extract module name from error and install
    # For now, just report
    print(f"Error: {{sys.argv[1]}}")
    return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: synthesized_tool_{task_id}.py <module_name>")
        sys.exit(1)
    sys.exit(main())
'''
    
    def _template_missing_command(self, task_id: str, error: str, context: Optional[str]) -> str:
        """Template for missing command errors."""
        return f'''#!/usr/bin/env python3
"""
Synthesized tool for task {task_id}
Error: Missing command
Original error: {error[:100]}
"""

import subprocess
import sys

def main():
    print("Synthesized tool: Install missing command")
    # TODO: Install missing command via cargo/pip/etc
    print(f"Command not found: {{sys.argv[1]}}")
    return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: synthesized_tool_{task_id}.py <command_name>")
        sys.exit(1)
    sys.exit(main())
'''
    
    def _template_permission(self, task_id: str, error: str, context: Optional[str]) -> str:
        """Template for permission errors."""
        return f'''#!/usr/bin/env python3
"""
Synthesized tool for task {task_id}
Error: Permission denied
Original error: {error[:100]}
"""

import os
import sys

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "."
    os.chmod(path, 0o755)
    print(f"Fixed permissions for: {{path}}")
    return 0

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: synthesized_tool_{task_id}.py <path>")
        sys.exit(1)
    sys.exit(main())
'''
    
    def _template_missing_file(self, task_id: str, error: str, context: Optional[str]) -> str:
        """Template for missing file errors."""
        return f'''#!/usr/bin/env python3
"""
Synthesized tool for task {task_id}
Error: No such file or directory
Original error: {error[:100]}
"""

from pathlib import Path
import sys

def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.touch()
    print(f"Created file: {{path}}")
    return 0

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: synthesized_tool_{task_id}.py <file_path>")
        sys.exit(1)
    sys.exit(main())
'''
    
    def _template_network(self, task_id: str, error: str, context: Optional[str]) -> str:
        """Template for network errors."""
        return f'''#!/usr/bin/env python3
"""
Synthesized tool for task {task_id}
Error: Network issue
Original error: {error[:100]}
"""

import time
import sys

def main():
    print("Synthesized tool: Network error handler")
    # Retry logic placeholder
    for i in range(3):
        print(f"Retry attempt {{i + 1}}...")
        time.sleep(1)
    return 0

if __name__ == "__main__":
    sys.exit(main())
'''
    
    def _template_syntax(self, task_id: str, error: str, context: Optional[str]) -> str:
        """Template for syntax errors."""
        return f'''#!/usr/bin/env python3
"""
Synthesized tool for task {task_id}
Error: Syntax error
Original error: {error[:100]}
"""

import ast
import sys

def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else "."
    try:
        with open(filepath, "r") as f:
            ast.parse(f.read())
        print(f"Syntax OK: {{filepath}}")
        return 0
    except SyntaxError as e:
        print(f"Syntax error: {{e}}")
        return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: synthesized_tool_{task_id}.py <filepath>")
        sys.exit(1)
    sys.exit(main())
'''
    
    def _template_unknown(self, task_id: str, error: str, context: Optional[str]) -> str:
        """Template for unknown errors."""
        return f'''#!/usr/bin/env python3
"""
Synthesized tool for task {task_id}
Error: Unknown
Original error: {error[:100]}
"""

import sys

def main():
    print("Synthesized tool: Generic error handler")
    print(f"Error: {{sys.argv[1]}}")
    return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: synthesized_tool_{task_id}.py <error_message>")
        sys.exit(1)
    sys.exit(main())
'''
