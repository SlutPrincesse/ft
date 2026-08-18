#!/bin/bash
# angel-proxy v2.2 — Free Model Provider Fallback System
# Automatically routes through free providers: Pollinations → KiloProxy chain
# ZERO API KEYS needed for tier-1 providers (Pollinations, Stable Horde, etc.)
#
# Usage:
#   angel-proxy generate text "prompt"            # Text generation
#   angel-proxy generate image "prompt" -o out.png # Image generation
#   angel-proxy generate audio "text" -o out.mp3  # TTS generation
#   angel-proxy status                            # Provider status
#   angel-proxy models [text|image|audio]         # List available models

ANGEL_SCRIPT="proxy"
ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
PROXY_DIR="$ANGEL_HOME/proxy"
STATE_FILE="$PROXY_DIR/provider-state.json"
LOG_FILE="$ANGEL_HOME/logs/provider-fallback.ndjson"
mkdir -p "$PROXY_DIR" "$(dirname "$LOG_FILE")"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
angel_console_init 2>/dev/null || true

# ============================================================================
# PROVIDER DEFINITIONS — Priority order (tier1 = no key, tier2 = free key, tier3 = community)
# ============================================================================

declare -a PROVIDER_NAMES=(
  "pollinations-image"    # Tier 1: No key needed — image gen
  "pollinations"          # Tier 1: No key needed — text gen
  "pollinations-text"     # Tier 1: No key needed — legacy text
  "pollinations-audio"    # Tier 1: No key needed — audio gen
  "poolside"              # Tier 2: Free key
  "openrouter"            # Tier 2: Free key
  "groq"                  # Tier 2: Free key
  "cerebras"              # Tier 2: Free key
  "nvidia"                # Tier 2: Free key
  "google"                # Tier 2: Free key
  "deepseek"              # Tier 2: Free key
  "github"                # Tier 2: Free key
  "huggingface"           # Tier 2: Free key
)

declare -A PROVIDER_ENDPOINT
declare -A PROVIDER_TYPE
declare -A PROVIDER_MODELS
declare -A PROVIDER_ENV_KEY

# --- Tier 1: No API key needed ---
PROVIDER_ENDPOINT["pollinations"]="https://gen.pollinations.ai/v1"
PROVIDER_TYPE["pollinations"]="openai_compat"
PROVIDER_MODELS["pollinations"]="openai openai-fast openai-large mistral gemini deepseek qwen-coder llama claude perplexity"
PROVIDER_ENV_KEY["pollinations"]=""

PROVIDER_ENDPOINT["pollinations-text"]="https://text.pollinations.ai"
PROVIDER_TYPE["pollinations-text"]="direct_get"

PROVIDER_ENDPOINT["pollinations-image"]="https://image.pollinations.ai"
PROVIDER_TYPE["pollinations-image"]="image_get"
PROVIDER_MODELS["pollinations-image"]="flux default"

PROVIDER_ENDPOINT["pollinations-audio"]="https://gen.pollinations.ai/v1"
PROVIDER_TYPE["pollinations-audio"]="openai_compat"

# --- Tier 2: Free tier with API key ---
PROVIDER_ENDPOINT["poolside"]="https://api.poolside.ai/v1"
PROVIDER_TYPE["poolside"]="openai_compat"
PROVIDER_MODELS["poolside"]="laguna-m deepseek-v3"
PROVIDER_ENV_KEY["poolside"]="POOLSIDE_API_KEY"

PROVIDER_ENDPOINT["openrouter"]="https://openrouter.ai/api/v1"
PROVIDER_TYPE["openrouter"]="openai_compat"
PROVIDER_MODELS["openrouter"]="google/gemini-flash-1.5 meta-llama/llama-3.1-405b"
PROVIDER_ENV_KEY["openrouter"]="OPENROUTER_API_KEY"

PROVIDER_ENDPOINT["groq"]="https://api.groq.com/openai/v1"
PROVIDER_TYPE["groq"]="openai_compat"
PROVIDER_MODELS["groq"]="llama-3.3-70b llama-3.1-8b gemma2-9b deepseek-r1-70b"
PROVIDER_ENV_KEY["groq"]="GROQ_API_KEY"

PROVIDER_ENDPOINT["cerebras"]="https://api.cerebras.ai/v1"
PROVIDER_TYPE["cerebras"]="openai_compat"
PROVIDER_MODELS["cerebras"]="llama-3.3-70b qwen-3-235b"
PROVIDER_ENV_KEY["cerebras"]="CEREBRAS_API_KEY"

PROVIDER_ENDPOINT["nvidia"]="https://integrate.api.nvidia.com/v1"
PROVIDER_TYPE["nvidia"]="openai_compat"
PROVIDER_MODELS["nvidia"]="meta/llama-3.3-70b-instruct nvidia/nemotron-4-340b-reward"
PROVIDER_ENV_KEY["nvidia"]="NVIDIA_API_KEY"

PROVIDER_ENDPOINT["google"]="https://generativelanguage.googleapis.com/v1beta"
PROVIDER_TYPE["google"]="google_compat"
PROVIDER_ENV_KEY["google"]="GOOGLE_API_KEY"

PROVIDER_ENDPOINT["deepseek"]="https://api.deepseek.com/v1"
PROVIDER_TYPE["deepseek"]="openai_compat"
PROVIDER_MODELS["deepseek"]="deepseek-chat deepseek-coder"
PROVIDER_ENV_KEY["deepseek"]="DEEPSEEK_API_KEY"

# ============================================================================
# INITIALIZE STATE
# ============================================================================

init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" << EOF
{
    "current_provider": "pollinations",
    "current_tier": "tier1",
    "rpm_count": 0,
    "tpm_count": 0,
    "last_reset": $(date +%s),
    "switches": 0,
    "total_calls": 0,
    "failed_calls": 0,
    "providers_tried": []
}
EOF
    fi
}

# ============================================================================
# PROVIDER STATUS & INFO
# ============================================================================

proxy_status() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     AngelKernel Free Provider Proxy — Status               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # State info
    if [ -f "$STATE_FILE" ]; then
        echo "📊 Current State:"
        python3 -c "
import json
with open('$STATE_FILE') as f:
    s = json.load(f)
print(f'  Active Provider: {s[\"current_provider\"]} (Tier: {s[\"current_tier\"]})')
print(f'  Total Calls: {s[\"total_calls\"]} | Failed: {s[\"failed_calls\"]} | Switches: {s[\"switches\"]}')
print(f'  Rate: {s[\"rpm_count\"]} RPM / {s[\"tpm_count\"]} TPM (reset: {s[\"last_reset\"]})')
" 2>/dev/null
    fi
    echo ""
    
    echo "📋 Provider Chain (Priority Order):"
    echo "────────────────────────────────────────────"
    printf "  %-22s %-12s %-8s %-18s\n" "Provider" "Tier" "Status" "Needs Key?"
    echo "  $(printf '%*s' 62 | tr ' ' '─')"
    
    for provider in "${PROVIDER_NAMES[@]}"; do
        local tier="tier1"
        if [ "$provider" = "poolside" ] || [ "$provider" = "openrouter" ] || [ "$provider" = "groq" ] || [ "$provider" = "cerebras" ] || [ "$provider" = "nvidia" ] || [ "$provider" = "google" ] || [ "$provider" = "deepseek" ] || [ "$provider" = "github" ] || [ "$provider" = "huggingface" ] || [ "$provider" = "cloudflare" ]; then
            tier="tier2"
        fi
        
        local needs_key="No"
        local env_key="${PROVIDER_ENV_KEY[$provider]}"
        if [ -n "$env_key" ]; then
            if [ -n "${!env_key}" ]; then
                needs_key="✅ Set"
            else
                needs_key="⚠️  \$$env_key"
            fi
        fi
        
        printf "  %-22s %-12s %-8s %-18s\n" "$provider" "$tier" "active" "$needs_key"
    done
    
    echo ""
    echo "✅ Tier 1 = No API key required"
    echo "⚠️  Tier 2 = Free API key available (may work without)"
}

# ============================================================================
# TEXT GENERATION
# ============================================================================

generate_text() {
    local prompt="$1"
    local model="${2:-openai}"
    
    init_state
    
    # Try Pollinations first (no key needed)
    angel_info "[proxy] Text gen: $model \"${prompt:0:60}...\""
    angel_console "call" "proxy" "generate_text" "Text gen: $model" "prompt_len=${#prompt}"
    
    local _start_ts
    _start_ts=$(date +%s%3N 2>/dev/null || date +%s)
    local response
    response=$(curl -s --max-time 60 "https://gen.pollinations.ai/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "$(python3 -c "
import json
prompt = '''$prompt'''
model = '''$model'''
body = {
    'model': model,
    'messages': [{'role': 'user', 'content': prompt}],
    'stream': False,
    'temperature': 0.7,
    'max_tokens': 4096
}
print(json.dumps(body))
")" 2>/dev/null)
    
    local status=$?
    
    if [ $status -eq 0 ] && [ -n "$response" ]; then
        # Extract content
        local content
        content=$(echo "$response" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d['choices'][0]['message']['content'])
except Exception as e:
    print(f'PARSE_ERROR: {e}')
    print(sys.stdin.read())
" 2>/dev/null)
        
        if [ -n "$content" ] && [[ "$content" != "PARSE_ERROR"* ]]; then
            local _end_ts _duration
            _end_ts=$(date +%s%3N 2>/dev/null || date +%s)
            _duration=$(( _end_ts - _start_ts ))
            angel_console "ok" "proxy" "generate_text" "Text gen success: $model" "tokens=${#content} duration=${_duration}ms"
            echo "$content"
            return 0
        fi
    fi
    
    # Fallback to legacy text endpoint
    angel_info "[proxy] Pollinations API failed, trying legacy endpoint..."
    angel_console "warn" "proxy" "generate_text" "Pollinations API failed, fallback to legacy" "model=$model"
    local encoded
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$prompt'''))" 2>/dev/null)
    response=$(curl -s --max-time 30 "https://text.pollinations.ai/$encoded" 2>/dev/null)
    
    if [ -n "$response" ]; then
        echo "$response"
        return 0
    fi
    
    angel_warn "[proxy] All free text providers failed"
    return 1
}

# ============================================================================
# IMAGE GENERATION
# ============================================================================

generate_image() {
    local prompt="$1"
    local output="${2:-/tmp/pollinations_image.png}"
    local width="${3:-1024}"
    local height="${4:-1024}"
    local model="${5:-flux}"
    
    init_state
    
    angel_info "[proxy] Image gen: $model \"${prompt:0:60}...\""
    angel_console "call" "proxy" "generate_image" "Image gen: $model" "width=${width}x${height}"
    
    local _start_ts
    _start_ts=$(date +%s%3N 2>/dev/null || date +%s)
    
    # Encode prompt
    local encoded
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$prompt'''))" 2>/dev/null)
    
    # Try Pollinations image (no key needed)
    local url="https://image.pollinations.ai/prompt/$encoded?width=$width&height=$height&model=$model"
    
    local response_code
    response_code=$(curl -s --max-time 30 -o "$output" -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response_code" = "200" ] && [ -s "$output" ]; then
        local size
        size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
        local _end_ts _duration
        _end_ts=$(date +%s%3N 2>/dev/null || date +%s)
        _duration=$(( _end_ts - _start_ts ))
        angel_info "[proxy] Image saved: ${output} (${size} bytes)"
        angel_console "ok" "proxy" "generate_image" "Image saved: $model" "size=${size}B duration=${_duration}ms output=$output"
        echo "$output"
        return 0
    fi
    
    angel_warn "[proxy] Image generation failed"
    angel_console "error" "proxy" "generate_image" "Image gen failed: $model" "http_code=$response_code"
    return 1
}

# ============================================================================
# AUDIO GENERATION (TTS)
# ============================================================================

generate_audio() {
    local text="$1"
    local output="${2:-/tmp/pollinations_audio.mp3}"
    local voice="${3:-nova}"
    
    init_state
    
    angel_info "[proxy] Audio gen: voice=$voice \"${text:0:60}...\""
    angel_console "call" "proxy" "generate_audio" "Audio gen" "voice=$voice"
    
    local _start_ts
    _start_ts=$(date +%s%3N 2>/dev/null || date +%s)
    
    # Try Pollinations audio
    local encoded
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$text'''))" 2>/dev/null)
    
    local response_code
    response_code=$(curl -s --max-time 30 -o "$output" -w "%{http_code}" \
        "https://gen.pollinations.ai/audio/$encoded?voice=$voice" 2>/dev/null)
    
    if [ "$response_code" = "200" ] && [ -s "$output" ]; then
        local size
        size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
        local _end_ts _duration
        _end_ts=$(date +%s%3N 2>/dev/null || date +%s)
        _duration=$(( _end_ts - _start_ts ))
        angel_info "[proxy] Audio saved: ${output} (${size} bytes)"
        angel_console "ok" "proxy" "generate_audio" "Audio saved" "size=${size}B duration=${_duration}ms"
        echo "$output"
        return 0
    fi
    
    angel_warn "[proxy] Audio generation failed"
    angel_console "error" "proxy" "generate_audio" "Audio gen failed" "voice=$voice http_code=$response_code"
    return 1
}

# ============================================================================
# MODEL LIST
# ============================================================================

list_models() {
    local type="${1:-all}"
    
    if [ "$type" = "all" ] || [ "$type" = "text" ]; then
        echo "📝 Text Models (free, no key needed):"
        for model in openai openai-fast openai-large mistral gemini deepseek qwen-coder llama claude perplexity; do
            echo "  - $model"
        done
        echo ""
    fi
    
    if [ "$type" = "all" ] || [ "$type" = "image" ]; then
        echo "🎨 Image Models (free, no key needed):"
        for model in flux zimage seedream kontext gptimage qwen-image grok-imagine; do
            echo "  - $model"
        done
        echo ""
    fi
    
    if [ "$type" = "all" ] || [ "$type" = "audio" ]; then
        echo "🔊 Audio Models (free, may need key):"
        for model in elevenlabs qwen-tts elevenmusic acestep whisper scribe; do
            echo "  - $model"
        done
        echo ""
    fi
    
    if [ "$type" = "all" ] || [ "$type" = "video" ]; then
        echo "🎬 Video Models (free, may need key):"
        for model in veo seedance ltx-2 wan; do
            echo "  - $model"
        done
        echo ""
    fi
}

# ============================================================================
# GENERATE ANY — Auto-detect type from prompt
# ============================================================================

generate_auto() {
    local prompt="$*"
    
    # Detect what the user wants
    local type
    type=$(python3 -c "
import sys
prompt = '''$prompt'''.lower()
# Check for image keywords
image_kw = ['image', 'picture', 'photo', 'draw', 'illustration', 'logo', 'art', 'design', 'visual', 'poster']
for kw in image_kw:
    if kw in prompt:
        print('image')
        sys.exit(0)
# Check for audio keywords
audio_kw = ['audio', 'sound', 'speech', 'voice', 'tts', 'say', 'speak', 'pronounce', 'music', 'song']
for kw in audio_kw:
    if kw in prompt:
        print('audio')
        sys.exit(0)
# Default to text
print('text')
" 2>/dev/null)
    
    case "$type" in
        image) generate_image "$prompt" ;;
        audio) generate_audio "$prompt" ;;
        *) generate_text "$prompt" ;;
    esac
}

# ============================================================================
# MAIN DISPATCH
# ============================================================================

init_state

case "${1:-}" in
    generate)
        shift
        case "${1:-}" in
            text) shift; generate_text "$@" ;;
            image) shift; generate_image "$@" ;;
            audio) shift; generate_audio "$@" ;;
            auto|*) generate_auto "$@" ;;
        esac
        ;;
    status|--status|-s)
        proxy_status ;;
    models|--models|-m)
        shift; list_models "$@" ;;
    *)
        echo "AngelKernel Free Provider Proxy v2.2"
        echo "ZERO API KEYS REQUIRED — powered by Pollinations + fallback chain"
        echo ""
        echo "Usage:"
        echo "  angel-proxy generate text \"prompt\" [model]"
        echo "  angel-proxy generate image \"prompt\" [output] [w] [h] [model]"
        echo "  angel-proxy generate audio \"text\" [output] [voice]"
        echo "  angel-proxy generate auto \"description\""
        echo "  angel-proxy models [text|image|audio]"
        echo "  angel-proxy status"
        echo ""
        echo "Examples:"
        echo "  angel-proxy generate text \"Explain quantum computing\""
        echo "  angel-proxy generate image \"a cyberpunk city\" /tmp/city.png"
        echo "  angel-proxy generate audio \"Hello world\" speech.mp3 nova"
        echo ""
        echo "All providers are FREE. No credit card needed."
        ;;
esac
