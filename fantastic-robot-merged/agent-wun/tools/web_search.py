"""Web search tool."""
import logging
from duckduckgo_search import DDGS

logger = logging.getLogger("agent-wun.tools.web_search")


def search_web(query: str, max_results: int = 5) -> str:
    """Search the web using DuckDuckGo."""
    try:
        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=max_results))
        formatted = []
        for r in results:
            formatted.append(f"- {r.get('title', '')}\n  {r.get('href', '')}\n  {r.get('body', '')}")
        return "\n\n".join(formatted) if formatted else "No results found."
    except Exception as e:
        return f"Search failed: {e}"
