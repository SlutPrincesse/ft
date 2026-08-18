# Universal CLI Skills

Self-contained, agent-agnostic wrappers for two foundational skills: **skill-creator** and **plugin-creator**. These skills were originally built for a single coding CLI agent; this project adapts them so they work across Codex, Claude Code, Kilo, Aider, OpenCode, Cursor, Gemini CLI, OpenClaw, and similar tools.

## What's Included

| Skill | Purpose |
|-------|---------|
| `skills/skill-creator/` | Guide for creating new skills with proper structure, frontmatter, bundled resources, and validation. |
| `skills/plugin-creator/` | Scaffold plugin directories with `.codex-plugin/plugin.json`, marketplace entries, cachebuster updates, and validation. |
| `skills/intake/` | Modern-project intake wizard (`intake.py`) — 4-phase questionnaire → `AGENTS.md` + dependency installer. |

Both skills are fully self-contained: all scripts, references, assets, and agent metadata are copied into this repo so it works without external dependencies.

## Modern Project Intake Wizard

`scripts/intake.py` drives a 4-phase intake flow (from
`modern-project-intake-questions.md`) and produces a structured `intake.yaml`,
a starter `AGENTS.md`, a **tiered dependency install plan**, and — via optional
research + enrichment — a `project-plan.md` and a specialized `agent-profile.md`.
It also bundles `scripts/model_layer.py`, an NVIDIA NIM client with RPM limiting,
multi-key rotation, and fallback.

```bash
# Full run: research auto-runs online (cached), then plan + profile
python3 scripts/intake.py --project my-saas --out ./intake --plan

# Offline-only: reuse cached research, never call web search
python3 scripts/intake.py --project my-saas --out ./intake --offline --plan

# Defaults-only (CI / scaffolding)
python3 scripts/intake.py --project my-saas --out ./intake --non-interactive

# Refine the plan with one NIM model call (keys in .env.local)
python3 scripts/intake.py --project my-saas --ai-plan

# Print the full question catalog
python3 scripts/intake.py --list
```

Outputs written to `--out`:
- `<project>.intake.yaml` — answers (API keys masked)
- `<project>.intake.md` — human summary
- `AGENTS.md` — project instruction file (sync to CLAUDE.md / `.kilo` / etc.)
- `<project>.research.json` — cached research (frameworks, skills, MCP, LSP, KBs)
- `<project>.deps-plan.md` — **tiered** install plan
- `<project>.deps.sh` — installer (auto steps run; manual steps printed)
- `<project>.project-plan.md` — offline-enriched dev plan
- `<project>.agent-profile.md` — skill favorites + MCP/LSP awareness + NIM config
- `.env.local` / `.gitignore` — API keys only, git-ignored

### Dependency install

`intake.py` maps your answered stack choices to concrete install commands, ordered
into 8 tiers (runtime → pkg mgr → lint/test → frameworks → data/services →
observability → infra → AI). It auto-runs only safe, non-privileged steps (e.g.
`npm install -g lefthook`) and emits `apt`/`brew`/`docker`/`pip`/sign-up steps as
**manual** so the run never hangs or breaks the system.

```bash
# Tiered plan + script
python3 scripts/intake.py --project my-saas --deps

# Preview mapped install commands (no execution)
python3 scripts/intake.py --project my-saas --deps-dry-run

# Emit + run safe auto-install steps; others printed as manual
python3 scripts/intake.py --project my-saas --install-deps
```

### NVIDIA NIM model layer

`scripts/model_layer.py` is an OpenAI-compatible NIM client (default
`https://integrate.api.nvidia.com/v1`) with per-key RPM limiting, key rotation on
`429`/quota, and a fallback model when all primary keys are exhausted.

```bash
python3 scripts/model_layer.py --prompt "..." --keys-file .env.local
```

### Live research (bridge JSON)

`websearch` is an agent tool, not an importable module, so `intake.py` cannot call
it directly. For **real** (not curated) findings, run web searches at the host
level, save results to a JSON bridge, and pass it in:

```bash
python3 scripts/intake.py --project my-saas --out ./intake --plan \
  --research-json research-bridge.sample.json
```

A ready example from live 2026 research (React 19 / Next.js 16 SaaS) is included
at `research-bridge.sample.json`. Without a bridge, research uses a curated
fallback and is cached to `<project>.research.json` for offline reuse.

See `modern-project-intake-questions.md` for the full categorized question set and
the recommended intake flow (Discovery → Architecture → Setup → Iterate).

## Install

Run the installer to copy or symlink skills into supported agent directories:

```bash
# Install into all detected agents
./install.sh --agent all

# Install into a specific agent
./install.sh --agent codex
./install.sh --agent claude
./install.sh --agent kilo
./install.sh --agent openclaw

# Dry run (preview without changes)
./install.sh --dry-run --agent all
```

The installer symlinks the three skills (`skill-creator`, `plugin-creator`,
`intake`) into each agent's skills directory, auto-creating any missing directory
and skipping skills that are already installed (idempotent). Use `--copy` to copy
instead of symlink, and `--dry-run` to preview.

### OpenClaw

OpenClaw consumes the toolkit as a plugin. The dedicated installer symlinks the
skills into OpenClaw's skills dir (`~/.openclaw/skills`, normally a symlink to
`~/.shared-skills`), places the packaged plugin under
`~/.openclaw/plugins/universal-cli-skills`, and enables it:

```bash
# Register the toolkit as an OpenClaw plugin (default manifest kind: skill)
bash scripts/install-openclaw.sh

# Use the "tool" manifest variant instead of "skill"
bash scripts/install-openclaw.sh --kind tool

# Or via the main installer
./install.sh --agent openclaw

# Then tell OpenClaw to use it (CLI; falls back to editing openclaw.json)
openclaw plugins enable universal-cli-skills

# Verify
openclaw plugins list
openclaw skills list
```

> Note: `openclaw plugins enable` writes `plugins.entries.universal-cli-skills.enabled=true`
> into `~/.openclaw/openclaw.json`. If the CLI is unavailable or hangs (e.g. the
> gateway starts), `install-openclaw.sh` performs that config edit directly as a
> safe fallback. OpenClaw requires Node >= 22.22.3 (not 22.16), >= 24.15, or >= 25.9.
>
> **Gateway startup limitation:** OpenClaw's gateway/daemon calls
> `os.networkInterfaces()` during `initSelfPresence` to pick the primary LAN IP.
> In sandboxed environments where that syscall returns `EACCES` ("Unknown system
> error 13"), the gateway cannot start. The CLI (`--version`, `config`, `plugins`)
> still works. If the gateway won't start, run OpenClaw in a less-restricted
> environment.

## Compatibility Matrix

| Agent | Skills Directory | Supported | Notes |
|-------|------------------|-----------|-------|
| Codex | `~/.codex/skills` | Yes | Auto-discovered when `CODEX_HOME` is unset |
| Claude Code | `~/.claude/skills` | Yes | Primary skills directory |
| Kilo | `~/.config/kilo/skills` or `~/.claude/skills` | Yes | Kilo loads skills from shared directories |
| Aider | `~/.aider/skills` or project `.aider/skills/` | Partial | Aider skill discovery varies by version |
| OpenCode | `~/.opencode/skills` | Yes | Standard config directory |
| Cursor | `~/.cursor/skills` or project `.cursor/` | Partial | Cursor supports project-local skills |
| Gemini CLI | `~/.gemini/skills` | Partial | Depends on CLI version and config layout |
| OpenClaw | `~/.openclaw/skills` + `~/.openclaw/plugins/` | Yes | Symlinked skills + plugin manifest; enabled via `openclaw plugins enable` or config edit |

## Project Structure

```
universal-cli-skills/
├── README.md
├── AGENTS.md
├── install.sh
├── modern-project-intake-questions.md
├── scripts/
│   ├── intake.py
│   ├── model_layer.py
│   └── install-openclaw.sh
├── skills/
│   ├── skill-creator/
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   ├── references/
│   │   ├── agents/
│   │   └── assets/
│   └── plugin-creator/
│       ├── SKILL.md
│       ├── scripts/
│       ├── references/
│       ├── agents/
│       └── assets/
```

## Assumptions

- Coding CLI agents consume skills as folders containing `SKILL.md` plus optional `scripts/`, `references/`, `assets/`, and `agents/` subdirectories.
- The `.codex-plugin/plugin.json` manifest format is preserved as a stable plugin contract that other agents may adopt or wrap.
- `~/.agents/plugins/marketplace.json` is treated as a generic personal marketplace path; agent-specific marketplace commands are documented per-agent.
- All scripts require Python 3 and the `pyyaml` package (`pip install pyyaml`).

## Validation

After copying, validate the adapted `skill-creator` skill:

```bash
python3 skills/skill-creator/scripts/quick_validate.py skills/skill-creator
```

Validate any generated plugin:

```bash
python3 skills/plugin-creator/scripts/validate_plugin.py <plugin-path>
```
