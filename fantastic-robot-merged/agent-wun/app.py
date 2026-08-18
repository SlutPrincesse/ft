#!/usr/bin/env python3
"""Agent-Wun-Tu-Free Streamlit app for Hugging Face Spaces."""

from __future__ import annotations

import os
import sys
import asyncio
import logging
from pathlib import Path
from typing import Any

import streamlit as st

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

st.set_page_config(
    page_title="Agent-Wun-Tu-Free",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded",
)

if "agent" not in st.session_state:
    try:
        from agent import Agent, AgentConfig
        st.session_state.agent = Agent(agent_name="hf-user", config=AgentConfig(id="hf", name="HF Agent"))
        st.session_state.messages = []
        st.session_state.provider_ready = True
    except Exception as e:
        st.session_state.provider_ready = False
        st.session_state.init_error = str(e)

if "provider" not in st.session_state:
    try:
        from provider import LLMProvider
        st.session_state.provider = LLMProvider()
        st.session_state.provider_ready = True
    except Exception as e:
        st.session_state.provider_ready = False
        st.session_state.provider_error = str(e)


def render_sidebar() -> None:
    with st.sidebar:
        st.header("⚙️ Settings")
        provider_name = st.selectbox(
            "LLM Provider",
            ["ollama", "openrouter", "groq", "openai"],
            index=0,
        )
        model_name = st.text_input("Model", value="llama3")
        st.session_state.provider_config = {
            "provider": provider_name,
            "model": model_name,
        }

        st.subheader("📊 Status")
        try:
            from core import loopx_adapter, taskplan_adapter, sme_adapter, trelix_adapter, reql_adapter
            for name, mod in [
                ("loopx", loopx_adapter),
                ("taskplan", taskplan_adapter),
                ("sme", sme_adapter),
                ("trelix", trelix_adapter),
                ("reql", reql_adapter),
            ]:
                st.caption(f"**{name}**: {'✅' if mod.is_available() else '⚠️ fallback'}")
        except Exception as e:
            st.caption(f"Core status error: {e}")

        if st.button("🗑️ Clear Chat"):
            st.session_state.messages = []
            st.rerun()


def render_chat() -> None:
    st.header("💬 Chat")

    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    if prompt := st.chat_input("Message Agent-Wun-Tu-Free..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        try:
            provider = st.session_state.get("provider")
            cfg = st.session_state.get("provider_config", {})
            if provider is None:
                from provider import LLMProvider
                provider = LLMProvider(cfg)
                st.session_state.provider = provider

            messages = [{"role": m["role"], "content": m["content"]} for m in st.session_state.messages]
            reply = asyncio.run(provider.chat(messages, model=cfg.get("model")))
        except Exception as e:
            reply = f"[error] {e}"

        st.session_state.messages.append({"role": "assistant", "content": reply})
        with st.chat_message("assistant"):
            st.markdown(reply)


def render_memory() -> None:
    st.header("🧠 Memory")
    try:
        from memory import MemoryStore, ConversationMemory
        col1, col2 = st.columns(2)
        with col1:
            st.subheader("Memory Store")
            key = st.text_input("Key")
            value = st.text_input("Value")
            if st.button("Store") and key:
                MemoryStore().set(key, value)
                st.success(f"Stored {key}")
        with col2:
            st.subheader("Conversation History")
            history = ConversationMemory().get_history(limit=20)
            for item in history:
                st.caption(f"**{item['role']}**: {item['content'][:120]}")
    except Exception as e:
        st.error(f"Memory module error: {e}")


def render_tools() -> None:
    st.header("🛠️ Tools")
    try:
        agent = st.session_state.get("agent")
        if agent:
            tools = agent.list_tools()
            st.write("Registered tools:", tools)
        else:
            st.warning("Agent not initialized")
    except Exception as e:
        st.error(f"Tools error: {e}")


def main() -> None:
    if not st.session_state.get("provider_ready", False):
        st.error(f"❌ Initialization failed: {st.session_state.get('init_error', st.session_state.get('provider_error', 'unknown'))}")
        st.info("This Space requires the following secrets in HF Spaces settings: `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL`")
        return

    render_sidebar()

    tab_chat, tab_memory, tab_tools = st.tabs(["Chat", "Memory", "Tools"])
    with tab_chat:
        render_chat()
    with tab_memory:
        render_memory()
    with tab_tools:
        render_tools()


if __name__ == "__main__":
    main()
