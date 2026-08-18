"""trelix Knowledge Graph — unified code property graph over indexed codebases."""

from ..graph.builder import GraphBuilder, GraphBuildResult
from ..graph.code_graph import CodeGraph
from ..graph.community import (
    assign_communities,
    compute_affected_frontier,
    compute_pagerank,
    detect_communities,
    detect_communities_incremental,
    get_community_summary,
)
from ..graph.concepts import ConceptExtractor, SemanticConcept, load_concepts, save_concepts
from ..graph.persistence import load_graph_metadata, save_graph_metadata
from ..graph.updater import GraphUpdater

__all__ = [
    "CodeGraph",
    "GraphBuilder",
    "GraphBuildResult",
    "ConceptExtractor",
    "SemanticConcept",
    "detect_communities",
    "detect_communities_incremental",
    "compute_affected_frontier",
    "assign_communities",
    "get_community_summary",
    "compute_pagerank",
    "save_graph_metadata",
    "load_graph_metadata",
    "save_concepts",
    "load_concepts",
    "GraphUpdater",
]