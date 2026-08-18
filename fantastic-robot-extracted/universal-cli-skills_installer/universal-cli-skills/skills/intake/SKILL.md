---
name: intake
description: Modern-project intake wizard. Use when starting a new or modernized software project and you need to capture product, architecture, infra, security, DX, data/AI, team, cost, and modernization decisions as structured AGENTS.md + dependency-install steps. Triggers on "intake", "new project questions", "project setup questionnaire", or "scaffold decisions".
---

# Modern Project Intake

## Overview

Interactive 4-phase intake wizard that turns project decisions into a structured
`intake.yaml`, a human summary, a starter `AGENTS.md` (source of truth for any
coding CLI agent), and a `<project>.deps.sh` dependency installer.

## Usage

Run the wizard from this skill's `scripts/` directory:

```bash
# Interactive walkthrough of all 4 phases (research auto-runs online, cached)
python3 scripts/intake.py --project my-saas --out ./intake

# Generate the tiered dependency plan + project plan + agent profile
python3 scripts/intake.py --project my-saas --out ./intake --plan

# Offline-only: reuse cached research, never call web search
python3 scripts/intake.py --project my-saas --out ./intake --offline --plan

# Single phase
python3 scripts/intake.py --phase discovery --project my-saas

# Defaults-only (CI / scaffolding)
python3 scripts/intake.py --project my-saas --out ./intake --non-interactive

# Tiered dependency planning
python3 scripts/intake.py --project my-saas --deps            # plan + script
python3 scripts/intake.py --project my-saas --install-deps    # safe auto-install
python3 scripts/intake.py --project my-saas --deps-dry-run   # preview only

# Refine the plan with one NVIDIA NIM model call (needs keys in .env.local)
python3 scripts/intake.py --project my-saas --ai-plan

# Print the full question catalog
python3 scripts/intake.py --list
```

The model layer lives in `scripts/model_layer.py` (NIM client with RPM limiting,
multi-key rotation, fallback model):

```bash
python3 scripts/model_layer.py --prompt "..." --keys-file .env.local
```

## Live research via bridge JSON

`websearch` is an agent tool, not an importable module, so `intake.py` cannot call
it directly. For **real** (not curated) research findings, run web searches at the
host/agent level, save the results to a JSON file, and pass it as a bridge:

```bash
# Auto-discovered if named <project>.research-input.json in --out
python3 scripts/intake.py --project my-saas --out ./intake --plan

# Or explicit path
python3 scripts/intake.py --project my-saas --out ./intake --plan \
  --research-json ./intake/my-findings.json
```

Bridge JSON shape (any subset; merged over curated fallback, lists extend+dedupe):

```json
{
  "frameworks": {"React 19": "top skills: react-query, zod, tanstack..."},
  "top_skills_for_framework": ["react-query", "zod"],
  "top_mcp_server": ["mcp-server-react"],
  "lsp_servers": ["typescript-language-server"],
  "knowledge_bases": ["https://react.dev", "https://tanstack.com"]
}
```

Without a bridge, research uses a curated fallback and is cached to
`<project>.research.json` for offline reuse (still no live web calls).

## Phases

1. **Discovery** — problem, users, MVP, NFRs, greenfield vs modernization audit, **best-outcome (90-day)**
2. **Architecture** — languages, frameworks, datastores, caching, search, queues, **AI provider (NVIDIA NIM default), API keys, model selection, NIM base URL**, auth, compliance
3. **Setup** — cloud, IaC, CI/CD, containers, observability, secrets, package manager, lint/test, agent setup
4. **Iterate** — branching, review, tracking, on-call, ownership, budget, scaling, SLOs

## Outputs

- `<project>.intake.yaml` — machine-readable answers (API keys masked)
- `<project>.intake.md` — human summary
- `AGENTS.md` — project instruction file (sync to CLAUDE.md / `.kilo` / etc.)
- `<project>.research.json` — cached web research (frameworks, skills, MCP, LSP, KBs)
- `<project>.deps-plan.md` — **tiered** install plan (runtime → pkg → lint → frameworks → data → observability → infra → AI)
- `<project>.deps.sh` — installer for the chosen toolchain (auto steps run; manual steps printed)
- `<project>.project-plan.md` — offline-enriched initial dev plan
- `<project>.agent-profile.md` — specialized agent profile (skill favorites w/ auto-equip, MCP + LSP awareness, NIM model config)
- `.env.local` — API keys only (git-ignored); `.gitignore` generated

Dependency install is **plan-first / safe-auto**: `npm` globals run automatically;
`apt`/`brew`/`docker`/`pip`/sign-up steps are emitted as manual so the run never
hangs. Research runs automatically once and is cached for offline reuse, keeping
per-session AI calls minimal.

See `modern-project-intake-questions.md` in the parent project for the full
categorized question set and the recommended intake flow.
