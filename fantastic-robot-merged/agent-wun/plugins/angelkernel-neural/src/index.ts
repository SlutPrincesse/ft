// AngelKernel Neural v4.0 — Main barrel export
export * from './types/index.js';
export { HookRegistry, HOOK_META } from './hooks/registry.js';
export { IntentClassifier } from './neural/engine.js';
export { AdaptiveRouter } from './neural/router.js';
export { CoherenceModel } from './neural/coherence.js';
export { NeuralEngine } from './neural/synthesize.js';
export { PatternDetector } from './auto-skill/detector.js';
export { SkillExtractor } from './auto-skill/extractor.js';
export { SkillLifecycle } from './auto-skill/lifecycle.js';
export { ErrorCorrection } from './error/correction.js';
export { MemoryCortex, L1WorkingMemory, L2EpisodicMemory, L3SemanticMemory, L4ProceduralMemory } from './cortex/index.js';
export { SwarmIntelligence } from './swarm/index.js';
export { UnityPipeline } from './pipeline/index.js';
export { PulseDaemon } from './pulse/index.js';
export { run, runBash, formatExecResult } from './utils/shell.js';
export { readJson, writeJson, appendLine, ensureDir, fileExists, generateId } from './utils/store.js';
