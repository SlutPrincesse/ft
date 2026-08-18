import { promises as fs } from 'node:fs';
import { join } from 'node:path';
import {
  IntentCategory,
  IntentConfig,
  IntentResult,
  RouteCache,
  RouteEntry,
} from '../types/index.js';

const INTENT_DEFINITIONS: Record<IntentCategory, IntentConfig> = {
  code: {
    patterns: ['write code', 'create function', 'implement', 'program', 'develop', 'build app',
      'fix bug', 'debug', 'refactor', 'coding', 'script', 'programming', 'api'],
    confidence: 0,
    agents: ['@coder'],
    skills: [],
  },
  research: {
    patterns: ['find', 'search', 'research', 'look up', 'what is', 'how does', 'explain',
      'tell me about', 'information', 'documentation', 'docs', 'learn about'],
    confidence: 0,
    agents: ['@researcher'],
    skills: [],
  },
  system: {
    patterns: ['health', 'status', 'diagnostic', 'check system', 'doctor', 'pulse',
      'disk', 'cleanup', 'maintenance', 'log'],
    confidence: 0,
    agents: [],
    skills: ['angel-doctor'],
  },
  memory: {
    patterns: ['remember', 'recall', 'memory', 'store', 'forget', 'consolidate',
      'what did i', 'previous', 'before', 'cortex'],
    confidence: 0,
    agents: [],
    skills: ['angel-cortex'],
  },
  evolution: {
    patterns: ['evolve', 'improve', 'optimize', 'upgrade', 'enhance', 'self-improve',
      'recursive', 'growth', 'skill extraction'],
    confidence: 0,
    agents: [],
    skills: ['angel-self-improve', 'angel-evolve'],
  },
  reasoning: {
    patterns: ['think', 'analyze', 'plan', 'design', 'architect', 'strategy',
      'decide', 'evaluate', 'compare', 'consider'],
    confidence: 0,
    agents: ['@thinker', '@architect'],
    skills: [],
  },
  creative: {
    patterns: ['create', 'generate', 'design', 'make', 'build', 'compose',
      'write', 'story', 'poem', 'art', 'image'],
    confidence: 0,
    agents: ['@thinker'],
    skills: ['imagegen'],
  },
  data: {
    patterns: ['data', 'analyze', 'process', 'transform', 'convert', 'parse',
      'extract', 'load', 'etl', 'pipeline', 'statistics', 'metrics'],
    confidence: 0,
    agents: ['@researcher'],
    skills: [],
  },
  learn: {
    patterns: ['learn', 'teach', 'tutorial', 'guide', 'how to', 'training',
      'practice', 'understand concept'],
    confidence: 0,
    agents: ['@researcher'],
    skills: [],
  },
};

const DEFAULT_CONFIDENCE = 0.15;
const FALLBACK_INTENT: IntentCategory = 'reasoning';
const FALLBACK_CONFIDENCE = 0.4;

export class IntentClassifier {
  private routeCachePath: string;

  constructor(private neuralDir: string) {
    this.routeCachePath = join(neuralDir, 'routes.json');
  }

  async classify(query: string): Promise<IntentResult> {
    const lower = query.toLowerCase();

    // Score each intent by word-boundary aware pattern matching
    const scored = new Map<IntentCategory, number>();

    for (const [name, config] of Object.entries(INTENT_DEFINITIONS)) {
      let matched = 0;
      for (const pattern of config.patterns) {
        const escaped = pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const regex = new RegExp(`\\b${escaped}\\b`, 'i');
        if (regex.test(lower)) {
          matched++;
        }
      }
      if (matched > 0) {
        const confidence = Math.min(1.0, matched / Math.max(1, config.patterns.length * 0.3));
        scored.set(name as IntentCategory, confidence);
      }
    }

    // Find best intent
    let bestIntent: IntentCategory = FALLBACK_INTENT;
    let bestConfidence = 0;

    for (const [name, confidence] of scored) {
      if (confidence > bestConfidence) {
        bestConfidence = confidence;
        bestIntent = name;
      }
    }

    // If confidence is too low, default to reasoning
    if (bestConfidence < DEFAULT_CONFIDENCE) {
      bestIntent = FALLBACK_INTENT;
      bestConfidence = FALLBACK_CONFIDENCE;
    }

    // Check route cache for historical preference
    const cache = await this.loadRouteCache();
    if (cache[bestIntent]) {
      const histConfidence = Math.min(1.0, cache[bestIntent].successRate * 0.3);
      bestConfidence = Math.min(1.0, bestConfidence + histConfidence);
    }

    const config = INTENT_DEFINITIONS[bestIntent];

    return {
      intent: bestIntent,
      confidence: Math.round(bestConfidence * 100) / 100,
      agents: config.agents,
      skills: config.skills,
    };
  }

  async updateRouteCache(intent: IntentCategory, agents: string, skills: string): Promise<void> {
    const cache = await this.loadRouteCache();
    if (!cache[intent]) {
      cache[intent] = {
        intent,
        count: 0,
        successRate: 0.5,
        agents,
        skills,
        lastRoute: Date.now(),
      };
    }
    cache[intent].count++;
    cache[intent].lastRoute = Date.now();
    cache[intent].agents = agents;
    cache[intent].skills = skills;

    await fs.writeFile(this.routeCachePath, JSON.stringify(cache, null, 2), 'utf-8');
  }

  private async loadRouteCache(): Promise<RouteCache> {
    try {
      const data = await fs.readFile(this.routeCachePath, 'utf-8');
      return JSON.parse(data) as RouteCache;
    } catch {
      return {};
    }
  }

  getDefinitions(): Record<IntentCategory, IntentConfig> {
    return { ...INTENT_DEFINITIONS };
  }

  getFallbackIntent(): { intent: IntentCategory; confidence: number } {
    return { intent: FALLBACK_INTENT, confidence: FALLBACK_CONFIDENCE };
  }
}
