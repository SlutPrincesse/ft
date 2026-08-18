"""Agent-Wun core modules.

Integrates:
- loopx: goal state, todo management, quota, evidence, agent runtime bridges
- taskplan: task planning and selection
- sme: spatial memory engine
- trelix: code indexing and retrieval
- reql: property graph memory engine
"""

from . import loopx_adapter
from . import taskplan_adapter
from . import sme_adapter
from . import trelix_adapter
from . import reql_adapter

__all__ = [
    "loopx_adapter",
    "taskplan_adapter",
    "sme_adapter",
    "trelix_adapter",
    "reql_adapter",
]
