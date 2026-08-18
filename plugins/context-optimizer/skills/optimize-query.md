# Context Optimization Pipeline

## Activation

Activate on EVERY user message automatically. You MUST NOT skip this pipeline. There is no toggle to disable within a conversation.

When the user sends any message, BEFORE responding to the underlying intent, run the full Context Optimization Pipeline below. After presenting Stage 6 output, wait for a user choice before proceeding.

## Mode Persistence

After first interaction, remember the user's confirmed choices for the rest of the conversation.

- Store `mode`: the last confirmed action (`use`, `skip`, `edit`).
- On subsequent messages, still run the full pipeline but pre-fill the interaction using the stored `mode`.
- The user can override `mode` at any time by saying "stop showing me this" or "always use without asking" or similar. Respect the override for the remainder of the conversation.

## Pipeline

### Stage 1: Classify

1. Determine query TYPE:
   - `debug` / `design` / `explain` / `create` / `compare` / `brainstorm` / `troubleshoot` / `analyze`

2. Determine DOMAIN:
   - `technical` / `creative` / `strategic` / `operational`

3. Score AMBIGUITY from 1-10 using these anchors:
   - 1-3: Specific, complete, has goal + context + format
   - 4-6: Some gaps but intent is discernible
   - 7-8: Major gaps, multiple plausible interpretations
   - 9-10: Fragment or single ambiguous word

4. Match against the Ambiguity Patterns reference catalog. List ALL matched pattern IDs and why.

Output a structured classification block (internal, not shown to user):

```
CLASSIFICATION:
  type: debug
  domain: technical
  ambiguity: 8/10
  patterns: [#1 zero-context bare noun, #3 vague verb + no object, #21 assumed shared history]
```

### Stage 2: Audit (Gap Analysis)

Check each dimension independently. For each, score: `explicit`, `partial`, or `missing`.

| Dimension   | Checks |
|-------------|--------|
| GOAL        | What is the desired outcome? What problem are we solving? |
| CONTEXT     | Framework, version, environment, existing code, dependencies |
| FORMAT      | How should the answer be structured? (code/list/report/etc) |
| AUDIENCE    | Who is this for? (junior/senior/manager/non-technical) |
| CONSTRAINTS | Time, budget, scope limits, must-not-break, compatibility |

For each `missing` or `partial` dimension, generate exactly ONE specific clarifying question. Store these questions for the Edit Flow.

### Stage 3: Assumption Inventory

List all implicit assumptions the query makes. Label each:

- `[CRITICAL]` — If this assumption is wrong, the answer will be wrong
- `[SAFE]` — Reasonable default, low risk
- `[RISKY]` — Ambiguous, could go either way

### Stage 4: Alternative Interpretations

Generate 3 distinct interpretations of what the user might mean. For each: brief paraphrase + confidence probability (p) that sums to 1.0 across all 3.

Interpretation A: "..." (p=0.6)
Interpretation B: "..." (p=0.3)
Interpretation C: "..." (p=0.1)

### Stage 5: Reconstruct (Build Optimized Query)

Construct a new query that fills ALL identified gaps. Use this structure:

**Role**: expertise level + persona based on domain
**Goal**: explicit, measurable outcome
**Context**: all known parameters, frameworks, versions, environment
**Task**: specific, actionable instructions
**Format**: output structure specification
**Constraints**: explicit boundaries and must-not-break rules

Fill known values from the user's original query. For gaps that remain (unknowns), include bracketed placeholders like `[unknown]` that clearly signal to the user what specific information would further improve the query.

### Stage 6: Present

Display a formatted block to the user:

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Context Optimizer — Expanded & Optimized Query          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  EXPANDED QUERY                                             │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  {full reconstructed query from Stage 5}                     │
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  WHAT CHANGED                                               │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  🟢 Added explicit context: ...                              │
│  🟡 Surfaced assumption: ...                                │
│  🔴 Resolved ambiguity (pattern #X): ...                    │
│                                                             │
│  Classified as: {type} in {domain} domain                    │
│  Ambiguity score: {score}/10                                 │
│                                                             │
│  ┌────────────────────────────────┐                         │
│  │ [y] Use   [n] Skip   [e] Edit  │                         │
│  └────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

The `[y]` `[n]` `[e]` options MUST be rendered as interactive buttons (markdown code fences with bracketed options) that the user can type.

## Edit Flow

When user selects `[e] Edit`:

1. Take the clarifying questions generated during Stage 2 audit
2. Present them to the user one at a time, waiting for each answer
3. After all answers received, re-run Stages 3 through 6 with the additional context
4. Present the updated result with the same `[y]` `[n]` `[e]` choices

## On User Choice

- `[y] Use` → Store `mode: use`. Proceed to answer the Stage 5 optimized query. Begin the response as if the optimized query was the user's original message. Do NOT prefix with "I optimized your query..." — the user already saw the diff and explicitly confirmed.
- `[n] Skip` → Store `mode: skip`. Answer the original query without optimization, but prefix with a one-line note: "Note: Context Optimizer identified this query as ambiguous (score {score}/10). Type `reoptimize` to run the pipeline."
- `[e] Edit` → Enter Edit Flow above.
- `reoptimize` → Re-run the full pipeline on the current query and present Stage 6 again.
- `stop showing this` → Stop running the pipeline. Answer queries directly without optimization for the remainder of the conversation.
- `always expand` / `always use without asking` → Run the pipeline silently and use the expanded query directly without presenting Stage 6. Skip the `[y]` `[n]` `[e]` prompt.

## Interaction Rules

1. When the user types a single letter `y`, `n`, or `e` on its own line within 5 exchanges after Stage 6 is displayed, treat it as a choice for `[y]`, `[n]`, or `[e]` respectively.
2. When the user types `reoptimize`, re-run the full pipeline on the most recent query.
3. When the user types `stop showing this`, disable the pipeline for the rest of the conversation.
4. When the user types `always expand`, run silently and auto-use.

## Examples

### Example 1: Technical Debug

User: "fix the login"

Internal classification:
```
type: debug
domain: technical
ambiguity: 9/10
patterns: [#1 zero-context bare noun, #3 vague verb + no object, #9 missing conditional]
```

Gaps: GOAL missing, CONTEXT missing, FORMAT missing, AUDIENCE missing, CONSTRAINTS missing
Assumptions: [CRITICAL] language/framework unknown, [CRITICAL] what "broken" means, [RISKY] frontend vs backend
Interpretations: frontend bug (p=0.5), backend issue (p=0.3), config problem (p=0.2)

Presented output:

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Context Optimizer — Expanded & Optimized Query          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  EXPANDED QUERY                                             │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  Act as a senior full-stack engineer.                       │
│                                                             │
│  I need to debug a login failure in [system name].          │
│  Current stack: [language, framework, auth library].        │
│  Specific symptom: [what happens when user tries to log in].│
│  Expected behavior: users authenticate successfully.        │
│                                                             │
│  Help me:                                                   │
│  1. Identify root cause                                     │
│  2. Provide fix options with tradeoffs                      │
│  3. Show code example for recommended fix                   │
│                                                             │
│  Output as: diagnostic steps with code snippets.            │
│  Constraint: must not break existing sessions.              │
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  WHAT CHANGED                                               │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  🟢 Added: system context placeholder                       │
│  🟢 Added: output format (diagnostic + code)                │
│  🟢 Added: constraint (no session breakage)                 │
│  🟡 Surfaced: expecting auth library in use                 │
│  🟡 Surfaced: expecting frontend/backend split              │
│  🔴 Resolved "login" → login failure debugging              │
│  🔴 Resolved "fix" → root cause + fix + tradeoffs           │
│                                                             │
│  Classified as: debug in technical domain                    │
│  Ambiguity score: 9/10                                      │
│                                                             │
│  ┌────────────────────────────────┐                         │
│  │ [y] Use   [n] Skip   [e] Edit  │                         │
│  └────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

### Example 2: Creative Design

User: "make the dashboard better"

Internal classification:
```
type: brainstorm
domain: creative
ambiguity: 8/10
patterns: [#3 vague verb + no object, #6 unspecified scope, #14 metric without measure]
```

Presented output:

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Context Optimizer — Expanded & Optimized Query          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  EXPANDED QUERY                                             │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  Act as a senior UX/UI designer.                            │
│                                                             │
│  I need to improve the dashboard for [app name].            │
│  Current pain points: [user feedback, metrics].             │
│  Target metrics: [engagement, task completion, NPS].        │
│  Constraints: [brand guidelines, timeline, tech stack].     │
│                                                             │
│  Provide:                                                   │
│  • 3 concrete improvement suggestions                       │
│  • Mockup descriptions for each                             │
│  • Rationale (which metric each improves)                   │
│  • Implementation effort estimate (low/med/high)            │
│                                                             │
│  Output as: comparison table with recommendation.           │
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  WHAT CHANGED                                               │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  🟢 Added: designer persona                                 │
│  🟢 Added: output format (comparison table)                  │
│  🟢 Added: specific sub-ask format (3 suggestions)          │
│  🟡 Surfaced: target metrics (engagement/completion)        │
│  🔴 Resolved "better" → measurable UX improvements          │
│  🔴 Resolved "dashboard" → [app name] dashboard             │
│                                                             │
│  Classified as: brainstorm in creative domain                │
│  Ambiguity score: 8/10                                      │
│                                                             │
│  ┌────────────────────────────────┐                         │
│  │ [y] Use   [n] Skip   [e] Edit  │                         │
│  └────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

### Example 3: Strategic Decision

User: "which database should we use"

Internal classification:
```
type: analyze
domain: strategic
ambiguity: 7/10
patterns: [#25 question without context, #19 no audience marker]
```

Presented output:

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Context Optimizer — Expanded & Optimized Query          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  EXPANDED QUERY                                             │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  Act as a solutions architect.                              │
│                                                             │
│  We need to select a database for [app type / workload].    │
│  Requirements:                                              │
│  - Data model: [relational / document / graph / time-series]│
│  - Scale: [users, data volume, throughput]                  │
│  - Consistency: [strong / eventual]                         │
│  - Current stack: [languages, cloud provider, infra]        │
│  - Team expertise: [primary language, DB experience]        │
│                                                             │
│  Compare these options: [candidates] across:                │
│  • Performance at our scale                                 │
│  • Operational complexity                                   │
│  • Cost (licensing + infra + ops)                           │
│  • Ecosystem fit with current stack                         │
│                                                             │
│  Output as: decision matrix with weighted criteria.         │
│  Constraint: decision needed by [timeline].                 │
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  WHAT CHANGED                                               │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  🟢 Added: solutions architect persona                      │
│  🟢 Added: evaluation criteria (perf, ops, cost, fit)      │
│  🟢 Added: output format (decision matrix)                  │
│  🟡 Surfaced: data model type assumption                    │
│  🔴 Resolved "which database" → multi-factor comparison     │
│                                                             │
│  Classified as: analyze in strategic domain                  │
│  Ambiguity score: 7/10                                      │
│                                                             │
│  ┌────────────────────────────────┐                         │
│  │ [y] Use   [n] Skip   [e] Edit  │                         │
│  └────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

### Example 4: Operational / DevOps

User: "deploy the app"

Internal classification:
```
type: troubleshoot
domain: operational
ambiguity: 6/10
patterns: [#1 zero-context bare noun, #8 unspecified scope]
```

Presented output:

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Context Optimizer — Expanded & Optimized Query          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  EXPANDED QUERY                                             │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  Act as a DevOps engineer.                                  │
│                                                             │
│  I need to deploy [app name] to [environment].              │
│  Current deployment method: [CI/CD pipeline / manual].     │
│  Target platform: [cloud provider / on-prem / k8s].        │
│  Artifact: [Docker image / binary / package].              │
│                                                             │
│  Provide:                                                   │
│  • Step-by-step deployment instructions                    │
│  • Rollback plan                                           │
│  • Verification steps (health checks)                      │
│                                                             │
│  Constraint: [downtime tolerance: zero / minimal].         │
│  Output as: numbered runbook with commands.                 │
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  WHAT CHANGED                                               │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  🟢 Added: DevOps persona                                   │
│  🟢 Added: deployment method placeholder                    │
│  🟢 Added: rollback and verification steps                  │
│  🟢 Added: output format (numbered runbook)                 │
│  🟡 Surfaced: deployment method assumption                  │
│  🔴 Resolved "deploy" → runbook with rollback               │
│                                                             │
│  Classified as: troubleshoot in operational domain           │
│  Ambiguity score: 6/10                                      │
│                                                             │
│  ┌────────────────────────────────┐                         │
│  │ [y] Use   [n] Skip   [e] Edit  │                         │
│  └────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

### Example 5: Vague Fragment

User: "error handling"

Internal classification:
```
type: analyze
domain: technical
ambiguity: 10/10
patterns: [#6 fragment-only]
```

Presented output:

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Context Optimizer — Expanded & Optimized Query          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  EXPANDED QUERY                                             │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  Act as a senior software engineer.                         │
│                                                             │
│  I need to design error handling for [project / system].    │
│  Language: [programming language].                          │
│  Stack: [framework, runtime].                               │
│                                                             │
│  Cover these aspects:                                       │
│  1. Error types — custom error hierarchy or enum            │
│  2. Propagation strategy — return vs throw vs monad         │
│  3. User-facing messages — tone, localization               │
│  4. Logging — structured, severity levels                   │
│  5. Recovery — retry, fallback, circuit breaker             │
│  6. Monitoring — alerting on error rates                    │
│                                                             │
│  Output as: design document with implementation patterns.   │
│                                                             │
│  ═══════════════════════════════════════════════════════     │
│  WHAT CHANGED                                               │
│  ═══════════════════════════════════════════════════════     │
│                                                             │
│  🟢 Added: senior engineer persona                          │
│  🟢 Added: 6-part error handling framework                  │
│  🟢 Added: output format (design document)                  │
│  🟢 Added: language and stack placeholders                  │
│  🔴 Resolved "error handling" → full error strategy design  │
│                                                             │
│  Classified as: analyze in technical domain                  │
│  Ambiguity score: 10/10                                     │
│                                                             │
│  ┌────────────────────────────────┐                         │
│  │ [y] Use   [n] Skip   [e] Edit  │                         │
│  └────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```
