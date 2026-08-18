# Ambiguity Pattern Catalog

Reference for Stage 1 of the Context Optimization Pipeline. When classifying a query, scan this catalog and list all matching pattern IDs.

## Structural (Patterns 1-10)

Sentence structure itself is missing critical elements.

### 1. Zero-context bare noun
- **Example**: "the login"
- **Triggers**: Starts with "the" + single noun
- **Missing**: What system? What layer? What symptom? Expected state?
- **Reconstruction**: "Debug the login flow for [system] where [symptom]. Expected behavior: [normal flow]. Actual: [broken behavior]."

### 2. Orphan pronoun
- **Example**: "it doesn't work", "this is broken"
- **Triggers**: "it", "this", "that", "these" without antecedent
- **Missing**: What is the referent? Working state vs broken state?
- **Reconstruction**: "Debug [specific component]. Current behavior: [symptom]. The referent was ambiguous: [resolved as]."

### 3. Vague verb + no object
- **Example**: "fix it", "make it better", "improve this"
- **Triggers**: Verb + "it/this/that" without specificity
- **Missing**: Expected outcome? Current state? Acceptance criteria?
- **Reconstruction**: "Improve [component] by [metric]. Current: [baseline]. Target: [goal]. Constraints: [boundaries]."

### 4. Dangling modifier
- **Example**: "running the app it crashes"
- **Triggers**: Participial phrase + ambiguous subject
- **Missing**: What exactly crashes? Under what conditions? What changed?
- **Reconstruction**: "When [action] on [component], [symptom] occurs. Environment: [OS/version/stack]. Recent changes: [relevant diffs]."

### 5. Missing subject
- **Example**: "should be faster", "needs better error handling"
- **Triggers**: No explicit "who/what" before modal verb
- **Missing**: Subject of statement? Responsible party? Scope?
- **Reconstruction**: "I need [subject] to [property]. Currently: [baseline]. Desired: [target]. Domain: [technical/design/ops]."

### 6. Fragment-only
- **Example**: "error handling", "database performance", "api auth"
- **Triggers**: Bare phrase, no verb, no sentence structure
- **Missing**: Everything — treat as maximum ambiguity
- **Reconstruction**: Act as senior [domain] engineer. Design/analyze/implement [topic] for [system]. Requirements: [unknown — generate 3 plausible specs]."

### 7. Implicit comparison
- **Example**: "make it faster", "cheaper", "more reliable"
- **Triggers**: Comparative adjective without baseline or target
- **Missing**: Baseline metric? Target metric? Measurement method?
- **Reconstruction**: "Optimize [system] for [metric]. Baseline: [current value]. Target: [desired value]. Measured by: [method]. Tradeoffs: [acceptable/unacceptable]."

### 8. Unspecified scope
- **Example**: "everything is broken", "all of it", "the whole thing"
- **Triggers**: "everything", "everyone", "all", "nothing", "nobody"
- **Missing**: Which subset? What's the boundary? Severity distribution?
- **Reconstruction**: "[X%] of [system] is [affected]. Specifically: [subcomponents]. Not affected: [subcomponents]. Severity: [critical/major/minor]."

### 9. Missing conditional
- **Example**: "when I click it breaks"
- **Triggers**: "when X then Y" without precondition context
- **Missing**: What state was the system in before? What sequence led here?
- **Reconstruction**: "Prerequisite state: [before state]. Action: [exact click sequence]. Result: [error/break]. Expected: [normal result]. Environment: [browser/OS/version]."

### 10. Conjunction explosion
- **Example**: "add auth and tests and logging and monitoring"
- **Triggers**: Multiple "and" clauses with no ordering or dependencies
- **Missing**: Priority? Dependencies? Which are new vs improvements?
- **Reconstruction**: "Implement these features in priority order: 1. [primary] because [reason]. 2. [secondary] because [reason]. Dependencies: [feature A blocks feature B]."

## Semantic (Patterns 11-18)

Words whose meaning depends on context.

### 11. Polysemy
- **Example**: "the bridge", "the agent", "the table"
- **Triggers**: Common noun that has different meanings across contexts
- **Missing**: Which sense is intended? Domain disambiguation?
- **Reconstruction**: "Work with [term] in the context of [domain: networking/AI/DB/UI]. Mean: [disambiguated meaning]. Related: [related concepts in same domain]."

### 12. Jargon collision
- **Example**: "the agent", "the action", "the event", "the pipe"
- **Triggers**: Term used differently across technical domains
- **Missing**: Which technical community's jargon applies here?
- **Reconstruction**: "Handle [term] according to [community: AI monitoring / CI/CD / event-driven / Unix]. Meaning: [disambiguated]. Non-meaning: [what it does NOT mean]."

### 13. Underspecified verb
- **Example**: "process the data", "handle the request", "manage users"
- **Triggers**: Generic verb that could mean many specific operations
- **Missing**: Which specific sub-operation? Input state? Desired output?
- **Reconstruction**: "[Operation type: parse/transform/aggregate/validate/filter] the [data type] from [source] into [target]. Rules: [transformation rules]. Edge cases: [known edge cases]."

### 14. Metric without measure
- **Example**: "better performance", "good quality", "fast response"
- **Triggers**: Qualitative adjective that maps to multiple unrelated metrics
- **Missing**: Which metric axis? How is it measured? What is good enough?
- **Reconstruction**: "Improve [metric: p95 latency / throughput / error rate / memory / bundle size]. Current: [baseline]. Target: [goal]. Measuring via: [tool/method]."

### 15. Domain leak
- **Example**: "the table" (DB vs UI vs data structure)
- **Triggers**: Term that is homonymous across sub-domains
- **Missing**: Which sub-domain? Specific field context?
- **Reconstruction**: "Work with [term] in [sub-domain: database schema / UI component / data structure / spreadsheet]. Schema/definition: [clarified structure]."

### 16. Version ambiguity
- **Example**: "the new version", "latest", "old one", "current"
- **Triggers**: Temporal qualifier without reference point
- **Missing**: New relative to what reference? Release date? What changed?
- **Reconstruction**: "Use version [explicit version] released [date]. Changes from [previous version]: [summary of changes]. Compatibility: [breaking changes]."

### 17. False cognate
- **Example**: "implement security"
- **Triggers**: Broad term that encompasses many specific sub-domains
- **Missing**: Which specific sub-domain of the broad concept?
- **Reconstruction**: "Implement [specific sub-domain: auth / encryption / compliance / monitoring / secrets management] for [system]. Threat model: [assets, actors, trust boundary]."

### 18. Generification
- **Example**: "the thing", "the stuff", "that part"
- **Triggers**: Placeholder noun replacing a specific concept
- **Missing**: What specific concept was placeholder? Context clues?
- **Reconstruction**: "Work with [inferred concept from context cues]. If wrong, intended referent is: [unknown — ask user]. Closest contextual match: [reasoning]."

## Pragmatic (Patterns 19-25)

Intent, audience, or constraints are missing.

### 19. No audience marker
- **Example**: "explain this", "write about"
- **Triggers**: No audience specification
- **Missing**: Who is the target? What's their baseline knowledge?
- **Reconstruction**: "Explain [topic] to a [audience: junior engineer / manager / non-technical stakeholder]. Assume they know: [prerequisites]. Assume they do NOT know: [excluded knowledge]. Use [analogies / technical depth / business language]."

### 20. No output format
- **Example**: "tell me about it", "describe"
- **Triggers**: No format specification
- **Missing**: Paragraph? Bullets? Code? Diagram? Table? Decision matrix?
- **Reconstruction**: "Present as [format: structured report / step-by-step / comparison table / code with explanation / architecture diagram description]. Length: [concise / detailed / exhaustive]."

### 21. Assumed shared history
- **Example**: "as I mentioned earlier", "like we discussed"
- **Triggers**: Reference to prior conversation without recap
- **Missing**: What was discussed? Key decisions? Rationale?
- **Reconstruction**: "Continuing from prior context: [summary of relevant prior discussion]. Decision made: [prior decision]. Open questions: [unresolved items]. New request: [specific ask]."

### 22. Undefined success
- **Example**: "make it good", "do it right", "properly"
- **Triggers**: Evaluation term without criteria
- **Missing**: What defines success? Acceptance criteria? Exit criteria?
- **Reconstruction**: "Deliver [work product] meeting these criteria: 1. [criterion A with measurable bar]. 2. [criterion B with measurable bar]. Verified by: [test/review method]. Done when: [definition of done]."

### 23. Implicit constraint
- **Example**: "I need this cheap", "fast", "simple"
- **Triggers**: Constraint word without bounds
- **Missing**: What type of constraint? What are the actual bounds?
- **Reconstruction**: "Constraint: [time / budget / complexity / ops cost]. Bound: [specific value or range]. Tradeoff priority: [which constraint matters most when they conflict]."

### 24. Conflicting intent
- **Example**: "easy but powerful", "cheap and enterprise-grade"
- **Triggers**: Two opposing requirements without tradeoff acknowledgment
- **Missing**: Where on the tradeoff curve? Which wins in conflict?
- **Reconstruction**: "Requirements: [A] and [B] which conflict on [tradeoff axis]. Primary: [A] over [B] when [condition]. Secondary: [B] over [A] when [condition]. Fallback: [compromise strategy]."

### 25. Question without context
- **Example**: "which one should I use?"
- **Triggers**: Interrogative without situational parameters
- **Missing**: Use for what? Under what constraints? Evaluated by what criteria?
- **Reconstruction**: "Select between [options] for [use case]. Selection criteria ranked: 1. [criterion]. 2. [criterion]. Constraints: [budget/stack/team/timeline]. Recommended: [option] because [reasoning]. Tradeoffs: [what you give up]."
