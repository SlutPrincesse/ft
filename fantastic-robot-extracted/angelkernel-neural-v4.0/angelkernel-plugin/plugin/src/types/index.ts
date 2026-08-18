// ============================================================================
// AngelKernel Neural — Complete TypeScript Type System
// ============================================================================

// ─── Plugin Configuration ─────────────────────────────────────────────────

export interface PluginConfig {
  homeDir: string;
  bashDir: string;
  profilesDir: string;
  storeDir: string;
  memoryDir: string;
  neuralDir: string;
  cortexDir: string;
  logDir: string;
  skillsDir: string;
  hooksDir: string;
  evolutionDb: string;
  metricsFile: string;
  hookRegistry: string;
  eventLog: string;
}

// ─── Neural Engine ────────────────────────────────────────────────────────

export type IntentCategory =
  | 'code'
  | 'research'
  | 'system'
  | 'memory'
  | 'evolution'
  | 'reasoning'
  | 'creative'
  | 'data'
  | 'learn';

export interface IntentConfig {
  patterns: string[];
  confidence: number;
  agents: SubagentMention[];
  skills: string[];
}

export interface IntentResult {
  intent: IntentCategory;
  confidence: number;
  agents: SubagentMention[];
  skills: string[];
}

export interface RouteEntry {
  intent: IntentCategory;
  count: number;
  successRate: number;
  agents: string;
  skills: string;
  lastRoute: number;
}

export type RouteCache = Record<string, RouteEntry>;

export interface ContextFrame {
  domain: string;
  content: string;
  weight: number;
  ts: number;
  decay: number;
}

export interface CoherenceCheck {
  name: string;
  status: 'ok' | 'warn' | 'critical';
  detail: string;
  contexts?: string[];
  routes?: string[];
}

export interface CoherenceReport {
  ts: number;
  iso: string;
  checks: CoherenceCheck[];
  health: 'optimal' | 'degraded' | 'critical';
  coherenceScore: number;
}

// ─── Auto-Skill Engine ────────────────────────────────────────────────────

export type SkillStatus = 'pending' | 'verified' | 'active' | 'failed' | 'deprecated';

export interface Skill {
  id: string;
  domain: string;
  triggerPattern: string;
  steps: string;
  source: string;
  extractedAt: number;
  status: SkillStatus;
  executionCount: number;
  successRate: number;
  version: number;
  verifiedAt?: number;
  activatedAt?: number;
}

export interface PatternEntry {
  key: string;
  source: string;
  content: string;
  count: number;
  firstSeen: number;
  lastSeen: number;
}

export interface SkillDb {
  skills: Record<string, Skill>;
  patterns: PatternEntry[];
  extractionHistory: ExtractionRecord[];
  stats: SkillStats;
}

export interface ExtractionRecord {
  ts: number;
  skill: string;
  domain: string;
  status: string;
}

export interface SkillStats {
  totalExtracted: number;
  totalActivated: number;
  totalFailed: number;
}

// ─── Universal Hooks ──────────────────────────────────────────────────────

export type HookCategory =
  | 'system'
  | 'neural'
  | 'skill'
  | 'error'
  | 'memory'
  | 'evolution'
  | 'pulse'
  | 'query'
  | 'unity'
  | 'agent'
  | 'swarm'
  | 'config'
  | 'plugin';

export type HookEvent =
  | 'system:init' | 'system:ready' | 'system:shutdown' | 'system:heartbeat' | 'system:degraded'
  | 'neural:intent-detected' | 'neural:route-selected' | 'neural:context-updated'
  | 'neural:coherence-check' | 'neural:learning-consolidated' | 'neural:pattern-detected'
  | 'skill:pattern-detected' | 'skill:extracted' | 'skill:verified' | 'skill:activated'
  | 'skill:failed' | 'skill:optimized' | 'skill:deprecated'
  | 'error:occurred' | 'error:diagnosed' | 'error:fixed' | 'error:learned' | 'error:escalated'
  | 'memory:store' | 'memory:recall' | 'memory:forget' | 'memory:consolidate'
  | 'memory:corrupted' | 'memory:repaired'
  | 'evolution:check' | 'evolution:cycle-start' | 'evolution:cycle-end' | 'evolution:milestone'
  | 'evolution:auto-heal' | 'evolution:refinement'
  | 'pulse:tick' | 'pulse:health-ok' | 'pulse:health-warn' | 'pulse:health-critical'
  | 'pulse:disk-cleanup' | 'pulse:log-rotate' | 'pulse:skill-extraction'
  | 'query:received' | 'query:analyzed' | 'query:planned' | 'query:executed'
  | 'query:complete' | 'query:error' | 'query:retry'
  | 'unity:enhance-start' | 'unity:enhance-end' | 'unity:analyze-start' | 'unity:analyze-end'
  | 'unity:plan-start' | 'unity:plan-end' | 'unity:execute-start' | 'unity:execute-end'
  | 'unity:step-complete' | 'unity:evolve-start' | 'unity:evolve-end'
  | 'unity:reflect-start' | 'unity:reflect-end'
  | 'agent:spawned' | 'agent:complete' | 'agent:error' | 'agent:timeout'
  | 'swarm:consensus-start' | 'swarm:consensus-end' | 'swarm:parallel-start'
  | 'swarm:parallel-end' | 'swarm:debate-start' | 'swarm:debate-end'
  | 'config:changed' | 'config:reloaded' | 'config:error'
  | 'plugin:enabled' | 'plugin:disabled' | 'plugin:installed' | 'plugin:error';

export interface HookMeta {
  category: HookCategory;
  priority: number;
  desc: string;
}

export interface HookPayload {
  [key: string]: unknown;
}

export interface HookHandler {
  (event: HookEvent, payload: HookPayload, timestamp: number): void | Promise<void>;
}

export interface EventLogEntry {
  iso: string;
  event: HookEvent;
  payload: HookPayload;
}

// ─── Error Correction ─────────────────────────────────────────────────────

export interface ErrorPattern {
  key: string;
  original: string;
  count: number;
  firstSeen: number;
  lastSeen: number;
  context: string;
}

export interface ErrorDb {
  created: string;
  patterns: ErrorPattern[];
  fixes: string[];
  learnings: string[];
}

// ─── Memory Cortex ─────────────────────────────────────────────────────────

export type MemoryTier = 'L1' | 'L2' | 'L3' | 'L4';

export interface L1Entry {
  key: string;
  value: string;
  ttl: number;
  createdAt: number;
  expiresAt: number;
}

export interface L2Entry {
  id: string;
  content: string;
  source: string;
  importance: number;
  metadata: Record<string, unknown>;
  createdAt: number;
  tags: string[];
}

export interface L3Entry {
  id: string;
  concept: string;
  content: string;
  source: string;
  confidence: number;
  related: string[];
  tags: string[];
  consolidatedAt: number;
  accessCount: number;
}

export interface L4Entry {
  id: string;
  name: string;
  domain: string;
  steps: string;
  source: string;
  version: number;
  successRate: number;
  createdAt: number;
  lastUsed: number;
}

export interface CortexStats {
  l1Count: number;
  l2Count: number;
  l3Count: number;
  l4Count: number;
  total: number;
  oldestEntry: number;
  newestEntry: number;
}

// ─── Swarm Intelligence ────────────────────────────────────────────────────

export interface SwarmVote {
  agent: string;
  choice: string;
  confidence: number;
  reasoning: string;
}

export interface SwarmConsensus {
  question: string;
  votes: SwarmVote[];
  consensus: string;
  agreementLevel: number;
  duration: number;
}

export interface SwarmDebate {
  topic: string;
  arguments: SwarmArgument[];
  conclusion: string;
  duration: number;
}

export interface SwarmArgument {
  agent: string;
  stance: 'pro' | 'con';
  points: string[];
  evidence: string[];
}

export interface SwarmParallelResult {
  taskId: string;
  task: string;
  result: string;
  success: boolean;
  duration: number;
}

// ─── Pipeline / Unity Engine ──────────────────────────────────────────────

export type PipelinePhase =
  | 'NEURAL'
  | 'ENHANCE'
  | 'ANALYZE'
  | 'PLAN'
  | 'EXECUTE'
  | 'EVOLVE'
  | 'REFLECT';

export type SubagentMention =
  | '@thinker' | '@coder' | '@researcher' | '@critic' | '@architect'
  | '@analyst' | '@artist' | '@speaker' | '@fast' | '@general'
  | '@executor' | '@writer' | '@explorer' | '@debugger';

export type ComplexityLevel = 'simple' | 'medium' | 'complex' | 'very_complex';

export interface PipelineStep {
  id: number;
  phase: PipelinePhase;
  agent: SubagentMention;
  task: string;
  toolType: string;
  needsMcp: boolean;
  usesMemory: boolean;
  dependencies: number[];
  parallel: boolean;
  verify: boolean;
}

export interface Plan {
  sessionId: string;
  query: string;
  intent: IntentCategory;
  complexity: ComplexityLevel;
  totalSteps: number;
  steps: PipelineStep[];
  parallelGroups: number[][];
  verificationPoints: number[];
  allSubsystemsActive: boolean;
  maxDepth: number;
  currentDepth: number;
}

export interface StepResult {
  step: number;
  agent: SubagentMention;
  task: string;
  success: boolean;
  attempts: number;
  toolType: string;
  output?: string;
  error?: string;
}

export interface PipelineResults {
  sessionId: string;
  query: string;
  steps: StepResult[];
  overallSuccess: boolean;
  startTime: number;
  endTime: number;
  elapsed: number;
}

// ─── Pulse / Health ───────────────────────────────────────────────────────

export interface HealthCheck {
  name: string;
  status: 'ok' | 'warn' | 'critical' | 'missing';
  detail: string;
  latency?: number;
}

export interface PulseReport {
  ts: number;
  iso: string;
  backendHealth: HealthCheck[];
  diskCleanup: { filesRemoved: number; spaceFreed: string };
  logRotation: { filesRotated: number };
  skillScan: { patternsFound: number; skillsReady: number };
  neuralCoherence: CoherenceReport;
  duration: number;
}

// ─── Providers ────────────────────────────────────────────────────────────

export type ProviderTier = 'tier1' | 'tier2';

export interface Provider {
  name: string;
  endpoint: string;
  models: string[];
  rateLimitRpm: number;
  requiresKey: boolean;
  tier: ProviderTier;
  imageEndpoint?: string;
  imageModels?: string[];
  audioEndpoint?: string;
  audioModels?: string[];
}

// ─── Profile ──────────────────────────────────────────────────────────────

export interface AngelProfile {
  name: string;
  version: string;
  description: string;
  neuralEngine: {
    enabled: boolean;
    firstPhase: boolean;
    autoSynthesize: boolean;
    contextDecaySeconds: number;
    patternThreshold: number;
    coherenceCheck: boolean;
    errorCorrection: boolean;
    routeCache: boolean;
    autoSkillExtraction: boolean;
  };
  unifiedEngine: {
    enabled: boolean;
    singlePathForAll: boolean;
    phases: PipelinePhase[];
    subsystemsAlwaysActive: string[];
    subsystemsOnDemand: string[];
    recursiveReflection: boolean;
    autoSkillIntegration: boolean;
    autoTodoCreation: boolean;
    optimalSubagentRouting: boolean;
  };
  providers: {
    primary: Provider;
    fallbackChain: Provider[];
  };
}

// ─── Evolution ────────────────────────────────────────────────────────────

export interface EvolutionEntry {
  ts: number;
  session: string;
  query: string;
  success: boolean;
  steps: StepResult[];
}

export interface EvolutionDb {
  evolutions: EvolutionEntry[];
}

// ─── Shell Utils ──────────────────────────────────────────────────────────

export interface ExecOptions {
  timeout?: number;
  env?: Record<string, string>;
  cwd?: string;
}

export interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
  duration: number;
}
