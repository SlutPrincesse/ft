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
        ("llm_provider", "AI/LLM provider & model?", ["OpenAI", "Anthropic", "Gemini", "open (Llama/Mistral vLLM)"], "OpenAI",
         "Capability, cost, data residency."),
        ("ai_pattern", "LLM integration pattern?", ["direct API", "gateway (LiteLLM)", "self-hosted vLLM"], "direct API",
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
        ans = input().strip()
        return ans if ans else default


def _yaml_escape(v: str) -> str:
    if v == "" or re.fullmatch(r"[A-Za-z0-9_./@\- ]+", v or ""):
        return v
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

def run_intake(phases: list[str], non_interactive: bool, project: str) -> dict:
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
           f"- AI: features={arch.get('ai_features', '')} provider={arch.get('llm_provider', '')} pattern={arch.get('ai_pattern', '')} eval={arch.get('ai_eval', '')}",
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
# Maps an answered question id -> list of (label, install_command, detector).
# detector is a shell command that exits 0 when the tool is already present.

DEPS: dict[str, list[tuple]] = {
    "package_manager": [
        ("pnpm", "npm install -g pnpm", "command -v pnpm"),
        ("npm", "npm install -g npm@latest", "command -v npm"),
        ("bun", "npm install -g bun", "command -v bun"),
        ("yarn", "npm install -g yarn", "command -v yarn"),
    ],
    "backend_lang": [
        ("Go", " (install via apt/brew: golang-go)", "command -v go"),
        ("Rust", " (install via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)", "command -v rustc"),
        ("Python", "python3 already present", "command -v python3"),
        ("TypeScript/Node", "node already present", "command -v node"),
        ("Java/Kotlin", " (install via apt/brew: default-jdk)", "command -v java"),
        ("C#", " (install via apt/brew: dotnet-sdk)", "command -v dotnet"),
    ],
    "iac": [
        ("Terraform", " (install via apt/brew: terraform)", "command -v terraform"),
        ("OpenTofu", " (install via: brew install opentofu/tap/tofu)", "command -v tofu"),
        ("Pulumi", " (install via: curl -fsSL https://get.pulumi.com | sh)", "command -v pulumi"),
        ("AWS CDK", "npm install -g aws-cdk", "command -v cdk"),
    ],
    "cicd": [
        ("GitHub Actions", "gh already present", "command -v gh"),
        ("GitLab CI", " (install via apt/brew: glab)", "command -v glab"),
        ("CircleCI", " (install via: brew install circleci)", "command -v circleci"),
    ],
    "containers": [
        ("Docker+Compose", "docker already present", "command -v docker"),
        ("Kubernetes/EKS/GKE", " (install via: brew install kubectl)", "command -v kubectl"),
        ("serverless", " (install via: npm install -g serverless)", "command -v serverless"),
    ],
    "cache": [
        ("Redis", " (install via apt/brew: redis)", "command -v redis-server"),
        ("Memcached", " (install via apt/brew: memcached)", "command -v memcached"),
    ],
    "search": [
        ("OpenSearch", " (install via: docker run -d -p 9200:9200 opensearchproject/opensearch)", "command -v opensearch"),
        ("Elasticsearch", " (install via: docker run -d -p 9200:9200 elasticsearch)", "command -v elasticsearch"),
        ("Typesense", " (install via apt/brew: typesense)", "command -v typesense-server"),
    ],
    "queue": [
        ("Kafka", " (install via: docker run -d -p 9092:9092 bitnami/kafka)", "command -v kafka"),
        ("NATS", " (install via apt/brew: nats-server)", "command -v nats-server"),
        ("RabbitMQ", " (install via: docker run -d -p 5672:5672 rabbitmq)", "command -v rabbitmqctl"),
        ("Redis Streams", "redis already present if cache=Redis", "command -v redis-server"),
        ("SQS", "aws cli already present via gh/aws", "command -v aws"),
    ],
    "observability": [
        ("OpenTelemetry+Grafana", " (install via: docker run -d -p 3000:3000 grafana/grafana)", "command -v grafana-server"),
        ("Datadog", " (install via: brew install datadog", "command -v datadog-agent"),
        ("Honeycomb", " (install via: brew install honeycombio/honeycomb/honeycomb)", "command -v honeycomb"),
    ],
    "precommit": [
        ("Lefthook", "npm install -g lefthook", "command -v lefthook"),
        ("Husky+lint-staged", "npm install -D husky lint-staged", "command -v husky"),
    ],
    "feature_flags": [
        ("LaunchDarkly", " (sign up at launchdarkly.com; SDK via npm/pip)", "command -v launchdarkly"),
        ("PostHog", " (sign up at posthog.com; SDK via npm/pip)", "command -v posthog"),
        ("Unleash", " (install via: docker run -d -p 4242:4242 unleash/unleash-server)", "command -v unleash"),
        ("Flagsmith", " (install via: docker run -d -p 8000:8000 flagsmith/flagsmith)", "command -v flagsmith"),
    ],
    "llm_provider": [
        ("OpenAI", " (set OPENAI_API_KEY; npm i openai)", "test -n \"$OPENAI_API_KEY\""),
        ("Anthropic", " (set ANTHROPIC_API_KEY; npm i @anthropic-ai/sdk)", "test -n \"$ANTHROPIC_API_KEY\""),
        ("Gemini", " (set GEMINI_API_KEY; npm i @google/generative-ai)", "test -n \"$GEMINI_API_KEY\""),
    ],
    "ai_pattern": [
        ("gateway (LiteLLM)", "python3 -m pip install litellm  # (externally-managed env: use a venv or --break-system-packages)", "command -v litellm"),
        ("self-hosted vLLM", "pip install vllm", "command -v vllm"),
    ],
}

# answers we can read env keys / API keys from (never print secrets)
ENV_KEYS = {
    "OpenAI": "OPENAI_API_KEY",
    "Anthropic": "ANTHROPIC_API_KEY",
    "Gemini": "GEMINI_API_KEY",
}


def build_deps(answers: dict) -> list[tuple]:
    """Resolve (label, command, detector) tuples for answered options."""
    resolved: list[tuple] = []
    seen = set()
    for phase, qa in answers.items():
        for qid, val in qa.items():
            if qid not in DEPS or not val:
                continue
            for label, cmd, detector in DEPS[qid]:
                if label == val and label not in seen:
                    seen.add(label)
                    resolved.append((label, cmd, detector))
    return resolved


def render_deps_script(project: str, answers: dict, execute: bool) -> str:
    lines = ["#!/usr/bin/env bash", "set -euo pipefail",
             f"# Dependency installer for {project} (generated by intake.py)",
             "# Review before running. Network/package-manager access required.",
             ""]
    for label, cmd, detector in build_deps(answers):
        lines.append(f'echo "== {label} =="')
        lines.append(f"if {detector} >/dev/null 2>&1; then")
        lines.append(f'  echo "  already present: {label}"')
        lines.append("else")
        if cmd.lstrip().startswith("("):
            note = cmd.strip().strip("()").strip()
            lines.append(f'  echo "  MANUAL: {note}"')
            lines.append(f'  # {note}')
        elif execute:
            lines.append(f'  echo "  installing: {cmd}"')
            lines.append(f"  {cmd}")
        else:
            lines.append(f'  # install: {cmd}')
        lines.append("fi")
        lines.append("")
    return "\n".join(lines)


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
    for label, cmd, detector in build_deps(answers):
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
# CLI
# ---------------------------------------------------------------------------

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

    if args.deps or args.install_deps or args.deps_dry_run:
        deps_path = out_dir / f"{_slug(project)}.deps.sh"
        deps_script = render_deps_script(project, answers, execute=args.install_deps)
        if args.deps or args.install_deps or args.deps_dry_run:
            deps_path.write_text(deps_script)
            sys.stderr.write(f"  {deps_path}\n")
        if args.install_deps:
            install_deps(answers, dry_run=False)
        elif args.deps_dry_run:
            install_deps(answers, dry_run=True)
        else:
            sys.stderr.write("  (use --install-deps to run, or --deps-dry-run to preview)\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
