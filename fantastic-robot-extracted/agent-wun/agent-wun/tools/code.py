"""Code execution tool."""
import logging
import subprocess
import tempfile
from pathlib import Path

logger = logging.getLogger("agent-wun.tools.code")


def run_python(code: str, timeout: int = 30) -> str:
    """Execute Python code safely."""
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
            f.write(code)
            f.flush()
            result = subprocess.run(
                ["python3", f.name],
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            output = result.stdout
            if result.stderr:
                output += f"\n[stderr]\n{result.stderr}"
            return output or "(no output)"
    except subprocess.TimeoutExpired:
        return "Execution timed out."
    except Exception as e:
        return f"Execution error: {e}"


def run_bash(command: str, timeout: int = 30) -> str:
    """Execute a bash command safely."""
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        output = result.stdout
        if result.stderr:
            output += f"\n[stderr]\n{result.stderr}"
        return output or "(no output)"
    except subprocess.TimeoutExpired:
        return "Command timed out."
    except Exception as e:
        return f"Command error: {e}"
