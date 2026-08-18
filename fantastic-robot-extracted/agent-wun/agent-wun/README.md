# Agent-Wun

Unified autonomous agent framework merging [Agent Zero](https://github.com/agent0ai/agent-zero), [Hermes Agent](https://github.com/NousResearch/hermes-agent), [AgenticSeek](https://github.com/Fosowl/agenticSeek), and [FreeRideV3](https://github.com/Shaivpidadi/FreeRideV3) into a single, maintainable, local-free, 100% free platform.

## Architecture

- **Base Framework**: Agent Zero's web-centric agent runtime with plugins, skills, and MCP tools
- **Agent Intelligence**: Hermes Agent's self-improving learning loop, memory, context compression, and 100+ tool implementations
- **Task Routing**: AgenticSeek's intelligent agent router (Casual, Coder, File, Browser, Planner)
- **LLM Gateway**: FreeRideV3's free-tier multi-provider failover with health-aware routing
- **Voice**: AgenticSeek's TTS/STT interface
- **Browser**: Dual browser support (Playwright from Agent Zero + Selenium stealth from AgenticSeek)

## Quick Start

```bash
pip install -r requirements.txt
python run.py
```

## Features

- Web-based agent control panel (Agent Zero)
- Autonomous learning and skill creation (Hermes Agent)
- Intelligent task routing to specialized agents (AgenticSeek)
- Free LLM inference with automatic failover (FreeRideV3)
- Voice interface with TTS/STT
- Browser automation (stealth mode + DOM annotation)
- Multi-agent cooperation and delegation
- Session memory with FTS5 search
- Scheduled automations
- Plugin marketplace
- MCP server integration
- No local required
- 100% free/open-source

## Project Structure

```
agent-wun/
├── agents/          # Agent profiles and configurations
├── api/             # REST API endpoints
├── core/            # Core agent runtime and models
├── tools/           # Unified tool system
├── providers/       # Free LLM provider plugins (FreeRideV3)
├── skills/          # Agent skills and workflows
├── plugins/         # Plugin system
├── webui/           # Web interface
├── conf/            # Configuration files
├── helpers/         # Shared utilities
├── prompts/         # Prompt templates
├── scripts/         # Setup and utility scripts
├── tests/           # Test suite
└── run.py           # Main entry point
```

## License

MIT
