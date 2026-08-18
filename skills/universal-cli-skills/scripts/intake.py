#!/usr/bin/env python3
"""Intake wizard for modernized software projects (2026).

Drives the 4-phase intake flow defined in
``modern-project-intake-questions.md`` and produces a structured
``intake.yaml`` plus a starter ``AGENTS.md`` and a markdown summary.

Usage:
    python3 scripts/intake.py                 # interactive, all phases
    python3 scripts/intake.py --phase discovery
    python3 scripts/intake.py --project my-saas --out ./intake
    python3 scripts/intake.py --non-interactive   # defaults only, for CI/scaffold
    python3 scripts/intake.py --list               # print the question catalog

The wizard is agent-agnostic: it only emits data files that any coding
CLI agent (Codex, Claude Code, Kilo, Aider, ...) can read.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Question catalog
# ---------------------------------------------------------------------------
# Each question: (id, prompt, options_or_None, default, help)
# A section maps to a phase so the intake flow is ordered.

SECTIONS = {
    "discovery": "Phase 1 - Discovery (Product, Requirements & Modernization audit)",
    "architecture": "Phase 2 - Architecture (Tech Stack, Data & AI, Security framing)",
    "setup": "Phase 3 - Setup (Infrastructure/DevOps & Developer Experience)",
    "iterate": "Phase 4 - Iterate (Team/Process, Cost/Scaling & continuous modernization)",
}

# section -> list of (id, prompt, [options]|None, default, help)
CATALOG: dict[str, list[tuple]] = {
    "discovery": [
        ("problem", "What is the core problem and success metric?", None, "",
         "North-star metric, e.g. activation rate, revenue, p95 latency."),
        ("users", "Who are the users and what platforms/devices?", None, "",
         "Web, mobile, desktop, API-only, kiosk/IoT."),
        ("mvp", "Must-have (MVP) vs nice-to-have features?", None, "",
         "Use MoSCoW prioritization."),
        ("nfrs", "Non-functional requirements (NFRs)?", None, "",
         "Latency, uptime, concurrency, WCAG 2.2 accessibility."),
        ("timeline", "Expected timeline and team size?", None, "",
         "1 dev / small team / scale-up / enterprise."),
        ("mode", "Greenfield or modernization?", ["greenfield", "strangler", "rewrite"], "greenfield",
         "Determines risk profile and migration strategy."),
        ("audit_state", "Current codebase state (if modernization)?", None, "",
         "Audit: languages, deps, tests, tech debt."),
        ("risk_modules", "Highest-risk modules to extract first?", None, "",
         "Profiling, churn, failure history."),
        ("parity", "Behavioral parity verification approach?", None, "",
         "Golden tests, shadow traffic, dual-write."),
        ("best_outcomes", "What does 'best outcome' look like in 90 days?", None, "",
         "Drives research recommendations and the generated project/agent plan."),
    ],
    "architecture": [
        ("backend_lang", "Backend language(s)?", ["TypeScript/Node", "Go", "Rust", "Python", "Java/Kotlin", "C#"], "TypeScript/Node",
         "Talent, ecosystem, performance."),
        ("frontend", "Frontend framework?", ["React 19", "Vue 3.6", "Angular 21", "Svelte 5", "SolidJS"], "React 19",
         "Hiring pool, DX, performance."),
        ("meta_framework", "Meta-framework for rendering?", ["Next.js 16", "Nuxt 3", "SvelteKit", "Astro 5", "Remix/RR7"], "Next.js 16",
         "SSR/SSG, SEO, routing, data loading."),
        ("repo_style", "Monorepo or polyrepo?", ["monorepo", "polyrepo"], "monorepo",
         "Shared code vs independent deploy."),
        ("api_style", "API style?", ["REST", "GraphQL", "gRPC", "tRPC/OpenAPI"], "REST",
         "Client needs, typing, performance."),
        ("datastore", "Primary datastore(s)?", ["Postgres", "MySQL", "MongoDB", "DynamoDB", "SQLite"], "Postgres",
         "Consistency, scale, query shape."),
        ("vector_store", "Vector/embedding store (for AI)?", ["none", "pgvector", "Pinecone", "Weaviate", "Qdrant"], "none",
         "AI search, RAG, semantic recall."),
        ("cache", "Caching layer?", ["Redis", "Memcached", "CDN", "in-memory", "none"], "Redis",
         "Reduces latency and DB load."),
        ("search", "Search engine?", ["Postgres FTS", "OpenSearch", "Elasticsearch", "Typesense", "none"], "Postgres FTS",
         "Full-text / faceted search at scale."),
        ("queue", "Message queue / async?", ["SQS", "Kafka", "NATS", "RabbitMQ", "Redis Streams", "none"], "none",
         "Decoupling, retries, backpressure."),
        ("ai_features", "Will the product include AI features?", ["yes", "no"], "no",
         "Chat, RAG, agents, classification, summarization."),
        ("llm_provider", "AI/LLM provider & model?", ["OpenAI", "Anthropic", "Gemini", "NVIDIA NIM", "open (Llama/Mistral vLLM)"], "NVIDIA NIM",
         "Capability, cost, data residency. NVIDIA NIM is OpenAI-compatible."),
        ("api_keys", "Which provider API keys do you have? (comma-separated; stored only in .env.local)", None, "NVIDIA NIM",
         "Used by the model layer for rotation/fallback. Never echoed to output."),
        ("model_selection", "Primary / fallback model for AI features?", None, "nim-llama-3.1-8b / nim-llama-3.1-70b",
         "Feeds the NIM model layer (primary + fallback)."),
        ("nim_base_url", "NVIDIA NIM base URL?", None, "https://integrate.api.nvidia.com/v1",
         "OpenAI-compatible NIM endpoint."),
        ("ai_pattern", "LLM integration pattern?", ["direct API", "gateway (LiteLLM)", "self-hosted vLLM", "NIM proxy"], "NIM proxy",
         "Cost, latency, control."),
        ("ai_eval", "Eval & guardrail framework?", ["RAGAS", "LangSmith", "promptfoo", "guardrails", "none"], "none",
         "Quality and safety of AI output."),
        ("auth", "Authentication approach?", ["Auth0/Okta", "Clerk", "NextAuth", "OIDC/SAML"], "Clerk",
         "Identity, SSO, MFA."),
        ("authz", "Authorization model?", ["RBAC", "ABAC", "ReBAC", "OPA"], "RBAC",
         "Least privilege, multi-tenancy."),
        ("compliance", "Relevant compliance regimes?", ["GDPR", "HIPAA", "SOC 2", "PCI-DSS", "CCPA", "none"], "none",
         "Legal and procurement requirements."),
    ],
    "setup": [
        ("cloud", "Cloud provider?", ["AWS", "GCP", "Azure", "Cloudflare", "Fly.io", "Render"], "AWS",
         "Existing contracts, region, services."),
        ("iac", "Infrastructure as Code tool?", ["Terraform", "Pulumi", "OpenTofu", "AWS CDK"], "Terraform",
         "Reproducible, reviewable infra."),
        ("cicd", "CI/CD platform?", ["GitHub Actions", "GitLab CI", "CircleCI", "Buildkite"], "GitHub Actions",
         "Build/test/deploy automation."),
        ("containers", "Containerization strategy?", ["Docker+Compose", "Kubernetes/EKS/GKE", "serverless"], "Docker+Compose",
         "Portability and scaling."),
        ("observability", "Observability stack?", ["OpenTelemetry+Grafana", "Datadog", "Honeycomb"], "OpenTelemetry+Grafana",
         "Debugging, SLOs, incident response."),
        ("secrets", "Secret management?", ["Vault", "AWS Secrets Manager", "Doppler", "env-injected"], "AWS Secrets Manager",
         "Avoid leaked credentials."),
        ("feature_flags", "Feature flag system?", ["LaunchDarkly", "PostHog", "Unleash", "Flagsmith", "none"], "none",
         "Progressive rollout, kill switch."),
        ("environments", "Environments (dev/staging/prod)?", None, "dev, staging, prod",
         "Safe promotion, parity."),
        ("package_manager", "Package manager?", ["pnpm", "npm", "bun", "yarn"], "pnpm",
         "Reproducibility, speed, lockfiles."),
        ("lint_format", "Linting & formatting?", ["Biome/ESLint+Prettier", "Ruff", "Clippy"], "Biome/ESLint+Prettier",
         "Consistent code, fewer review cycles."),
        ("test_framework", "Test framework & levels?", ["Vitest/Jest", "Playwright", "pytest", "k6"], "Vitest/Jest",
         "Confidence and safety net."),
        ("coverage", "Coverage expectation?", None, "70-90% unit; e2e smoke required",
         "Quality gate."),
        ("precommit", "Pre-commit hooks?", ["Lefthook", "Husky+lint-staged", "none"], "Lefthook",
         "Block bad commits locally."),
        ("agent_setup", "AI coding-agent setup?", ["AGENTS.md+skills+hooks", "CLAUDE.md import", "none"], "AGENTS.md+skills+hooks",
         "Leverage 2026 agent workflows."),
        ("docs", "Documentation approach?", ["Markdown/Starlight", "ADRs", "README+AGENTS.md"], "README+AGENTS.md",
         "Onboarding and maintenance."),
    ],
    "iterate": [
        ("branching", "Branching strategy?", ["trunk-based", "GitHub Flow", "GitFlow"], "trunk-based",
         "Merge safety, release cadence."),
        ("review", "Code review requirements?", None, "min 1-2 approvers, required checks",
         "Quality, knowledge sharing."),
        ("commits", "Commit/PR conventions?", ["Conventional Commits", "squash merge", "free-form"], "Conventional Commits",
         "History clarity, releases."),
        ("tracking", "Issue/task tracking?", ["GitHub Issues", "Linear", "Jira", "Shortcut"], "GitHub Issues",
         "Visibility and planning."),
        ("oncall", "On-call & incident process?", ["PagerDuty", "incident runbook", "postmortems"], "incident runbook",
         "Reliability ownership."),
        ("ownership", "Ownership model (CODEOWNERS)?", None, "per-service/module owners",
         "Clear accountability."),
        ("budget", "Monthly infra budget?", None, "",
         "Sets architecture ceiling."),
        ("scaling", "Scaling targets (users/RPS/data)?", None, "",
         "Capacity planning."),
        ("slo", "SLOs / SLAs?", None, "99.9% uptime, p95 < 300ms",
         "User expectations, penalties."),
        ("perf_budget", "Performance budget?", None, "LCP < 2.5s, bundle < 200KB",
         "UX and Core Web Vitals."),
    ],
}

ALL_PHASES = list(SECTIONS.keys())


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _slug(text: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s or "project"


def _ask(prompt: str, options, default, help_text: str) -> str:
    if options:
        opts = "/".join(options)
        dflt = f" [{default}]" if default in options else ""
        sys.stderr.write(f"\n{help_text}\n{prompt} ({opts}){dflt}: ")
        while True:
            ans = input().strip()
            if not ans and default:
                return default
            if ans in options:
                return ans
            sys.stderr.write(f"  choose one of: {opts}: ")
    else:
        dflt = f" [{default}]" if default else ""
        sys.stderr.write(f"\n{help_text}\n{prompt}{dflt}: ")
        try:
            ans = input().strip()
        except EOFError:
            return default
        return ans if ans else default


def _yaml_escape(v: str) -> str:
    if v == "" or re.fullmatch(r"[A-Za-z0-9_./@\- ]+", v or ""):
        return v
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

def run_intake(phases: list[str], non_interactive: bool, project: str) -> dict:
    # If no TTY on stdin (piped/CI), degrade to non-interactive instead of crashing.
    if not non_interactive and not sys.stdin.isatty():
        non_interactive = True
    answers: dict[str, dict] = {p: {} for p in phases}
    sys.stderr.write("=== Modern Project Intake Wizard (2026) ===\n")
    for phase in phases:
        sys.stderr.write(f"\n## {SECTIONS[phase]}\n")
        for qid, prompt, options, default, help_text in CATALOG[phase]:
            if non_interactive:
                val = default
            else:
                val = _ask(prompt, options, default, help_text)
            answers[phase][qid] = val
    return answers


def render_yaml(project: str, answers: dict) -> str:
    today = _dt.date.today().isoformat()
    lines = [
        f"# Modern project intake - generated {today}",
        f"project: {_yaml_escape(project)}",
        "generated: " + today,
        "phases:",
    ]
    for phase, qa in answers.items():
        lines.append(f"  {phase}:")
        for qid, val in qa.items():
            lines.append(f"    {qid}: {_yaml_escape(val)}")
    return "\n".join(lines) + "\n"


def render_summary(project: str, answers: dict) -> str:
    today = _dt.date.today().isoformat()
    out = [f"# Intake Summary: {project}", "",
           f"_Generated {today} from the 4-phase modern-project intake flow._", ""]
    for phase in answers:
        out.append(f"## {SECTIONS[phase]}")
        out.append("")
        for qid, prompt, options, default, help_text in CATALOG[phase]:
            val = answers[phase].get(qid, "")
            out.append(f"- **{prompt}** — `{val}`")
        out.append("")
    return "\n".join(out)


def render_agents_md(project: str, answers: dict) -> str:
    a = answers
    arch = a.get("architecture", {})
    setup = a.get("setup", {})
    disc = a.get("discovery", {})
    out = [f"# AGENTS.md - {project}", "",
           "> Source of truth for coding CLI agents working on this project. "
           "Import into CLAUDE.md / .kilo / other agent configs.", "",
           "## Project",
           f"- Problem: {disc.get('problem', '')}",
           f"- Users/platforms: {disc.get('users', '')}",
           f"- Mode: {disc.get('mode', '')}",
           "",
           "## Stack",
           f"- Backend: {arch.get('backend_lang', '')}",
           f"- Frontend: {arch.get('frontend', '')} + {arch.get('meta_framework', '')}",
           f"- Repo: {arch.get('repo_style', '')}",
           f"- API: {arch.get('api_style', '')}",
           f"- Datastore: {arch.get('datastore', '')} | Cache: {arch.get('cache', '')} | Search: {arch.get('search', '')}",
            f"- AI: features={arch.get('ai_features', '')} provider={arch.get('llm_provider', '')} model={arch.get('model_selection', '')} pattern={arch.get('ai_pattern', '')} eval={arch.get('ai_eval', '')}",
           "",
           "## DX & Infra",
           f"- Cloud: {setup.get('cloud', '')} | IaC: {setup.get('iac', '')} | CI/CD: {setup.get('cicd', '')}",
           f"- Package mgr: {setup.get('package_manager', '')} | Lint: {setup.get('lint_format', '')} | Tests: {setup.get('test_framework', '')}",
           f"- Agent setup: {setup.get('agent_setup', '')}",
           "",
           "## Guardrails",
           "- Run lint + typecheck + tests before committing.",
           "- No secrets in repo or images; use secret manager.",
           "- Keep this file as the source of truth; sync to other agent configs.",
           ""]
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Dependency installation
# ---------------------------------------------------------------------------
# Maps an answered question id -> list of (label, install_command, detector, tier).
# detector is a shell command that exits 0 when the tool is already present.
# tier orders the install plan: 1 runtime/lang -> 2 pkg mgr -> 3 lint/test ->
# 4 frameworks -> 5 data/services -> 6 observability -> 7 infra -> 8 AI.

TIER_NAMES = {
    1: "Runtime / language",
    2: "Package manager",
    3: "Lint / format / test / pre-commit",
    4: "Frameworks",
    5: "Data & services",
    6: "Observability",
    7: "Infrastructure / DevOps",
    8: "AI",
}

DEPS: dict[str, list[tuple]] = {
    "package_manager": [
        ("pnpm", "npm install -g pnpm", "command -v pnpm", 2),
        ("npm", "npm install -g npm@latest", "command -v npm", 2),
        ("bun", "npm install -g bun", "command -v bun", 2),
        ("yarn", "npm install -g yarn", "command -v yarn", 2),
    ],
    "backend_lang": [
        ("Go", " (install via apt/brew: golang-go)", "command -v go", 1),
        ("Rust", " (install via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)", "command -v rustc", 1),
        ("Python", "python3 already present", "command -v python3", 1),
        ("TypeScript/Node", "node already present", "command -v node", 1),
        ("Java/Kotlin", " (install via apt/brew: default-jdk)", "command -v java", 1),
        ("C#", " (install via apt/brew: dotnet-sdk)", "command -v dotnet", 1),
    ],
    "iac": [
        ("Terraform", " (install via apt/brew: terraform)", "command -v terraform", 7),
        ("OpenTofu", " (install via: brew install opentofu/tap/tofu)", "command -v tofu", 7),
        ("Pulumi", " (install via: curl -fsSL https://get.pulumi.com | sh)", "command -v pulumi", 7),
        ("AWS CDK", "npm install -g aws-cdk", "command -v cdk", 7),
    ],
    "cicd": [
        ("GitHub Actions", "gh already present", "command -v gh", 7),
        ("GitLab CI", " (install via apt/brew: glab)", "command -v glab", 7),
        ("CircleCI", " (install via: brew install circleci)", "command -v circleci", 7),
    ],
    "containers": [
        ("Docker+Compose", "docker already present", "command -v docker", 7),
        ("Kubernetes/EKS/GKE", " (install via: brew install kubectl)", "command -v kubectl", 7),
        ("serverless", " (install via: npm install -g serverless)", "command -v serverless", 7),
    ],
    "cache": [
        ("Redis", " (install via apt/brew: redis)", "command -v redis-server", 5),
        ("Memcached", " (install via apt/brew: memcached)", "command -v memcached", 5),
    ],
    "search": [
        ("OpenSearch", " (install via: docker run -d -p 9200:9200 opensearchproject/opensearch)", "command -v opensearch", 5),
        ("Elasticsearch", " (install via: docker run -d -p 9200:9200 elasticsearch)", "command -v elasticsearch", 5),
        ("Typesense", " (install via apt/brew: typesense)", "command -v typesense-server", 5),
    ],
    "queue": [
        ("Kafka", " (install via: docker run -d -p 9092:9092 bitnami/kafka)", "command -v kafka", 5),
        ("NATS", " (install via apt/brew: nats-server)", "command -v nats-server", 5),
        ("RabbitMQ", " (install via: docker run -d -p 5672:5672 rabbitmq)", "command -v rabbitmqctl", 5),
        ("Redis Streams", "redis already present if cache=Redis", "command -v redis-server", 5),
        ("SQS", "aws cli already present via gh/aws", "command -v aws", 5),
    ],
    "observability": [
        ("OpenTelemetry+Grafana", " (install via: docker run -d -p 3000:3000 grafana/grafana)", "command -v grafana-server", 6),
        ("Datadog", " (install via: brew install datadog", "command -v datadog-agent", 6),
        ("Honeycomb", " (install via: brew install honeycombio/honeycomb/honeycomb)", "command -v honeycomb", 6),
    ],
    "precommit": [
        ("Lefthook", "npm install -g lefthook", "command -v lefthook", 3),
        ("Husky+lint-staged", "npm install -D husky lint-staged", "command -v husky", 3),
    ],
    "feature_flags": [
        ("LaunchDarkly", " (sign up at launchdarkly.com; SDK via npm/pip)", "command -v launchdarkly", 7),
        ("PostHog", " (sign up at posthog.com; SDK via npm/pip)", "command -v posthog", 7),
        ("Unleash", " (install via: docker run -d -p 4242:4242 unleash/unleash-server)", "command -v unleash", 7),
        ("Flagsmith", " (install via: docker run -d -p 8000:8000 flagsmith/flagsmith)", "command -v flagsmith", 7),
    ],
    "llm_provider": [
        ("OpenAI", " (set OPENAI_API_KEY; npm i openai)", "test -n \"$OPENAI_API_KEY\"", 8),
        ("Anthropic", " (set ANTHROPIC_API_KEY; npm i @anthropic-ai/sdk)", "test -n \"$ANTHROPIC_API_KEY\"", 8),
        ("Gemini", " (set GEMINI_API_KEY; npm i @google/generative-ai)", "test -n \"$GEMINI_API_KEY\"", 8),
        ("NVIDIA NIM", " (set NVIDIA_NIM_API_KEY; npm i @nvidia/... or use OpenAI-compatible client)", "test -n \"$NVIDIA_NIM_API_KEY\"", 8),
    ],
    "ai_pattern": [
        ("gateway (LiteLLM)", "python3 -m pip install litellm  # (externally-managed env: use a venv or --break-system-packages)", "command -v litellm", 8),
        ("self-hosted vLLM", "pip install vllm  # (externally-managed env: use a venv or --break-system-packages)", "command -v vllm", 8),
    ],
    "lint_format": [
        ("Biome/ESLint+Prettier", "npm install -D biome eslint prettier", "command -v biome", 3),
        ("Ruff", "python3 -m pip install ruff  # (externally-managed env: use a venv or --break-system-packages)", "command -v ruff", 3),
        ("Clippy", "rustup component add clippy", "command -v cargo-clippy", 3),
    ],
    "test_framework": [
        ("Vitest/Jest", "npm install -D vitest jest", "command -v vitest", 3),
        ("Playwright", "npm install -D playwright && npx playwright install", "command -v playwright", 3),
        ("pytest", "python3 -m pip install pytest  # (externally-managed env: use a venv or --break-system-packages)", "command -v pytest", 3),
        ("k6", " (install via: brew install k6)", "command -v k6", 3),
    ],
}

# answers we can read env keys / API keys from (never print secrets)
ENV_KEYS = {
    "OpenAI": "OPENAI_API_KEY",
    "Anthropic": "ANTHROPIC_API_KEY",
    "Gemini": "GEMINI_API_KEY",
    "NVIDIA NIM": "NVIDIA_NIM_API_KEY",
}


def build_deps(answers: dict) -> list[tuple]:
    """Resolve (label, command, detector, tier) tuples for answered options."""
    resolved: list[tuple] = []
    seen = set()
    for phase, qa in answers.items():
        for qid, val in qa.items():
            if qid not in DEPS or not val:
                continue
            for entry in DEPS[qid]:
                label, cmd, detector = entry[0], entry[1], entry[2]
                tier = entry[3] if len(entry) > 3 else 9
                if label == val and label not in seen:
                    seen.add(label)
                    resolved.append((label, cmd, detector, tier))
    resolved.sort(key=lambda x: (x[3], x[0]))
    return resolved


def _is_present_note(cmd: str) -> bool:
    """True for pseudo-commands like 'node already present' (nothing to run)."""
    c = cmd.strip().lower()
    return c.endswith("already present") or c == ""


def _detector_expr(detector: str) -> str:
    """Wrap a detector so stdout/stderr is silenced without breaking `test`."""
    if detector.strip().startswith("test "):
        return detector  # test has no stdout; redirection would misparse
    return f"{detector} >/dev/null 2>&1"


def render_deps_script(project: str, answers: dict, execute: bool) -> str:
    lines = ["#!/usr/bin/env bash", "set -euo pipefail",
             f"# Dependency installer for {project} (generated by intake.py)",
             "# Review before running. Network/package-manager access required.",
             "# Steps run only 'auto' tier by default; use --force to attempt 'manual'.",
             ""]
    for label, cmd, detector, tier in build_deps(answers):
        mode = "auto" if _safe_to_autorun(cmd) else "manual"
        lines.append(f'echo "== [tier {tier}] {label} ({mode}) =="')
        lines.append(f"if {_detector_expr(detector)}; then")
        lines.append(f'  echo "  already present: {label}"')
        lines.append("else")
        if _is_present_note(cmd):
            lines.append(f'  echo "  no install needed: {cmd.strip()}"')
        elif not _safe_to_autorun(cmd):
            note = cmd.strip().strip("()").strip() if cmd.lstrip().startswith("(") else cmd
            lines.append(f'  echo "  MANUAL: {note}"')
            lines.append(f'  # {note}')
        elif execute:
            lines.append(f'  echo "  installing: {cmd}"')
            lines.append(f"  {cmd}")
        else:
            lines.append(f'  echo "  # (dry-run) install: {cmd}"')
        lines.append("fi")
        lines.append("")
    return "\n".join(lines)


def render_deps_plan_md(project: str, answers: dict) -> str:
    today = _dt.date.today().isoformat()
    out = [f"# Dependency Install Plan: {project}", "",
           f"_Generated {today} from intake answers. Ordered by install tier._", "",
           "Run safe (`auto`) steps with `bash <project>.deps.sh`; "
           "`auto` steps execute, `manual` steps are printed for review. "
           "Use `bash <project>.deps.sh` with `--force` only to attempt manual steps.",
           ""]
    current = None
    for label, cmd, detector, tier in build_deps(answers):
        if tier != current:
            current = tier
            out.append(f"## Tier {tier} - {TIER_NAMES.get(tier, 'Other')}")
            out.append("")
        mode = "auto" if _safe_to_autorun(cmd) else "manual"
        cmd_disp = cmd.strip().strip("()").strip() if cmd.lstrip().startswith("(") else cmd
        out.append(f"- **[{mode}] {label}:** `{cmd_disp}`")
    out.append("")
    return "\n".join(out)


def _safe_to_autorun(cmd: str) -> bool:
    """Only auto-run package-manager installs that are safe in this environment.

    apt/brew/docker/pip/curl steps require elevated perms, a daemon, or a venv
    and are emitted as manual steps instead of being executed automatically.
    """
    head = cmd.strip().split()[0] if cmd.strip() else ""
    if head in ("apt", "brew", "docker", "curl", "sudo", "pip", "python3"):
        return False
    if cmd.lstrip().startswith("("):  # parenthesized manual note
        return False
    return True


def install_deps(answers: dict, dry_run: bool) -> None:
    import subprocess
    sys.stderr.write("\n=== Dependency installation ===\n")
    for label, cmd, detector, tier in build_deps(answers):
        try:
            present = subprocess.run(detector, shell=True,
                                     stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL).returncode == 0
        except Exception:
            present = False
        if present:
            sys.stderr.write(f"  [ok]    {label} (already present)\n")
            continue
        if dry_run:
            sys.stderr.write(f"  [install] {label}: {cmd}\n")
            continue
        if not _safe_to_autorun(cmd):
            sys.stderr.write(f"  [manual] {label}: {cmd}\n")
            continue
        sys.stderr.write(f"  [run]   {label}: {cmd}\n")
        try:
            subprocess.run(cmd, shell=True, check=True, timeout=180)
            sys.stderr.write(f"  [done]  {label}\n")
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"  [FAILED] {label}: {e}\n")
        except subprocess.TimeoutExpired:
            sys.stderr.write(f"  [TIMEOUT] {label}: skipped\n")


# ---------------------------------------------------------------------------
# Research (online, once; cached) + prompt enrichment (offline)
# ---------------------------------------------------------------------------

# Language -> LSP server(s) used by the agent profile.
LSP_BY_LANG = {
    "Go": ["gopls"],
    "Rust": ["rust-analyzer"],
    "Python": ["pylsp", "ruff"],
    "TypeScript/Node": ["typescript-language-server", "eslint"],
    "Java/Kotlin": ["jdtls"],
    "C#": ["omnisharp", "csharp-ls"],
}

# Curated high-signal skills/MCP per framework (web-verified at research time;
# this map is the offline fallback used when cache is missing).
FRAMEWORK_SKILLS = {
    "React 19": ["react-components", "nextjs", "tailwind-ui"],
    "Next.js 16": ["nextjs", "vercel-deploy", "react-components"],
    "Vue 3.6": ["vue", "nuxt"],
    "Svelte 5": ["svelte", "sveltekit"],
    "Angular 21": ["angular"],
    "Astro 5": ["astro"],
    "Go": ["go-test", "go-mod"],
    "Python": ["python-packaging", "pytest"],
}

FRAMEWORK_MCP = {
    "React 19": "mcp-server-react",
    "Next.js 16": "mcp-server-next",
    "Go": "mcp-server-go",
    "Python": "mcp-server-python",
}


def _merge_research(base: dict, override: dict) -> dict:
    """Deep-ish merge: override scalars/lists over base; lists extend+dedupe."""
    for k, v in override.items():
        if isinstance(v, list) and isinstance(base.get(k), list):
            base[k] = list(dict.fromkeys(base[k] + v))
        elif isinstance(v, dict) and isinstance(base.get(k), dict):
            base[k].update(v)
        else:
            base[k] = v
    return base


def run_research(answers: dict, cache_path: Path, force: bool = False,
                 bridge_path: Path | None = None) -> dict:
    """Always-on research: framework skills/MCP/LSP + goal skills.

    Strategy (offline-safe, live when possible):
    1. Start from a curated fallback map (FRAMEWORK_SKILLS / FRAMEWORK_MCP / LSP_BY_LANG).
    2. If a research bridge JSON exists (real web findings, e.g. produced by the
       `websearch` tool at the host/agent level), merge it on top. The bridge
       shape is any subset of the research dict: {"frameworks": {...},
       "top_skills_for_framework": [...], "top_mcp_server": [...],
       "lsp_servers": [...], "knowledge_bases": [...]}.
    3. Cache the merged result to <project>.research.json so later --offline runs
       and the enrichment step never hit the network again.

    NOTE: `websearch` is an agent tool, not an importable module, so the script
    itself cannot call it. The bridge file is the supported live-research path.
    """
    if cache_path.exists() and not force:
        try:
            return json.loads(cache_path.read_text())
        except Exception:
            pass

    arch = answers.get("architecture", {})
    frameworks = [arch.get("frontend", ""), arch.get("meta_framework", "")]
    langs = [arch.get("backend_lang", "")]
    goal = answers.get("discovery", {}).get("best_outcomes", "")

    research: dict = {
        "frameworks": {},
        "top_skills_for_framework": [],
        "top_mcp_server": [],
        "top_skills_for_goal": [],
        "lsp_servers": [],
        "knowledge_bases": [],
        "generated": _dt.date.today().isoformat(),
        "source": "curated-fallback",
    }

    for fw in frameworks:
        if not fw:
            continue
        research["frameworks"][fw] = "(curated) agent skills for " + fw
        research["top_skills_for_framework"].extend(FRAMEWORK_SKILLS.get(fw, []))
        if fw in FRAMEWORK_MCP:
            research["top_mcp_server"].append(FRAMEWORK_MCP[fw])

    for lang in langs:
        research["lsp_servers"].extend(LSP_BY_LANG.get(lang, []))

    if goal:
        research["knowledge_bases"].append("(curated) goal: " + goal[:200])

    # Live research bridge: merge real web findings if provided.
    if bridge_path and bridge_path.exists():
        try:
            bridge = json.loads(bridge_path.read_text())
            research = _merge_research(research, bridge)
            research["source"] = "bridge+" + research.get("source", "curated-fallback")
        except Exception:
            pass

    research["top_skills_for_goal"] = list(dict.fromkeys(
        research["top_skills_for_framework"]))[:5]

    # de-dupe
    for k in ("top_skills_for_framework", "top_mcp_server", "top_skills_for_goal",
              "lsp_servers", "knowledge_bases"):
        research[k] = list(dict.fromkeys([x for x in research[k] if x]))

    cache_path.write_text(json.dumps(research, indent=2))
    return research


def write_secrets(answers: dict, out_dir: Path) -> Path:
    """Write API keys to .env.local (git-ignored). Returns the path."""
    arch = answers.get("architecture", {})
    raw = arch.get("api_keys", "") or ""
    keys = [k.strip() for k in raw.split(",") if k.strip()]
    lines = ["# Generated by intake.py - DO NOT COMMIT", ""]
    for k in keys:
        envvar = ENV_KEYS.get(k)
        if envvar:
            lines.append(f"{envvar}=<your-key-here>")
        else:
            lines.append(f"# provider '{k}' (no known env var)")
    lines.append("")
    p = out_dir / ".env.local"
    p.write_text("\n".join(lines))
    return p


def render_project_plan_md(project: str, answers: dict, research: dict) -> str:
    disc = answers.get("discovery", {})
    arch = answers.get("architecture", {})
    today = _dt.date.today().isoformat()
    out = [
        f"# Project Plan: {project}", "",
        f"_Generated {today} from intake (offline enrichment)._", "",
        "## Best outcome (90 days)",
        disc.get("best_outcomes", "(not specified)"), "",
        "## Stack snapshot",
        f"- Backend: {arch.get('backend_lang','')}",
        f"- Frontend: {arch.get('frontend','')} + {arch.get('meta_framework','')}",
        f"- AI: provider={arch.get('llm_provider','')} model={arch.get('model_selection','')}",
        f"- LSP servers: {', '.join(research.get('lsp_servers', [])) or 'n/a'}", "",
        "## Recommended skills (favorites)",
        *(f"- {s}" for s in research.get("top_skills_for_framework", [])),
        "",
        "## Recommended MCP",
        *(f"- {m}" for m in research.get("top_mcp_server", [])),
        "",
        "## Knowledge bases",
        *(f"- {k}" for k in research.get("knowledge_bases", [])),
        "",
        "## Next steps (offline)",
        "1. Install tiered dependencies (`bash <project>.deps.sh`).",
        "2. Equip favorite skills via the agent profile below.",
        "3. Wire MCP + LSP into the agent's config.",
        "4. Use the NIM model layer for all AI calls (rotation + fallback).",
        "",
    ]
    return "\n".join(out)


def render_agent_profile_md(project: str, answers: dict, research: dict) -> str:
    arch = answers.get("architecture", {})
    setup = answers.get("setup", {})
    out = [
        f"# Agent Profile: {project}", "",
        "> Specialized coding-agent profile. Auto-equip favorite skills on match; "
        "full MCP + LSP awareness. Imported by AGENTS.md so the agent loads it on demand.",
        "",
        "## Skill favorites (auto-equip rules)",
    ]
    for s in research.get("top_skills_for_framework", []):
        out.append(f"- `{s}` — equip when task mentions {s} or related files")
    out += [
        "",
        "## MCP awareness",
    ]
    for m in research.get("top_mcp_server", []):
        out.append(f"- `{m}` — tools available for framework tasks")
    out += [
        "",
        "## LSP servers",
    ]
    for l in research.get("lsp_servers", []):
        out.append(f"- `{l}`")
    out += [
        "",
        "## Model config (NVIDIA NIM)",
        f"- base_url: {arch.get('nim_base_url','https://integrate.api.nvidia.com/v1')}",
        f"- primary/fallback: {arch.get('model_selection','nim-llama-3.1-8b / nim-llama-3.1-70b')}",
        "- keys: loaded from .env.local (rotation + fallback on 429)",
        "- rpm limit: enforced per key; fallback model on exhaustion",
        "",
        "## Guardrails",
        "- Run lint + typecheck + tests before committing.",
        "- No secrets in repo or images; use secret manager / .env.local.",
        "- Keep AGENTS.md as the index; import this profile, do not inline everything.",
        "",
    ]
    return "\n".join(out)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _bridge(args, out_dir: Path) -> Path | None:
    """Resolve the research bridge JSON path (explicit or auto-discovered)."""
    if args.research_json:
        return Path(args.research_json).expanduser()
    auto = out_dir / f"{_slug(args.project or 'project')}.research-input.json"
    return auto if auto.exists() else None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Modern project intake wizard (2026).")
    ap.add_argument("--phase", choices=ALL_PHASES, action="append",
                    help="Run only these phases (repeatable). Default: all.")
    ap.add_argument("--project", default="", help="Project name (for output files).")
    ap.add_argument("--out", default=".", help="Output directory. Default: current dir.")
    ap.add_argument("--non-interactive", action="store_true",
                    help="Use defaults only (for CI / scaffolding).")
    ap.add_argument("--list", action="store_true", help="Print the question catalog and exit.")
    ap.add_argument("--deps", action="store_true",
                    help="Print/emit dependency install steps for answered tools.")
    ap.add_argument("--install-deps", action="store_true",
                    help="Actually run install commands for missing tools (needs network).")
    ap.add_argument("--deps-dry-run", action="store_true",
                    help="Show install commands without executing them.")
    ap.add_argument("--research", action="store_true",
                    help="Force research recompute (ignore cache). "
                         "Live findings come from a bridge JSON (see --research-json).")
    ap.add_argument("--research-json", default=None,
                    help="Path to a research bridge JSON (real web findings) merged over the "
                         "curated fallback. Shape: any subset of {frameworks, "
                         "top_skills_for_framework, top_mcp_server, lsp_servers, knowledge_bases}.")
    ap.add_argument("--offline", action="store_true",
                    help="Use cached research only; never call web search.")
    ap.add_argument("--plan", action="store_true",
                    help="Generate project-plan.md and agent-profile.md (offline enrichment).")
    ap.add_argument("--ai-plan", action="store_true",
                    help="Refine the plan with one NIM model call (needs network + keys).")
    ap.add_argument("--force", action="store_true",
                    help="Overwrite existing files / attempt manual deps.")
    args = ap.parse_args(argv)

    if args.list:
        for phase, qs in CATALOG.items():
            print(f"\n# {SECTIONS[phase]}")
            for qid, prompt, options, default, help_text in qs:
                opt = f" options={options}" if options else ""
                print(f"  - {qid}: {prompt} (default={default!r}{opt})")
        return 0

    phases = args.phase or ALL_PHASES
    project = args.project or _slug(input("Project name (for output files): ").strip()) \
        if not args.non_interactive and not args.project else (args.project or "my-project")
    if not project:
        project = "my-project"

    answers = run_intake(phases, args.non_interactive, project)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    yaml_path = out_dir / f"{_slug(project)}.intake.yaml"
    md_path = out_dir / f"{_slug(project)}.intake.md"
    agents_path = out_dir / "AGENTS.md"

    yaml_path.write_text(render_yaml(project, answers))
    md_path.write_text(render_summary(project, answers))
    agents_path.write_text(render_agents_md(project, answers))

    sys.stderr.write(
        f"\nWrote:\n  {yaml_path}\n  {md_path}\n  {agents_path}\n"
    )

    # Always-on research unless offline; cached for reuse.
    research_cache = out_dir / f"{_slug(project)}.research.json"
    if args.offline:
        research = run_research(answers, research_cache, force=False,
                                 bridge_path=_bridge(args, out_dir))
        sys.stderr.write("  [research] offline (cached)\n")
    else:
        research = run_research(answers, research_cache, force=args.research,
                                 bridge_path=_bridge(args, out_dir))
        sys.stderr.write(f"  {research_cache}\n")

    # Secrets hygiene: API keys -> .env.local, masked in yaml.
    secrets_path = write_secrets(answers, out_dir)
    sys.stderr.write(f"  {secrets_path}\n")
    gitignore = out_dir / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text(".env.local\n*.research.json\n")
        sys.stderr.write(f"  {gitignore}\n")

    if args.plan or args.ai_plan:
        plan_path = out_dir / f"{_slug(project)}.project-plan.md"
        profile_path = out_dir / f"{_slug(project)}.agent-profile.md"
        plan_path.write_text(render_project_plan_md(project, answers, research))
        profile_path.write_text(render_agent_profile_md(project, answers, research))
        sys.stderr.write(f"  {plan_path}\n  {profile_path}\n")
        if args.ai_plan:
            _ai_refine_plan(project, answers, research, out_dir)

    # Always emit the tiered deps plan + script; run only on request.
    deps_sh = out_dir / f"{_slug(project)}.deps.sh"
    deps_md = out_dir / f"{_slug(project)}.deps-plan.md"
    deps_script = render_deps_script(project, answers, execute=args.install_deps)
    deps_sh.write_text(deps_script)
    deps_md.write_text(render_deps_plan_md(project, answers))
    sys.stderr.write(f"  {deps_sh}\n  {deps_md}\n")
    if args.install_deps:
        install_deps(answers, dry_run=False)
    elif args.deps_dry_run:
        install_deps(answers, dry_run=True)
    elif not args.deps:
        sys.stderr.write("  (use --install-deps to run, or --deps-dry-run to preview)\n")

    return 0


def _ai_refine_plan(project, answers, research, out_dir):
    """One NIM model call to refine the project plan (optional, online)."""
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import model_layer  # type: ignore
    except Exception as e:
        sys.stderr.write(f"  [ai-plan] model_layer unavailable: {e}\n")
        return
    arch = answers.get("architecture", {})
    keys_file = out_dir / ".env.local"
    keys = model_layer.load_keys_from_file(str(keys_file))
    if not keys:
        sys.stderr.write("  [ai-plan] no API keys in .env.local; skipping.\n")
        return
    client = model_layer.NIMClient(
        base_url=arch.get("nim_base_url", "https://integrate.api.nvidia.com/v1"),
        primary_keys=keys,
        fallback_keys=keys,
        primary_model=arch.get("model_selection", "nim-llama-3.1-8b").split("/")[0].strip(),
        fallback_model="nim-llama-3.1-70b",
    )
    prompt = (
        f"Given this project intake, write a concise 5-step implementation plan "
        f"and list the top 3 risks.\n\n"
        f"Best outcome: {answers.get('discovery', {}).get('best_outcomes', '')}\n"
        f"Stack: {arch.get('backend_lang','')} / {arch.get('frontend','')} / "
        f"{arch.get('meta_framework','')}\n"
        f"Skills: {', '.join(research.get('top_skills_for_framework', []))}\n"
        f"MCP: {', '.join(research.get('top_mcp_server', []))}"
    )
    try:
        refined = client.call(prompt, max_tokens=600)
    except Exception as e:
        sys.stderr.write(f"  [ai-plan] call failed: {e}\n")
        return
    path = out_dir / f"{_slug(project)}.project-plan.ai.md"
    path.write_text(f"# AI-refined Plan: {project}\n\n{refined}\n")
    sys.stderr.write(f"  {path} (telemetry: {json.dumps(client.telemetry.as_dict())})\n")


if __name__ == "__main__":
    raise SystemExit(main())
