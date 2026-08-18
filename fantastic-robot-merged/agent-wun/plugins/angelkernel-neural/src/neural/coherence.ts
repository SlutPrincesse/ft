import { promises as fs } from 'node:fs';
import { join } from 'node:path';
import {
  ContextFrame,
  CoherenceCheck,
  CoherenceReport,
  IntentCategory,
} from '../types/index.js';

const CONTEXT_DECAY_SECONDS = 3600; // 1 hour
const MAX_CONTEXTS = 50;
const MIN_WEIGHT_RETAIN = 0.3;

export class CoherenceModel {
  private contextPath: string;
  private coherencePath: string;

  constructor(private neuralDir: string) {
    this.contextPath = join(neuralDir, 'context.json');
    this.coherencePath = join(neuralDir, 'coherence.json');
  }

  async initialize(): Promise<void> {
    await fs.mkdir(this.neuralDir, { recursive: true });

    try {
      await fs.access(this.contextPath);
    } catch {
      await fs.writeFile(this.contextPath, JSON.stringify({
        _meta: { created: new Date().toISOString() },
      }, null, 2), 'utf-8');
    }

    try {
      await fs.access(this.coherencePath);
    } catch {
      await fs.writeFile(this.coherencePath, JSON.stringify({
        created: new Date().toISOString(),
        checks: [],
        health: 'initialized',
        coherenceScore: 1.0,
      }, null, 2), 'utf-8');
    }
  }

  async updateContext(domain: string, content: string, weight: number = 0.5): Promise<number> {
    const ctx = await this.loadContexts();
    const now = Date.now() / 1000;
    const domainKey = domain.toLowerCase().replace(/\s+/g, '_');

    const entry: ContextFrame = {
      domain,
      content: content.slice(0, 200),
      weight,
      ts: now,
      decay: Math.max(0.1, weight * 0.95),
    };

    ctx[domainKey] = entry;

    // Prune stale contexts: those older than decay window OR below minimum weight
    const pruned: Record<string, unknown> = {};
    pruned._meta = ctx._meta;
    let activeCount = 0;
    for (const [key, val] of Object.entries(ctx)) {
      if (key === '_meta') continue;
      const frame = val as ContextFrame;
      const age = now - frame.ts;
      if (age < CONTEXT_DECAY_SECONDS || frame.weight >= MIN_WEIGHT_RETAIN) {
        pruned[key] = frame;
        activeCount++;
      }
    }

    // Limit total contexts
    const entries = Object.entries(pruned).filter(([k]) => k !== '_meta');
    if (entries.length > MAX_CONTEXTS) {
      entries.sort((a, b) => (b[1] as ContextFrame).weight - (a[1] as ContextFrame).weight);
      const kept: Record<string, unknown> = { _meta: pruned._meta };
      for (const [k, v] of entries.slice(0, MAX_CONTEXTS)) {
        kept[k] = v;
      }
      await fs.writeFile(this.contextPath, JSON.stringify(kept, null, 2), 'utf-8');
      return Object.keys(kept).length - 1;
    }

    await fs.writeFile(this.contextPath, JSON.stringify(pruned, null, 2), 'utf-8');
    return activeCount;
  }

  async getContext(domain?: string): Promise<ContextFrame | string> {
    const ctx = await this.loadContexts();
    if (domain) {
      const domainKey = domain.toLowerCase().replace(/\s+/g, '_');
      if (ctx[domainKey]) {
        return ctx[domainKey] as ContextFrame;
      }
      return `No context for: ${domain}`;
    }

    const entries = Object.entries(ctx)
      .filter(([k]) => k !== '_meta')
      .map(([, v]) => v as ContextFrame)
      .sort((a, b) => b.weight - a.weight);

    const now = Date.now() / 1000;
    const lines = entries.slice(0, 10).map(f => {
      const age = Math.floor(now - f.ts);
      return `  ${f.domain}: weight=${f.weight} age=${age}s content=${f.content.slice(0, 60)}`;
    }).join('\n');

    return `Active contexts: ${entries.length}\n${lines}`;
  }

  async updateIntentContext(intent: IntentCategory, query: string): Promise<void> {
    await this.updateContext(intent, query, 0.8);
  }

  async checkCoherence(): Promise<CoherenceReport> {
    const checks: CoherenceCheck[] = [];
    const now = Date.now() / 1000;

    // 1. Context coherence
    try {
      const ctx = await this.loadContexts();
      const activeCtx = Object.entries(ctx).filter(([k]) => k !== '_meta');
      checks.push({
        name: 'context_coherence',
        status: activeCtx.length > 0 ? 'ok' : 'warn',
        detail: `${activeCtx.length} active contexts`,
        contexts: activeCtx.slice(0, 5).map(([k]) => k),
      });
    } catch {
      checks.push({ name: 'context_coherence', status: 'warn', detail: 'corrupt' });
    }

    // 2. Route cache health
    try {
      const routePath = join(this.neuralDir, 'routes.json');
      const data = await fs.readFile(routePath, 'utf-8');
      const routes = JSON.parse(data);
      const count = Object.keys(routes).length;
      checks.push({
        name: 'route_cache',
        status: 'ok',
        detail: `${count} routes cached`,
        routes: Object.keys(routes).filter(k => k !== 'created'),
      });
    } catch {
      checks.push({ name: 'route_cache', status: 'warn', detail: 'missing' });
    }

    // 3. Pattern detection health
    try {
      const patPath = join(this.neuralDir, 'patterns.ndjson');
      const data = await fs.readFile(patPath, 'utf-8').catch(() => '');
      const lines = data.split('\n').filter(Boolean);
      checks.push({
        name: 'pattern_detection',
        status: 'ok',
        detail: `${lines.length} patterns tracked`,
      });
    } catch {
      checks.push({ name: 'pattern_detection', status: 'warn', detail: 'unreadable' });
    }

    // 4. Error pattern health
    try {
      const errPath = join(this.neuralDir, 'error_patterns.json');
      const data = await fs.readFile(errPath, 'utf-8');
      const err = JSON.parse(data);
      checks.push({
        name: 'error_correction',
        status: 'ok',
        detail: `${err.patterns?.length || 0} error patterns tracked`,
      });
    } catch {
      checks.push({ name: 'error_correction', status: 'warn', detail: 'missing' });
    }

    const okCount = checks.filter(c => c.status === 'ok').length;
    const health = okCount === checks.length ? 'optimal' as const
      : okCount > 0 ? 'degraded' as const
      : 'critical' as const;
    const coherenceScore = Math.round((okCount / Math.max(1, checks.length)) * 100) / 100;

    const report: CoherenceReport = {
      ts: now,
      iso: new Date().toISOString(),
      checks,
      health,
      coherenceScore,
    };

    // Persist coherence report
    await fs.writeFile(this.coherencePath, JSON.stringify(report, null, 2), 'utf-8');

    return report;
  }

  private async loadContexts(): Promise<Record<string, unknown>> {
    try {
      const data = await fs.readFile(this.contextPath, 'utf-8');
      return JSON.parse(data);
    } catch {
      return { _meta: { created: new Date().toISOString() } };
    }
  }
}
