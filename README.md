# Agent-Wun-Tu-Free + AGNOSTIC-HARVESTER

Unified autonomous agent framework merging multiple open-source projects into a single, Docker-free, cost-free system, enhanced with the **AGNOSTIC-HARVESTER Harness** - a zero-cost LLM pre-processing and context optimization framework.

## Architecture

```
agent-wun-tu-free/
├── core/               # Main execution loops and adapters
│   ├── loopx/          # Goal-state management and todo loops
│   ├── taskplan/       # Task decomposition and selection
│   ├── sme/            # Spatial memory engine
│   ├── trelix/         # Code indexing and retrieval
│   └── reql/           # Property graph memory
├── memory/             # Memory abstraction layer
├── tools/              # Agent tools (browser, security, budget)
├── provider/           # LLM provider routing (FreeRideV3)
├── server/             # API endpoints
├── agents/             # Agent personalities/prompts
├── plugins/            # Plugin system
├── helpers/            # Shared utilities
├── workspace/          # Agent sandbox
├── run.py              # Main entrypoint
├── requirements.txt    # Unified dependencies
└── .harness/           # AGNOSTIC-HARVESTER Harness
    ├── harness_core.py         # Core orchestrator and state management
    ├── harness_modules.py      # LED v3.0, Context Optimizer, Error Recovery
    ├── shadow_broker.py        # GitHub research and tool planning
    ├── shadow_agent.py         # Background worker and micro-tool generation
    ├── tui.py                  # Terminal User Interface
    ├── integration.py          # Plugin/MCP/Agent integration layer
    └── cli.py                  # Command-line interface
```

## AGNOSTIC-HARVESTER Harness

The harness provides zero-cost pre-processing that preserves up to **85% of the LLM's context window** for high-reasoning tasks.

### Key Features

- **LED v3.0 Linguistic Engine:** Zero-LLM spellcheck, grammar normalization, and ambiguity resolution
- **Context Splicing:** Grammar-based text splitting into atomic task units
- **Context Optimization:** AST-driven pruning and compression
- **Shadow Git Engine:** Parallel git delta tracking without LLM context pollution
- **Shadow Broker:** GitHub repo research, tool discovery, and global Rust binary installation
- **Shadow Agent:** Background worker for auto-loadouts, error interception, and micro-tool generation
- **Neuro-Modes:** OCD, ADHD, AUTISTIC, BIPOLAR, SCHIZOPHRENIA, SHADOW-CLONES
- **Post-Queue Audit:** Comprehensive integrity checks and interactive recommendations

### Quick Start

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

### Directory Structure

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

### Zero-Cost Functionality Matrix

| Feature | Execution Location | Token Cost | Performance Impact |
|---------|-------------------|------------|-------------------|
| Typo / Grammar Correction | Local Dictionary | **0 Tokens** | Eliminates LLM misunderstanding |
| Ambiguity Disambiguation | Local Regex + TUI | **0 Tokens** | Prevents clarification loops |
| Task Decomposition | Splicing Parser | **0 Tokens** | Focuses model on atomic goals |
| Workspace Context Weaving | Local AST / git diff | **0 Tokens** | Reduces code bloat by 80% |
| Error Handling & Retry | Local stderr Hook | **0 Tokens** | Prevents hallucinated fix loops |
| State Tracking | Shadow Git Delta | **0 Tokens** | Provides revision history |
| Task Queue Execution | Local State Machine | **Model Invocations Only** | Maximizes model headroom |

### Shadow Agent Profiles

- **shadow-agent:** Background worker for auto-loadouts, error interception, and micro-tool generation
- **shadow-broker:** Local-first planning and research specialist for GitHub repo discovery and global tool installation
- **shadow-clones:** Convergent optimization profile - spawns multiple headless agents in isolated shadow-fs

### Neuro-Modes

| Mode | Objective | Mechanism |
|------|-----------|-----------|
| **OCD** | Perfectionism | Non-stop until 100% test coverage |
| **ADHD** | Rapid triage | Easiest tasks first, parallel searches |
| **AUTISTIC** | Hyper-focus | Single-task, zero switching |
| **BIPOLAR** | Dual-agent consensus | Low-temp logic + high-temp creativity |
| **SCHIZOPHRENIA** | Divergent exploration | Free-Random-Projection context distortion |
| **SHADOW-CLONES** | Convergent optimization | Semantic merge of best AST nodes |

## Merged Projects

| Project | Contribution | Status |
|---------|-------------|--------|
| Agent Zero | Base runtime, tool system, plugin architecture | Integrated |
| FreeRideV3 | Multi-provider LLM routing (OpenRouter, Groq, Ollama, etc.) | Integrated |
| Hermes Agent | Advanced reasoning, TUI gateway, model tools | Partial |
| AgenticSeek | Browser automation, web search, interpreters | Partial |
| LoopX | Goal loops, quota management, control plane | Integrated |
| Task Master | Task planning, workflow selection | Integrated |
| Spatial Memory Engine | Long-term spatial/vector memory | Integrated |
| Trelix | Code indexing, graph-based retrieval | Integrated |
| ReQL | Property graph memory and query engine | Integrated |

## Quick Start

```bash
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
python run.py
```

## API Server

```bash
python -m server.api
# or
uvicorn server.api:create_app --host 0.0.0.0 --port 8080
```

## Features

- **Zero Docker**: Pure Python deployment
- **Zero Cost**: Uses free-tier LLM providers by default
- **Unified Tools**: All agents share the same tool registry
- **Persistent Memory**: Spatial + graph-based long-term memory
- **Code Intelligence**: Trelix indexing + ReQL graph queries
- **Goal Loops**: LoopX quota and todo management
- **Zero-Token Pre-Processing**: AGNOSTIC-HARVESTER harness for maximum context efficiency

## Configuration

Edit `conf/` directory for:
- Model provider settings
- Agent profiles
- Tool policies
- Memory backends

## License

MIT (see LICENSE for component licenses)
