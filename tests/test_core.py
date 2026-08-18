"""Basic tests for core modules."""

import pytest
from pathlib import Path
import sys

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from agnostic.models import Task, TaskStatus, NeuroMode
from agnostic.engine.task_dag import TaskDAG
from agnostic.cognitive.led import LEDv3LinguisticEngine
from agnostic.cognitive.modes import NeuroModeManager
from agnostic.tools.registry import ToolRegistry


def test_task_creation():
    """Test task creation."""
    task = Task(id="test_001", description="Test task")
    assert task.id == "test_001"
    assert task.description == "Test task"
    assert task.status == TaskStatus.PENDING


def test_task_dag_add_task():
    """Test adding task to DAG."""
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        dag = TaskDAG(Path(tmpdir))
        task = dag.add_task("Test task")
        assert task.id.startswith("task_")
        assert len(dag.tasks) == 1


def test_led_processing():
    """Test LED v3.0 processing."""
    led = LEDv3LinguisticEngine()
    profile = led.process("fix teh code pls")
    
    assert profile.original == "fix teh code pls"
    assert profile.normalized != profile.original
    assert len(profile.corrections) > 0


def test_neuro_mode_manager():
    """Test neuro-mode management."""
    manager = NeuroModeManager()
    assert manager.current_mode == NeuroMode.OCD
    
    manager.set_mode(NeuroMode.ADHD)
    assert manager.current_mode == NeuroMode.ADHD
    
    manager.cycle_mode()
    assert manager.current_mode == NeuroMode.AUTISTIC


def test_tool_registry():
    """Test tool registry."""
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        registry = ToolRegistry(Path(tmpdir))
        assert registry.list_tools() == []
        
        from agnostic.models import ToolManifest
        manifest = ToolManifest(
            name="test_tool",
            binary_path="/usr/bin/test",
            schema={},
        )
        registry.register_tool(manifest)
        
        tools = registry.list_tools()
        assert len(tools) == 1
        assert tools[0]["name"] == "test_tool"
