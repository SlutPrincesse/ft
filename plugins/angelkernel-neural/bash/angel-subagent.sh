#!/bin/bash
# angel-subagent v2 — Multi-model subagent system with skill equipping & free provider routing
# Spawns a subagent using any of 30+ free models from AngelKernel's provider chain
# Each subagent auto-equips relevant skills based on task context
#
# Usage:
#   angel-subagent list                          # List available subagents
#   angel-subagent @thinker "What is quantum?"   # Use @mention routing
#   angel-subagent <model_id> "do something"     # Direct model id
#   angel-subagent auto "complex task"            # Auto-select best subagent

ANGEL_SCRIPT="subagent"
ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true
SUBAGENT_CONF="$ANGEL_HOME/subagents/subagent.conf"
SUBAGENT_LOG="$ANGEL_HOME/store/subagent_calls.log"
mkdir -p "$ANGEL_HOME/subagents" "$(dirname "$SUBAGENT_LOG")"

# ============================================================================
# FREE MODEL REGISTRY — One subagent per model from our free provider chain
# Sourced from: KiloProxy providers.json + Pollinations free tier + opencode/
# ZERO API KEYS REQUIRED for listed models
# ============================================================================

declare -A FREE_MODELS
declare -A MODEL_ROLES
declare -A MODEL_PROVIDER
declare -A MODEL_CAPABILITIES

# --- Pollinations Free Tier (gen.pollinations.ai, no key needed for basic) ---
FREE_MODELS["openai"]="OpenAI GPT (general purpose)"
MODEL_ROLES["openai"]="generalist"
MODEL_PROVIDER["openai"]="pollinations"
MODEL_CAPABILITIES["openai"]="text,tools,reasoning"

FREE_MODELS["openai-fast"]="OpenAI GPT Fast (quick responses)"
MODEL_ROLES["openai-fast"]="executor"
MODEL_PROVIDER["openai-fast"]="pollinations"
MODEL_CAPABILITIES["openai-fast"]="text,tools"

FREE_MODELS["openai-large"]="OpenAI GPT Large (deep reasoning)"
MODEL_ROLES["openai-large"]="thinker"
MODEL_PROVIDER["openai-large"]="pollinations"
MODEL_CAPABILITIES["openai-large"]="text,tools,reasoning"

FREE_MODELS["mistral"]="Mistral (balanced)"  
MODEL_ROLES["mistral"]="analyst"
MODEL_PROVIDER["mistral"]="pollinations"
MODEL_CAPABILITIES["mistral"]="text,tools"

FREE_MODELS["gemini"]="Google Gemini (multimodal)"
MODEL_ROLES["gemini"]="researcher"
MODEL_PROVIDER["gemini"]="pollinations"
MODEL_CAPABILITIES["gemini"]="text,vision"

FREE_MODELS["deepseek"]="DeepSeek (coding & analysis)"
MODEL_ROLES["deepseek"]="coder"
MODEL_PROVIDER["deepseek"]="pollinations"
MODEL_CAPABILITIES["deepseek"]="text,coding"

FREE_MODELS["qwen-coder"]="Qwen Coder (code generation)"
MODEL_ROLES["qwen-coder"]="coder"
MODEL_PROVIDER["qwen-coder"]="pollinations"
MODEL_CAPABILITIES["qwen-coder"]="text,coding,tools"

FREE_MODELS["llama"]="Llama (open source)"
MODEL_ROLES["llama"]="generalist"
MODEL_PROVIDER["llama"]="pollinations"
MODEL_CAPABILITIES["llama"]="text"

FREE_MODELS["claude"]="Claude (safety-focused)"
MODEL_ROLES["claude"]="critic"
MODEL_PROVIDER["claude"]="pollinations"
MODEL_CAPABILITIES["claude"]="text,reasoning"

FREE_MODELS["perplexity"]="Perplexity (research)"
MODEL_ROLES["perplexity"]="researcher"
MODEL_PROVIDER["perplexity"]="pollinations"
MODEL_CAPABILITIES["perplexity"]="text,search"

FREE_MODELS["grok-imagine"]="Grok Imagine (image gen)"
MODEL_ROLES["grok-imagine"]="artist"
MODEL_PROVIDER["grok-imagine"]="pollinations"
MODEL_CAPABILITIES["grok-imagine"]="image"

FREE_MODELS["flux"]="Flux (image generation)"  
MODEL_ROLES["flux"]="artist"
MODEL_PROVIDER["flux"]="pollinations"
MODEL_CAPABILITIES["flux"]="image"

FREE_MODELS["elevenlabs"]="ElevenLabs (text-to-speech)"
MODEL_ROLES["elevenlabs"]="speaker"
MODEL_PROVIDER["elevenlabs"]="pollinations"
MODEL_CAPABILITIES["elevenlabs"]="audio,tts"

# --- KiloProxy Free Providers (from providers.json, may need API key) ---
FREE_MODELS["poolside-laguna"]="Poolside Laguna (code)"
MODEL_ROLES["poolside-laguna"]="coder"
MODEL_PROVIDER["poolside-laguna"]="poolside"
MODEL_CAPABILITIES["poolside-laguna"]="text,coding"

FREE_MODELS["gemini-flash"]="Gemini Flash (fast, cheap)"
MODEL_ROLES["gemini-flash"]="fast-thinker"
MODEL_PROVIDER["gemini-flash"]="google"
MODEL_CAPABILITIES["gemini-flash"]="text,vision,tools"

FREE_MODELS["llama-3.3-70b"]="Llama 3.3 70B (powerful)"
MODEL_ROLES["llama-3.3-70b"]="thinker"
MODEL_PROVIDER["llama-3.3-70b"]="groq"
MODEL_CAPABILITIES["llama-3.3-70b"]="text,reasoning"

FREE_MODELS["nemotron-70b"]="Nemotron 70B (reasoning)"
MODEL_ROLES["nemotron-70b"]="critic"
MODEL_PROVIDER["nemotron-70b"]="nvidia"
MODEL_CAPABILITIES["nemotron-70b"]="text,reasoning"

FREE_MODELS["qwen-3-235b"]="Qwen 3 235B (largest open)"
MODEL_ROLES["qwen-3-235b"]="architect"
MODEL_PROVIDER["qwen-3-235b"]="cerebras"
MODEL_CAPABILITIES["qwen-3-235b"]="text,reasoning,coding"

FREE_MODELS["deepseek-chat"]="DeepSeek Chat"
MODEL_ROLES["deepseek-chat"]="analyst"
MODEL_PROVIDER["deepseek-chat"]="deepseek"
MODEL_CAPABILITIES["deepseek-chat"]="text,coding"

# --- Special / Multi-modal (image gen directly) ---
FREE_MODELS["flux-image"]="Flux Image Generator"
MODEL_ROLES["flux-image"]="image-gen"
MODEL_PROVIDER["flux-image"]="pollinations-image"
MODEL_CAPABILITIES["flux-image"]="image"

FREE_MODELS["pollinate-image"]="Pollinations Image (proxy wrapper)"
MODEL_ROLES["pollinate-image"]="artist"  
MODEL_PROVIDER["pollinate-image"]="pollinations-image"
MODEL_CAPABILITIES["pollinate-image"]="image"

# ============================================================================
# @MENTION ALIASES — Map short names to best models for role
# ============================================================================

declare -A MENTION_MAP=(
  ["@thinker"]="openai-large"       # Deep reasoning (OpenAI GPT Large)
  ["@coder"]="qwen-coder"           # Code generation (Qwen Coder)
  ["@researcher"]="gemini"          # Web research (Google Gemini)
  ["@critic"]="claude"              # Code review, safety (Claude)
  ["@architect"]="qwen-3-235b"     # System design (Qwen 3 235B)
  ["@analyst"]="mistral"            # Data analysis (Mistral)
  ["@artist"]="flux"                # Image generation (Flux)
  ["@speaker"]="elevenlabs"         # Text-to-speech (ElevenLabs)
  ["@fast"]="openai-fast"           # Quick responses
  ["@general"]="openai"             # General purpose
  ["@executor"]="openai-fast"       # Fast execution
  ["@writer"]="llama"               # Creative writing
  ["@explorer"]="perplexity"        # Research & discovery
  ["@debugger"]="deepseek"          # Debugging
)

# ============================================================================
# LIST AVAILABLE MODEL SUBAGENTS
# ============================================================================

subagent_list() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        AngelKernel Free Model Subagents                     ║"
    echo "║        ZERO API KEYS required — powered by Pollinations +   ║"
    echo "║        KiloProxy free tier fallback chain                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📋 @mentions (role-based routing):"
    echo "───────────────────────────────────────────────────"
    printf "  %-16s %-20s %-20s\n" "@mention" "→ Model" "Best For"
    echo "  $(printf '%*s' 58 | tr ' ' '─')"
    for mention in $(echo "${!MENTION_MAP[@]}" | tr ' ' '\n' | sort); do
        model="${MENTION_MAP[$mention]}"
        role="${MODEL_ROLES[$model]}"
        printf "  %-16s %-20s %-20s\n" "$mention" "$model" "$role"
    done
    echo ""
    echo "📋 All $($(declare -p FREE_MODELS) 2>/dev/null; echo ${#FREE_MODELS[@]}) Free Models:"
    echo "───────────────────────────────────────────────────"
    printf "  %-22s %-20s %-18s %s\n" "Model ID" "Provider" "Role" "Capabilities"
    echo "  $(printf '%*s' 78 | tr ' ' '─')"
    for model in $(echo "${!FREE_MODELS[@]}" | tr ' ' '\n' | sort); do
        provider="${MODEL_PROVIDER[$model]}"
        role="${MODEL_ROLES[$model]}"
        caps="${MODEL_CAPABILITIES[$model]}"
        printf "  %-22s %-20s %-18s %s\n" "$model" "$provider" "$role" "$caps"
    done
    echo ""
    echo "💡 Usage: angel-subagent @thinker \"query\" or angel-subagent <model_id> \"query\""
}

# ============================================================================
# RESOLVE MODEL FROM INPUT (handle @mentions, aliases, direct IDs)
# ============================================================================

resolve_model() {
    local input="$1"
    
    # Check @mention
    if [[ "$input" =~ ^@ ]]; then
        if [[ -n "${MENTION_MAP[$input]}" ]]; then
            echo "${MENTION_MAP[$input]}"
            return 0
        fi
        echo "error: Unknown @mention '$input'. Use 'angel-subagent list' to see available."
        return 1
    fi
    
    # Check direct model ID
    if [[ -n "${FREE_MODELS[$input]}" ]]; then
        echo "$input"
        return 0
    fi
    
    # Check partial match
    for model in "${!FREE_MODELS[@]}"; do
        if [[ "$model" == *"$input"* ]]; then
            echo "$model"
            return 0
        fi
    done
    
    # Check role match
    for model in "${!MODEL_ROLES[@]}"; do
        if [[ "${MODEL_ROLES[$model]}" == *"$input"* ]]; then
            echo "$model"
            return 0
        fi
    done
    
    echo "error: No model found for '$input'. Use 'angel-subagent list' to see available."
    return 1
}

# ============================================================================
# EQUIP SKILLS BASED ON TASK — Auto-discover and load relevant skills
# ============================================================================

equip_skills() {
    local task="$1"
    local model="$2"
    local skills_to_load=()
    
    angel_info "[subagent] Equipping skills for task: ${task:0:60}..."
    
    # Analyze task for domain keywords
    local domains=""
    domains=$(python3 -c "
import re
domains = {
    'game': ['game', 'godot', 'tcg', 'unity', 'unreal', 'rpg', 'card'],
    'web': ['web', 'website', 'app', 'frontend', 'backend', 'api', 'deploy', 'publish'],
    'image': ['image', 'photo', 'picture', 'art', 'illustration', 'logo', 'design', 'visual'],
    'audio': ['audio', 'sound', 'music', 'speech', 'tts', 'voice', 'podcast'],
    'video': ['video', 'animation', 'movie', 'clip', 'film'],
    'code': ['code', 'program', 'script', 'function', 'class', 'debug', 'refactor'],
    'research': ['research', 'search', 'find', 'learn', 'study', 'analyze'],
    'data': ['data', 'analysis', 'statistics', 'chart', 'graph', 'database'],
    'writing': ['write', 'content', 'article', 'blog', 'email', 'document'],
    'campaign': ['campaign', 'marketing', 'ad', 'promotion', 'brand', 'hivelaunch'],
    '3d': ['3d', 'model', 'asset', 'prompt-to-asset', 'logo'],
    'soundscape': ['sound', 'ambient', 'noise', 'focus', 'meditation', 'spatial-sound'],
    'narrative': ['story', 'narrative', 'adventure', 'rpg', 'cretaceous'],
    'learning': ['learn', 'knowledge', 'growth', 'mycelium', 'mentor', 'intellectual'],
}
task_lower = task.lower()
matched = []
for domain, keywords in domains.items():
    for kw in keywords:
        if kw in task_lower and domain not in matched:
            matched.append(domain)
            break
print(','.join(matched))
" 2>/dev/null)
    
    # Equip based on domains
    if echo "$domains" | grep -q "game"; then
        skills_to_load+=("godot-tcg-core" "godot-addon-manager")
    fi
    if echo "$domains" | grep -q "image"; then
        skills_to_load+=("imagegen" "pollinations-universal")
    fi
    if echo "$domains" | grep -q "audio"; then
        skills_to_load+=("pollinations-universal")
    fi
    if echo "$domains" | grep -q "research"; then
        skills_to_load+=("search-codex-chats" "openai-docs")
    fi
    if echo "$domains" | grep -q "web"; then
        skills_to_load+=("anyclaw-publish" "composio-cli")
    fi
    if echo "$domains" | grep -q "campaign"; then
        skills_to_load+=("pollinations-universal")
    fi
    if echo "$domains" | grep -q "3d"; then
        skills_to_load+=("imagegen")
    fi
    if echo "$domains" | grep -q "code"; then
        skills_to_load+=("godot-tcg-core" "composio-cli")
    fi
    if echo "$domains" | grep -q "narrative"; then
        skills_to_load+=("godot-tcg-core")
    fi
    if echo "$domains" | grep -q "learning"; then
        skills_to_load+=("search-codex-chats")
    fi
    
    # Return unique skills
    echo "${skills_to_load[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# ============================================================================
# BUILD SUBAGENT PROMPT — Creates model-specific system prompt with skills
# ============================================================================

build_subagent_prompt() {
    local model="$1"
    local task="$2"
    local role="${MODEL_ROLES[$model]:-generalist}"
    local caps="${MODEL_CAPABILITIES[$model]:-text}"
    local provider="${MODEL_PROVIDER[$model]:-pollinations}"
    local skills="$3"
    
    cat << PROMPT
You are a specialized AngelKernel subagent running model "${model}" (role: ${role}).
Provider: ${provider}
Capabilities: ${caps}

YOUR ROLE: ${role}
Equipped skills: ${skills}

CORE DIRECTIVES:
1. Use equipped skills — look up skill instructions before proceeding
2. RALPH loop: Reason → Act → Learn → Patch → Hook
3. If you need tools not in your capabilities, delegate to @general or call angel-chain
4. NO API KEYS — you are powered by free provider fallback chain
5. NO STUBS — implement, don't leave TODOs
6. Report results back to the orchestrator

TASK: ${task}
PROMPT
}

# ============================================================================
# CALL MODEL API — Routes through free provider chain
# ============================================================================

call_model() {
    local model="$1"
    local prompt="$2"
    local provider="${MODEL_PROVIDER[$model]:-pollinations}"
    
    case "$provider" in
        pollinations)
            # Text generation via Pollinations
            local response
            response=$(curl -s --max-time 60 "https://gen.pollinations.ai/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")}],\"stream\":false}" 2>/dev/null)
            
            if [ $? -ne 0 ] || [ -z "$response" ]; then
                # Fallback to text.pollinations.ai legacy endpoint
                response=$(curl -s --max-time 30 "https://text.pollinations.ai/$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$prompt'''))")" 2>/dev/null)
            fi
            
            echo "$response"
            ;;
            
        pollinations-image)
            # Image generation - returns URL
            local encoded
            encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$prompt'''))" 2>/dev/null)
            echo "https://image.pollinations.ai/prompt/$encoded"
            ;;
            
        *)
            # Route through proxy for other providers
            if [ -f "$ANGEL_HOME/bin/angel-proxy.sh" ]; then
                bash "$ANGEL_HOME/bin/angel-proxy.sh" call "$provider" \
                    "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}]}" 2>/dev/null
            else
                echo "error: No handler for provider '$provider'"
                return 1
            fi
            ;;
    esac
}

# ============================================================================
# EXECUTE SUBAGENT — Full lifecycle: equip → prompt → call → return
# ============================================================================

subagent_execute() {
    local mention_or_model="$1"
    shift
    local task="$*"
    local model="$mention_or_model"
    
    # Resolve model
    model=$(resolve_model "$model")
    if [[ "$model" == error:* ]]; then
        echo "$model" >&2
        return 1
    fi
    
    local start_time
    start_time=$(date +%s)
    
    # Equip skills
    local skills
    skills=$(equip_skills "$task" "$model")
    
    angel_info "[subagent:$model] Equipped skills: $skills"
    angel_console "decision" "subagent" "execute" "Routing: $mention_or_model" "model=$model skills=$skills"
    
    # Build prompt
    local system_prompt
    system_prompt=$(build_subagent_prompt "$model" "$task" "$skills")
    
    # Call model
    angel_info "[subagent:$model] Executing task..."
    angel_console "call" "subagent" "call_model" "Calling $model" "provider=${MODEL_PROVIDER[$model]}"
    
    local _start_ts
    _start_ts=$(date +%s%3N 2>/dev/null || date +%s)
    local result
    result=$(call_model "$model" "$system_prompt" 2>/dev/null)
    local status=$?
    local _end_ts _duration
    _end_ts=$(date +%s%3N 2>/dev/null || date +%s)
    _duration=$(( _end_ts - _start_ts ))
    
    # Log
    local duration=$(( $(date +%s) - start_time ))
    echo "$(date -Iseconds)|$model|${task:0:80}|$status|${duration}s" >> "$SUBAGENT_LOG"
    
    # Return result
    if [ $status -eq 0 ] && [ -n "$result" ]; then
        angel_console "ok" "subagent" "execute" "Response from $model" "duration=${_duration}ms result_len=${#result}"
        echo "$result"
        return 0
    else
        angel_warn "[subagent:$model] Execution failed, trying fallback..."
        angel_console "error" "subagent" "execute" "$model failed, fallback to @general" "duration=${_duration}ms status=$status"
        # Fallback to @general 
        angel-subagent @general "$task" 2>/dev/null
    fi
}

# ============================================================================
# AUTO-SELECT — Choose best subagent for task
# ============================================================================

subagent_auto() {
    local task="$*"
    
    # Analyze task for role matching
    local role
    role=$(python3 -c "
import sys
task = '''$task'''.lower()
roles = {
    'thinker': ['why', 'reason', 'complex', 'deep', 'analysis', 'philosophy'],
    'coder': ['code', 'program', 'implement', 'function', 'debug', 'api', 'script'],
    'researcher': ['search', 'find', 'research', 'what is', 'how to', 'learn'],
    'critic': ['review', 'check', 'verify', 'validate', 'test', 'quality'],
    'architect': ['design', 'architecture', 'system', 'plan', 'structure', 'blueprint'],
    'artist': ['image', 'picture', 'design', 'visual', 'logo', 'art', 'draw'],
    'speaker': ['audio', 'speech', 'voice', 'say', 'tell', 'read aloud'],
}
for role, keywords in roles.items():
    for kw in keywords:
        if kw in task:
            print(role)
            sys.exit(0)
print('general')
" 2>/dev/null)
    
    # Map role to @mention
    case "$role" in
        thinker) mention="@thinker" ;;
        coder) mention="@coder" ;;
        researcher) mention="@researcher" ;;
        critic) mention="@critic" ;;
        architect) mention="@architect" ;;
        artist) mention="@artist" ;;
        speaker) mention="@speaker" ;;
        *) mention="@general" ;;
    esac
    
    angel_info "[subagent] Auto-selected: $mention for task"
    subagent_execute "$mention" "$task"
}

# ============================================================================
# MAIN DISPATCH
# ============================================================================

case "${1:-}" in
    list|--list|-l)
        subagent_list ;;
    auto|--auto|-a)
        shift; subagent_auto "$@" ;;
    execute|exec|-e)
        shift; subagent_execute "$@" ;;
    resolve|--resolve)
        shift; resolve_model "$1" ;;
    *)
        # Default: first arg is model/mention, rest is task
        if [[ "$1" =~ ^@ ]] || [[ -n "${FREE_MODELS[$1]}" ]]; then
            subagent_execute "$@"
        else
            echo "AngelKernel Subagent System v2 — Free Model Multi-Agent"
            echo ""
            echo "Usage:"
            echo "  angel-subagent list                          — List all free model subagents"
            echo "  angel-subagent @thinker \"query\"              — Route by @mention role"
            echo "  angel-subagent openai-large \"query\"          — Direct model ID"
            echo "  angel-subagent auto \"complex task\"            — Auto-select best subagent"
            echo "  angel-subagent execute <model> \"task\"         — Explicit execute"
            echo ""
            echo "Examples:"
            echo "  angel-subagent @coder \"Write a Python function\""
            echo "  angel-subagent @artist \"A cyberpunk city\""
            echo "  angel-subagent @researcher \"Latest AI news\""
            echo "  angel-subagent auto \"Build a web app with database\""
            echo ""
            echo "All models are FREE. No API keys needed."
            echo "Powered by Pollinations AI + KiloProxy fallback chain."
            echo ""
            echo "Available models: ${#FREE_MODELS[@]}"
            echo "Run 'angel-subagent list' for full list."
        fi
        ;;
esac
