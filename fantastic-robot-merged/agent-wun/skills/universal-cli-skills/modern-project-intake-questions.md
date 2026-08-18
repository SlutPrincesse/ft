# Modern Project Intake Questions (2026)

A comprehensive, categorized checklist of the questions every developer should answer before
or while building a modernized software project — whether greenfield or a modernization of an
existing codebase. Use the tables to drive an intake workshop; tailor to your context.

---

## 1. Product & Requirements

| Question | Why it matters | Default/Options |
|---|---|---|
| What is the core problem and success metric? | Prevents scope creep; defines "done." | North-star metric (e.g. activation rate, revenue, latency) |
| Who are the users and what devices/platforms? | Drives UX, accessibility, and platform choices. | Web, mobile, desktop, API-only, kiosk/IoT |
| What are the must-have (MVP) vs nice-to-have features? | Focuses first release; defers cost. | MoSCoW prioritization |
| What are the non-functional requirements (NFRs)? | Sets perf, availability, and compliance bar. | Latency, uptime, concurrency, accessibility (WCAG 2.2) |
| What is the expected timeline and team size? | Shapes architecture and process rigor. | 1 dev / small team / scale-up / enterprise |
| Is this greenfield or modernization? | Determines risk profile and migration strategy. | Greenfield / Strangler / Rewrite |
| What are the branding/design constraints? | Affects design system and tooling. | Design system, Figma, component lib |
| What third-party dependencies are required? | Licensing, cost, and lock-in exposure. | SaaS APIs, SDKs, open-source libs |

---

## 2. Tech Stack & Architecture

| Question | Why it matters | Default/Options |
|---|---|---|
| Which language(s) for the backend? | Talent, ecosystem, performance. | TypeScript/Node, Go, Rust, Python, Java/Kotlin, C# |
| Which frontend framework? | Hiring pool, DX, performance. | React 19, Vue 3.6, Angular 21, Svelte 5, SolidJS |
| Which meta-framework for rendering? | SSR/SSG, SEO, routing, data loading. | Next.js 16 (RSC/PPR), Nuxt 3, SvelteKit, Astro 5, Remix/RR7 |
| Monorepo or polyrepo? | Shared code vs independent deploy. | Turborepo/Nx/Bazel (mono) vs multi-repo |
| Server-first vs SPA-first? | SEO, TTI, bundle size. | RSC/SSR default; hydrate only interactive islands |
| API style: REST, GraphQL, gRPC, tRPC? | Client needs, typing, performance. | REST, GraphQL, gRPC, tRPC/OpenAPI |
| Which datastore(s)? | Consistency, scale, query shape. | Postgres, MySQL, MongoDB, DynamoDB, SQLite |
| Need a vector/embedding store? | AI search, RAG, semantic recall. | pgvector, Pinecone, Weaviate, Qdrant |
| Caching layer? | Reduces latency and DB load. | Redis, Memcached, CDN, in-memory |
| Search engine? | Full-text / faceted search at scale. | Postgres FTS, OpenSearch/Elasticsearch, Typesense |
| Message queue / async? | Decoupling, retries, backpressure. | SQS/Kafka/NATS/RabbitMQ/Redis Streams |
| Need mobile / native? | Reach and offline support. | React Native, Flutter, Expo, native (Swift/Kotlin) |
| Edge / serverless runtime? | Latency and cost at the edge. | Cloudflare Workers, Vercel Edge, Lambda@Edge |
| Real-time (websockets/streaming)? | Live UX, collaboration. | WebSockets, SSE, WebRTC, partykit |
| Which AI/LLM provider & model? | Capability, cost, data residency. | OpenAI, Anthropic, Gemini, open (Llama/Mistral vLLM) |
| TypeScript baseline? | Type safety for humans and AI agents. | Strict TS everywhere (plain JS treated as legacy) |
| Design system / UI kit? | Consistency and velocity. | Tailwind + shadcn, MUI, Radix, Chakra, custom |

---

## 3. Infrastructure & DevOps

| Question | Why it matters | Default/Options |
|---|---|---|
| Which cloud provider? | Existing contracts, region, services. | AWS, GCP, Azure, Cloudflare, Fly.io, Render |
| Infrastructure as Code tool? | Reproducible, reviewable infra. | Terraform, Pulumi, AWS CDN, OpenTofu |
| CI/CD platform? | Build/test/deploy automation. | GitHub Actions, GitLab CI, CircleCI, Buildkite |
| Containerization strategy? | Portability and scaling. | Docker + Compose; Kubernetes/EKS/GKE; serverless |
| Orchestration needed? | Scale, multi-service topology. | K8s, ECS/Fargate, Nomad, none (serverless) |
| Environments (dev/staging/prod)? | Safe promotion, parity. | 3+ envs with isolated data |
| Observability stack? | Debugging, SLOs, incident response. | OpenTelemetry + Grafana/Loki/Tempo, Datadog, Honeycomb |
| Log aggregation & tracing? | Root-cause analysis. | OTel traces, structured logs, sampling |
| Alerting & on-call routing? | MTTR, ownership. | Prometheus Alertmanager, PagerDuty, Grafana OnCall |
| Secret management? | Avoid leaked credentials. | Vault, AWS Secrets Manager, Doppler, env-injected |
| How are secrets injected at runtime? | No secrets in repo or images. | OIDC, secret refs, SSM params |
| Feature flag system? | Progressive rollout, kill switch. | LaunchDarkly, PostHog, Unleash, Flagsmith |
| CDN / edge caching? | Global perf and offload. | Cloudflare, Fastly, CloudFront |
| Backup & disaster recovery plan? | RPO/RTO guarantees. | Automated snapshots, cross-region, tested restores |
| Container registry & artifact store? | Secure supply chain. | ECR/GHCR, Artifactory, npm registry |

---

## 4. Security & Compliance

| Question | Why it matters | Default/Options |
|---|---|---|
| Authentication approach? | Identity, SSO, MFA. | Auth0/Okta, Clerk, NextAuth, OIDC/SAML |
| Authorization model? | Least privilege, multi-tenancy. | RBAC, ABAC, ReBAC, policy-as-code (OPA) |
| PII / sensitive data handling? | Breach and legal exposure. | Tokenization, encryption, data minimization |
| Encryption at rest & in transit? | Compliance baseline. | TLS 1.3, KMS-managed keys, mTLS |
| Relevant compliance regimes? | Legal and procurement requirements. | GDPR, HIPAA, SOC 2, PCI-DSS, CCPA |
| Data residency / region constraints? | GDPR, sovereignty. | EU-only, US-only, multi-region |
| Audit logging & traceability? | Forensics, compliance evidence. | Immutable audit log, event sourcing |
| Dependency vulnerability scanning? | Supply-chain risk. | Snyk, Dependabot, Trivy, OSV-Scanner |
| SBOM generation? | Compliance and incident response. | CycloneDX, SPDX in CI |
| Rate limiting & abuse protection? | DDoS, cost, scraping. | WAF, API gateway limits, bot defense |
| CSP / security headers? | XSS and injection defense. | Strict CSP, HSTS, SRI |
| Penetration testing cadence? | Assurance before launch. | Pre-launch + quarterly |

---

## 5. Developer Experience & Tooling

| Question | Why it matters | Default/Options |
|---|---|---|
| Package manager? | Reproducibility, speed, lockfiles. | pnpm, npm, bun, yarn (avoid mixed) |
| Linting & formatting? | Consistent code, fewer review cycles. | Biome/ESLint + Prettier, Ruff, Clippy |
| Type-checking in CI? | Catch errors pre-merge. | tsc --noEmit, strict mode |
| Test framework & levels? | Confidence and safety net. | Vitest/Jest, Playwright, pytest, k6 |
| Coverage expectations? | Quality gate. | 70-90% on unit; e2e smoke required |
| Pre-commit hooks? | Block bad commits locally. | Lefthook, Husky + lint-staged |
| AI coding-agent setup? | Leverage 2026 agent workflows. | AGENTS.md + skills + hooks |
| Agent instruction file strategy? | Cross-tool consistency, no drift. | AGENTS.md (source of truth) + CLAUDE.md import |
| Skills / plugins for agents? | Reusable task workflows on demand. | SKILL.md per workflow, plugins for shared |
| Hooks for agents? | Deterministic guardrails. | lint/test on change, no-push-without-tests |
| Documentation approach? | Onboarding and maintenance. | Markdown/Starlight, ADRs, README + AGENTS.md |
| Monorepo tooling? | Fast, cached builds. | Turborepo, Nx, Bazel, moon |
| Local dev experience? | Onboarding speed. | docker-compose, devcontainers, Hot Reload |
| Codegen tooling? | Less boilerplate, typed contracts. | OpenAPI/gen, GraphQL codegen, orval |
| Editor/IDE standardization? | Shared config, fewer surprises. | VS Code + extensions, Zed, JetBrains |

---

## 6. Data & AI Strategy

| Question | Why it matters | Default/Options |
|---|---|---|
| Data model & ownership? | Correctness and migrations. | Relational + migrations (Drizzle/Prisma), document |
| Migration tooling & rollback? | Safe schema evolution. | Flyway, Liquibase, Drizzle-Kit, Alembic |
| Will the product include AI features? | Scope and risk. | Chat, RAG, agents, classification, summarization |
| LLM integration pattern? | Cost, latency, control. | Direct API, gateway (LiteLLM), self-hosted vLLM |
| RAG vs fine-tuning? | Knowledge freshness vs behavior. | RAG + vector store; LoRA for niche tasks |
| Eval & guardrail framework? | Quality and safety of AI output. | RAGAS, LangSmith, promptfoo, guardrails |
| Prompt/version management? | Reproducibility of AI behavior. | Prompt registry, config-as-code |
| Cost controls on AI spend? | Prevent runaway bills. | Token caps, caching, model tiering |
| Data privacy for AI inputs? | Prevent leaking PII to providers. | Redaction, zero-retention, self-host |
| Observability for AI calls? | Debugging hallucination/latency. | Trace per call, token metrics, eval dashboards |

---

## 7. Team & Process

| Question | Why it matters | Default/Options |
|---|---|---|
| Branching strategy? | Merge safety, release cadence. | Trunk-based, GitHub Flow, GitFlow |
| Code review requirements? | Quality, knowledge sharing. | Min 1-2 approvers, required checks |
| Commit/PR conventions? | History clarity, releases. | Conventional Commits, squash merge |
| Issue/task tracking? | Visibility and planning. | GitHub Issues, Linear, Jira, Shortcut |
| Definition of Done? | Shared completion bar. | Tests + review + docs + dashboards |
| On-call & incident process? | Reliability ownership. | PagerDuty, incident runbook, postmortems |
| Ownership model (CODEOWNERS)? | Clear accountability. | Per-service/module owners |
| Knowledge sharing & docs? | Bus factor reduction. | ADRs, internal wiki, pairing |
| Release cadence? | Feedback loop. | Continuous, weekly, scheduled |
| AI agent usage policy in CI? | Safe automation. | Agent reviews PRs, guarded permissions |

---

## 8. Cost & Scaling

| Question | Why it matters | Default/Options |
|---|---|---|
| What is the monthly infra budget? | Sets architecture ceiling. | Fixed cap, usage-based alerts |
| Scaling targets (users/RPS/data)? | Capacity planning. | DAU, peak RPS, TB stored |
| Horizontal vs vertical scaling? | Statelessness, cost. | Stateless + autoscale; scale DB separately |
| SLOs / SLAs? | User expectations, penalties. | 99.9% uptime, p95 < 300ms |
| Performance budget? | UX and Core Web Vitals. | LCP < 2.5s, bundle < 200KB |
| Cost monitoring & alerts? | Avoid surprises. | Cloud cost dashboards, Finout, infracost |
| Caching to reduce cost? | Lower compute/DB bills. | CDN, Redis, query caching |
| Idle/non-prod cost controls? | Waste reduction. | Auto-suspend, scheduled shutdown |

---

## 9. Modernization-Specific

| Question | Why it matters | Default/Options |
|---|---|---|
| What is the current codebase state? | Baseline for risk. | Audit: languages, deps, tests, debt |
| Strangler-fig vs big-bang rewrite? | Risk and continuity. | Incremental (strangler) preferred |
| What is the highest-risk module? | Prioritize safe extraction. | Profiling, churn, failure history |
| Test coverage of legacy code? | Safety net before change. | Characterization tests first |
| Data migration & parity plan? | No data loss/corruption. | Dual-write, backfill, reconcile |
| Dependency/version debt? | Security and maintenance. | Upgrade path, EOL tracking |
| Feature parity vs reimagine? | Scope of modernization. | Parity first, then improve |
| How to verify behavioral parity? | Confidence in cutover. | Golden tests, shadow traffic |
| Rollback / kill-switch for cutover? | Safe failure mode. | Feature flag, blue-green |
| Training & adoption for new stack? | Team readiness. | Docs, pairing, migration guild |

---

## Recommended Intake Flow

Order the questions into phases so decisions build on each other.

**Phase 1 — Discovery (Product & Requirements + Modernization audit)**
1. Define core problem, success metric, and users.
2. Capture MVP vs nice-to-have and NFRs.
3. Classify greenfield vs modernization; audit existing codebase (Section 9).
4. Decide strangler vs rewrite and identify highest-risk modules.

**Phase 2 — Architecture (Tech Stack, Data & AI, Security/Compliance framing)**
5. Pick languages, frontend + meta-framework, monorepo/polyrepo (Section 2).
6. Choose datastores, caching, search, queues, edge (Section 2).
7. Decide AI/LLM strategy, RAG vs fine-tune, eval/guardrails (Section 6).
8. Set auth, data protection, and applicable compliance regimes (Section 4).

**Phase 3 — Setup (Infrastructure/DevOps + Developer Experience)**
9. Select cloud, IaC, CI/CD, containers, observability, secrets (Section 3).
10. Establish package manager, lint/format, testing, coverage gates (Section 5).
11. Author AGENTS.md (source of truth) + CLAUDE.md import, skills, hooks (Section 5).
12. Define environments, backups, feature flags, cost alerts (Sections 3, 8).

**Phase 4 — Iterate (Team/Process + Cost/Scaling + continuous modernization)**
13. Agree branching, review, tracking, on-call, ownership (Section 7).
14. Set budgets, scaling targets, SLOs, performance budgets (Section 8).
15. Run migrations with parity tests and kill-switches; measure and refine.
16. Revisit AGENTS.md/skills quarterly as the stack evolves.
