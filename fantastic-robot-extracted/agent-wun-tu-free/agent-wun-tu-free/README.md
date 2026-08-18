# Agent-Wun-Tu-Free

Unified autonomous agent framework merging multiple open-source projects into a single, Docker-free, cost-free system.

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
└── requirements.txt    # Unified dependencies
```

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

## Configuration

Edit `conf/` directory for:
- Model provider settings
- Agent profiles
- Tool policies
- Memory backends

## License

MIT (see LICENSE for component licenses)
