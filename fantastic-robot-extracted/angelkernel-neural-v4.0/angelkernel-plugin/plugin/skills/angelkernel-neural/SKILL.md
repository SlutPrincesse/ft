# AngelKernel Neural v4.0 — OpenCode Plugin Skill

This skill activates the AngelKernel Neural plugin for autonomous neural cognition within OpenCode.

## Commands

| Command | Action |
|---------|--------|
| `angel-kernel run <query>` | Full 7-phase pipeline (NEURAL→ENHANCE→ANALYZE→PLAN→EXECUTE→EVOLVE→REFLECT) |
| `angel-kernel pulse` | Run pulse daemon health/cleanup tick |
| `angel-kernel status` | System status overview |
| `angel-neural synthesize "<query>"` | Full neural pipeline: classify, route, learn |
| `angel-neural classify "<query>"` | Intent classification only |
| `angel-neural coherence` | Neural coherence check |
| `angel-cortex store "<content>" [source]` | Store to L2 episodic memory |
| `angel-cortex recall "<query>"` | Recall from memory cortex |
| `angel-cortex stats` | Memory cortex statistics |
| `angel-swarm consensus "<question>"` | Multi-agent democratic consensus |
| `angel-swarm parallel "<t1>" "<t2>"` | Parallel task execution |
| `angel-swarm debate "<topic>"` | Pro/con debate between agents |
| `angel-auto-skill scan` | Scan for extractable patterns |
| `angel-auto-skill extract <domain> <content>` | Extract new skill from pattern |
| `angel-auto-skill list` | List all auto-skills |
| `angel-hooks fire <event> [payload]` | Fire a hook event |
| `angel-hooks list [category]` | List registered hook events |
| `angel-hooks stats` | Hook system statistics |
| `angel-pulse tick` | Run pulse daemon tick |
| `angel-doctor` | Full system diagnostic |
| `angel-status` | System health overview |

## Neural Pipeline

Every query automatically flows through:
1. **NEURAL** — Intent classification → adaptive routing → context coherence
2. **ENHANCE** — Cortex recall → cross-chain discovery → auto-todo creation
3. **ANALYZE** — Intent confirmation → complexity estimation → domain detection
4. **PLAN** — Task decomposition → dependency graph → strategy selection
5. **EXECUTE** — Parallel execution → verification per step → auto-retry
6. **EVOLVE** — Self-improvement check → skill extraction → cortex store
7. **REFLECT** — Quality evaluation → performance benchmark → result persistence

## Auto-Skill Engine

Patterns repeating 3+ times auto-extract as skills:
```
angel-auto-skill scan          # Find patterns ready for extraction
angel-auto-skill extract <d> <c>  # Extract skill from pattern
angel-auto-skill verify <name>    # Mark skill as verified
angel-auto-skill activate <name>  # Activate skill
```

## Error Correction Loop

Errors follow Detect → Diagnose → Fix → Learn cycle:
- 10 common error patterns auto-detected (ENOENT, EACCES, ECONNREFUSED, etc.)
- 3+ repeats of same error triggers auto-fix suggestion
- All errors logged to correction DB for learning
