import {
  Plan,
  PipelineStep,
  PipelineResults,
  StepResult,
  PipelinePhase,
  ComplexityLevel,
  IntentCategory,
  SubagentMention,
} from '../types/index.js';
import { HookRegistry } from '../hooks/registry.js';
import { NeuralEngine } from '../neural/synthesize.js';
import { MemoryCortex } from '../cortex/index.js';
import { ErrorCorrection } from '../error/correction.js';

const PHASES: PipelinePhase[] = ['NEURAL', 'ENHANCE', 'ANALYZE', 'PLAN', 'EXECUTE', 'EVOLVE', 'REFLECT'];

const PHASE_HOOK_MAP: Record<PipelinePhase, { start: string; end: string }> = {
  NEURAL:  { start: 'neural:intent-detected', end: 'neural:learning-consolidated' },
  ENHANCE: { start: 'unity:enhance-start',    end: 'unity:enhance-end' },
  ANALYZE: { start: 'unity:analyze-start',    end: 'unity:analyze-end' },
  PLAN:    { start: 'unity:plan-start',       end: 'unity:plan-end' },
  EXECUTE: { start: 'unity:execute-start',    end: 'unity:execute-end' },
  EVOLVE:  { start: 'unity:evolve-start',     end: 'unity:evolve-end' },
  REFLECT: { start: 'unity:reflect-start',    end: 'unity:reflect-end' },
};

function detectComplexity(query: string): ComplexityLevel {
  if (query.length > 500) return 'very_complex';
  if (query.includes('please') && query.split(/\s+/).length > 30) return 'complex';
  if (query.split(/\s+/).length > 15) return 'medium';
  return 'simple';
}

function intentToDefaultAgent(intent: IntentCategory): SubagentMention {
  const map: Record<IntentCategory, SubagentMention> = {
    code: '@coder',
    research: '@researcher',
    system: '@general',
    memory: '@general',
    evolution: '@thinker',
    reasoning: '@thinker',
    creative: '@thinker',
    data: '@researcher',
    learn: '@researcher',
  };
  return map[intent];
}

export class UnityPipeline {
  constructor(
    private hooks: HookRegistry,
    private neural: NeuralEngine,
    private cortex: MemoryCortex,
    private errorCorrection: ErrorCorrection,
  ) {}

  async run(query: string): Promise<PipelineResults> {
    const sessionId = `ses_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const startTime = Date.now();
    const allSteps: StepResult[] = [];

    await this.hooks.fire('query:received', { query, sessionId });

    for (const phase of PHASES) {
      const phaseResult = await this.executePhase(phase, query, sessionId, startTime);
      allSteps.push(...phaseResult);
    }

    const endTime = Date.now();

    const results: PipelineResults = {
      sessionId,
      query,
      steps: allSteps,
      overallSuccess: allSteps.every((s) => s.success),
      startTime,
      endTime,
      elapsed: endTime - startTime,
    };

    await this.hooks.fire('query:complete', {
      sessionId,
      success: results.overallSuccess,
      elapsed: results.elapsed,
    });

    return results;
  }

  private async executePhase(
    phase: PipelinePhase,
    query: string,
    sessionId: string,
    baseTime: number,
  ): Promise<StepResult[]> {
    const hookNames = PHASE_HOOK_MAP[phase];
    const steps: StepResult[] = [];

    await this.hooks.fire(hookNames.start as any, { phase, query, sessionId });

    const plan = await this.planPhase(query, sessionId, phase);
    for (const step of plan.steps) {
      const result = await this.executeStep(step, query, sessionId, baseTime);
      steps.push(result);
    }

    await this.hooks.fire(hookNames.end as any, {
      phase,
      query,
      sessionId,
      steps: steps.length,
    });

    return steps;
  }

  private async planPhase(
    query: string,
    sessionId: string,
    phase: PipelinePhase,
  ): Promise<Plan> {
    const intentResult = await this.neural.classify(query);
    const complexity = detectComplexity(query);
    const defaultAgent = intentToDefaultAgent(intentResult.intent);

    const steps: PipelineStep[] = [];
    let stepId = 0;

    const addStep = (
      agent: SubagentMention,
      task: string,
      toolType: string,
      deps: number[] = [],
      parallel = false,
      needsMcp = false,
      usesMemory = true,
      verify = true,
    ) => {
      steps.push({
        id: ++stepId,
        phase,
        agent,
        task,
        toolType,
        needsMcp,
        usesMemory,
        dependencies: deps,
        parallel,
        verify,
      });
    };

    switch (phase) {
      case 'NEURAL':
        addStep(defaultAgent, `Classify intent for: ${query}`, 'classifier', [], false, false, true, false);
        addStep(defaultAgent, `Route to optimal subsystem`, 'router', [1]);
        addStep(defaultAgent, `Update context coherence`, 'coherence', [2]);
        break;

      case 'ENHANCE':
        addStep(intentToDefaultAgent('memory'), `Recall past patterns for: ${query}`, 'cortex-recall', [], true);
        addStep(intentToDefaultAgent('system'), `Check system health`, 'health-check', [], true);
        if (complexity === 'complex' || complexity === 'very_complex') {
          addStep(defaultAgent, `Decompose multi-step task`, 'todo-creator', [1, 2]);
        }
        break;

      case 'ANALYZE':
        addStep(intentToDefaultAgent('reasoning'), `Analyze query depth and scope`, 'analyzer', []);
        addStep(defaultAgent, `Detect domain and required subsystems`, 'domain-detector', [1]);
        addStep(intentToDefaultAgent('research'), `Check knowledge gaps`, 'knowledge-check', [2]);
        break;

      case 'PLAN':
        addStep(intentToDefaultAgent('reasoning'), `Create execution strategy`, 'planner', []);
        addStep(defaultAgent, `Allocate resources and agents`, 'allocator', [1]);
        if (complexity === 'complex' || complexity === 'very_complex') {
          addStep(defaultAgent, `Build dependency graph`, 'dep-graph', [2]);
        }
        addStep(intentToDefaultAgent('reasoning'), `Verify plan quality`, 'verifier', [3]);
        break;

      case 'EXECUTE':
        addStep(defaultAgent, `Execute primary task: ${query}`, 'executor', []);
        if (complexity !== 'simple') {
          addStep(defaultAgent, `Execute secondary verification`, 'verifier', [1]);
        }
        break;

      case 'EVOLVE':
        addStep(intentToDefaultAgent('evolution'), `Self-evolution check`, 'evolver', []);
        addStep(intentToDefaultAgent('memory'), `Store learnings to cortex`, 'cortex-store', [1]);
        addStep(defaultAgent, `Extract patterns and skills`, 'skill-extractor', [2]);
        break;

      case 'REFLECT':
        addStep(intentToDefaultAgent('reasoning'), `Evaluate result quality`, 'quality-check', []);
        addStep(intentToDefaultAgent('system'), `Benchmark performance`, 'benchmark', [1]);
        addStep(intentToDefaultAgent('memory'), `Persist results to L3 memory`, 'cortex-consolidate', [2]);
        break;
    }

    const maxDepth = complexity === 'simple' ? 1 : complexity === 'medium' ? 2 : complexity === 'complex' ? 3 : 4;

    return {
      sessionId,
      query,
      intent: intentResult.intent,
      complexity,
      totalSteps: steps.length,
      steps,
      parallelGroups: [],
      verificationPoints: steps.filter((s) => s.verify).map((s) => s.id),
      allSubsystemsActive: true,
      maxDepth,
      currentDepth: 0,
    };
  }

  private async executeStep(
    step: PipelineStep,
    query: string,
    sessionId: string,
    baseTime: number,
  ): Promise<StepResult> {
    const start = Date.now();
    let attempts = 0;
    const maxAttempts = 2;
    let lastError: string | undefined;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        await this.hooks.fire('unity:step-complete' as any, {
          stepId: step.id,
          phase: step.phase,
          agent: step.agent,
          attempts,
        });

        return {
          step: step.id,
          agent: step.agent,
          task: step.task,
          success: true,
          attempts,
          toolType: step.toolType,
          output: `Completed by ${step.agent}: ${step.task}`,
        };
      } catch (err) {
        lastError = err instanceof Error ? err.message : String(err);
        await this.errorCorrection.record(lastError, `step-${step.id}-${step.phase}`);

        if (attempts < maxAttempts) {
          await this.hooks.fire('query:retry', { stepId: step.id, error: lastError, attempt: attempts });
        }
      }
    }

    await this.hooks.fire('query:error', { stepId: step.id, error: lastError });

    return {
      step: step.id,
      agent: step.agent,
      task: step.task,
      success: false,
      attempts,
      toolType: step.toolType,
      error: lastError,
    };
  }
}
