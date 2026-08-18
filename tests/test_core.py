import ast
import pytest

from backend.core.parser import PythonParser
from backend.core.sharding import SRPSharder
from backend.core.normalization import RegexNormalizer, EnvironmentProvisioner
from backend.core.synthesis import SynthesisEngine
from backend.core.filestore import ShardFilestore, ShardMetadata
from backend.core.typing_inference import TypeInferenceEngine
from backend.core.incremental import IncrementalIngestion


@pytest.fixture
def parser():
    return PythonParser()


@pytest.fixture
def sharder():
    return SRPSharder()


@pytest.fixture
def normalizer():
    return RegexNormalizer()


@pytest.fixture
def provisioner():
    return EnvironmentProvisioner(output_dir="/tmp/pyshard_test_env")


@pytest.fixture
def filestore():
    return ShardFilestore(filestore_root="/tmp/pyshard_test_filestore")


@pytest.fixture
def type_engine():
    return TypeInferenceEngine()


def test_parser_extracts_function(parser):
    source = """
def hello(name: str) -> str:
    return f"Hello {name}"
"""
    import tempfile, pathlib
    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        f.write(source)
        path = pathlib.Path(f.name)
    try:
        result = parser.parse_file(path)
        assert len(result["functions"]) == 1
        assert result["functions"][0].name == "hello"
        assert result["functions"][0].returns == "str"
    finally:
        path.unlink()


def test_parser_extracts_class(parser):
    source = """
class MyClass:
    def method(self):
        pass
"""
    import tempfile, pathlib
    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        f.write(source)
        path = pathlib.Path(f.name)
    try:
        result = parser.parse_file(path)
        assert len(result["classes"]) == 1
        assert result["classes"][0].name == "MyClass"
        assert len(result["classes"][0].methods) == 1
    finally:
        path.unlink()


def test_sharder_categorizes():
    sharder = SRPSharder()
    assert sharder.categorize("fetch_http", "import aiohttp async def fetch", [], "HTTP client") == "asyncio"
    assert sharder.categorize("hash_password", "import hashlib def hash", [], "Crypto util") == "crypto"


def test_normalizer_removes_prints():
    normalizer = RegexNormalizer()
    source = "print('debug')\nx = 1\n"
    result = normalizer.normalize(source)
    assert "print" not in result
    assert "x = 1" in result


def test_provisioner_generates_requirements(provisioner):
    reqs = provisioner.generate_requirements(["fastapi", "pydantic"])
    assert "fastapi" in reqs
    assert "pydantic" in reqs


def test_filestore_store_and_get(filestore):
    metadata = ShardMetadata(
        shard_id="test_001",
        category="utils",
        shard_type="function",
        source_repo="test",
        source_file="test.py",
        name="test_func",
        description="A test function",
        cyclomatic_complexity=1,
        import_dependencies=[],
    )
    filestore.store_shard(type("Obj", (), {"source_code": "def test_func(): pass", "body": "def test_func(): pass"})(), metadata)
    record = filestore.get_shard("test_001")
    assert record is not None
    assert record["name"] == "test_func"


def test_type_inference():
    engine = TypeInferenceEngine()
    source = """
def add(a, b):
    return a + b
"""
    hints = engine.infer_from_usage(source)
    assert "add" in hints


def test_incremental_ingestion():
    engine = IncrementalIngestion()
    import tempfile, pathlib
    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        f.write("x = 1\n")
        path = pathlib.Path(f.name)
    try:
        assert engine.is_changed(path) is True
        engine.update(path)
        assert engine.is_changed(path) is False
    finally:
        path.unlink()


def test_synthesis_deduplicate(filestore):
    engine = SynthesisEngine(filestore)
    ids = ["a", "b"]
    deduped = engine.deduplicate_shards(ids)
    assert len(deduped) <= len(ids)
