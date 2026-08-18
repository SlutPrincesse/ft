# Agent-Wun-Tu-Free on Hugging Face Spaces

Streamlit-based deployment of Agent-Wun-Tu-Free for Hugging Face Spaces.

## Quick Deploy

1. Create a new Space on https://huggingface.co/spaces
2. Select **Streamlit** as the SDK
3. Upload this repository or connect to your git repo
4. Add the following secrets in **Space Settings > Secrets**:
   - `LLM_API_KEY` — API key for your chosen provider
   - `LLM_BASE_URL` — Base URL (e.g. `http://localhost:11434` for Ollama)
   - `LLM_MODEL` — Default model name (e.g. `llama3`)

## Local Development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```

## Architecture

| Component | Purpose |
|-----------|---------|
| `app.py` | Streamlit UI and session management |
| `agent.py` | Agent runtime, context, logging |
| `provider/` | Multi-backend LLM routing |
| `core/` | LoopX, TaskPlan, SME, Trelix, ReQL adapters |
| `memory/` | Conversation + key-value memory |
| `helpers/` | Shared utilities |
| `plugins/` | Plugin system |
| `tools/` | Browser, security, budget tools |

## Hugging Face Spaces Compatibility

- Runs on CPU by default
- Uses free-tier providers by default
- No Docker required
- State stored in `st.session_state`
- File uploads limited to 200 MB
