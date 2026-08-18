# AGNOSTIC-HARVESTER Harness

**Zero-Cost LLM Pre-Processing & Context Optimization Framework**

AGNOSTIC-HARVESTER is a standardized, agent-agnostic framework designed to bridge human intent and LLM execution. By shifting the computational burden of context management, task decomposition, linguistic normalization, and error recovery to **zero-cost local deterministic scripts**, the harness preserves up to **85% of the LLM's context window** for high-reasoning tasks.

## Key Features

- **Zero-Token Pre-Processing:** Local Regex, AST parsers, and heuristic engines resolve ambiguity before contacting the model
- **LED v3.0 Linguistic Engine:** Spellcheck, grammar normalization, and ambiguity detection with zero API calls
- **Context Splicing:** Grammar-based text splitting into atomic task units
- **Context Optimization:** AST-driven pruning and compression for maximum headroom
- **Shadow Git Engine:** Parallel git delta tracking without polluting LLM context
- **Shadow Broker:** GitHub research, tool discovery, and global Rust binary installation
- **Shadow Agent:** Background worker for auto-loadouts, error interception, and micro-tool generation
- **Neuro-Modes:** OCD, ADHD, AUTISTIC, BIPOLAR, SCHIZOPHRENIA, SHADOW-CLONES
- **Post-Queue Audit:** Comprehensive integrity checks and interactive recommendations

## Quick Start

```bash
# Initialize harness
python .harness/cli.py init

# Process a prompt
python .harness/cli.py process --prompt "Build a REST API"

# Launch interactive TUI
python .harness/tui.py

# Shadow Broker research
python .harness/cli.py research --query "rust cli tools"

# Run audit
python .harness/cli.py audit
```

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  MODULE 1: LED v3.0 "Human Vibez" Linguistic Engine            │
│  - Zero-LLM Spellcheck / Grammar Normalization                  │
│  - Local Dictionary Ambiguity Resolution & Regex Interception   │
│  - Speculative Branching TUI                                   │
└───────────────────────────────────┬──────────────────────────────┘
                                    │
┌───────────────────────────────────┴──────────────────────────────┐
│  MODULE 2: Sidebar Task Manager & Context Splicer               │
│  - Grammar-based Text Splicing                                  │
│  - Queue Assembly & Sequential State Lock                       │
└───────────────────────────────────┬──────────────────────────────┘
                                    │
┌───────────────────────────────────┴──────────────────────────────┐
│  MODULE 3: Context Optimization Engine (COE)                    │
│  - AST-Driven Context-Weaving & File Pruning                    │
│  - MCP Tool / Skill Headroom Expansion                          │
└───────────────────────────────────┬──────────────────────────────┘
                                    │
┌───────────────────────────────────┴──────────────────────────────┐
│  MODULE 4: LLM Execution Loop & Reactive Tool Synthesis         │
│  - Dispatches Task N to Model                                   │
│  - Reactive Error Catching & Auto-Synthesis of Local Tools      │
└───────────────────────────────────┬──────────────────────────────┘
                                    │
┌───────────────────────────────────┴──────────────────────────────┐
│  MODULE 5: Neural Memory & Shadow Git Engine                    │
│  - .jsonl Dataset Generation & Compaction                       │
│  - State Delta Recording (Shadow Git Nodes)                     │
└───────────────────────────────────┬──────────────────────────────┘
                                    │
┌───────────────────────────────────┴──────────────────────────────┐
│  MODULE 6: Post-Queue Audit & Interactive Recommendation Loop   │
│  - Comprehensive Integrity Audit                                │
│  - Multi-Select Task Recommendation Injection                   │
└──────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
.harness/
├── tools/
│   ├── synthesized/      # Auto-generated micro-tools
│   └── global/           # Globally installed Rust binaries
├── memory/
│   └── dataset.jsonl     # Neural memory dataset
├── steering/
│   └── api-standards.md  # Local steering documents
├── logs/
│   └── harness.log       # Harness execution logs
└── state/
    ├── harness_state.json        # Persistent harness state
    ├── task_dag.json             # Motor Cortex DAG
    ├── tool_manifest.json        # Global tool registry
    └── shadow_deltas.jsonl       # Shadow git deltas

.human/                     # User-level harness state
├── tools/
│   └── manifest.json       # Tool manifest
├── skills/                 # Custom skills
├── memory/                 # Long-term memory
└── config/                 # Configuration files

.shadow-fs/                  # Isolated shadow worktrees
```

## Zero-Cost Functionality Matrix

| Feature | Execution Location | Token Cost | Performance Impact |
|---------|-------------------|------------|-------------------|
| Typo / Grammar Correction | Local Dictionary | **0 Tokens** | Eliminates LLM misunderstanding |
| Ambiguity Disambiguation | Local Regex + TUI | **0 Tokens** | Prevents clarification loops |
| Task Decomposition | Splicing Parser | **0 Tokens** | Focuses model on atomic goals |
| Workspace Context Weaving | Local AST / git diff | **0 Tokens** | Reduces code bloat by 80% |
| Error Handling & Retry | Local stderr Hook | **0 Tokens** | Prevents hallucinated fix loops |
| State Tracking | Shadow Git Delta | **0 Tokens** | Provides revision history |
| Task Queue Execution | Local State Machine | **Model Invocations Only** | Maximizes model headroom |

## Shadow Agent Profiles

### shadow-agent (Background Worker)
- Auto-loadouts on session start
- Error interception and micro-tool generation
- Context-Time Training (CTT) and In-Context Reinforcement Learning (ICRL)

### shadow-broker (Planning & Research)
- GitHub repository research via gh-cli
- Tool creation planning with human confirmation
- Global Rust binary installation and CLI introspection

### shadow-clones (Convergent Optimization)
- Multiple headless agents in isolated shadow-fs
- Semantic AST merging of best implementations
- Worktree-aware git isolation

## Neuro-Modes

| Mode | Objective | Mechanism |
|------|-----------|-----------|
| **OCD** | Perfectionism | Non-stop until 100% test coverage |
| **ADHD** | Rapid triage | Easiest tasks first, parallel searches |
| **AUTISTIC** | Hyper-focus | Single-task, zero switching |
| **BIPOLAR** | Dual-agent consensus | Low-temp logic + high-temp creativity |
| **SCHIZOPHRENIA** | Divergent exploration | Free-Random-Projection context distortion |
| **SHADOW-CLONES** | Convergent optimization | Semantic merge of best AST nodes |

## Integration with Existing Codebase

The harness integrates with:
- **Plugins:** Auto-discovery and tool extraction from `plugins/` directory
- **MCP Servers:** Registration of discovered MCP servers in tool manifest
- **Agent Profiles:** Shadow agent profiles for background operations
- **Existing Python Code:** Reuses existing helpers, core modules, and API layer

## Documentation

- [Architecture Blueprint](ARCHITECTURE_BLUEPRINT.md) - Full technical design document
- [Harness Modules](ARCHITECTURE_BLUEPRINT.md) - Detailed module specifications

## License

MIT
