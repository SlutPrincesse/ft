// ============================================================================
// AngelKernel Neural — Universal Hook Registry v4
// Typed EventEmitter for all 79 hook events with priority ordering,
// wildcard listeners, error isolation, event logging, and stats.
// ============================================================================

import { promises as fs } from 'node:fs';
import {
  HookEvent,
  HookPayload,
  HookHandler,
  HookCategory,
  HookMeta,
  EventLogEntry,
} from '../types/index.js';

// ─── Constants ─────────────────────────────────────────────────────────────

const MAX_EVENT_LOG = 10_000;
const WILDCARD = '*';

// ─── Static Hook Metadata ──────────────────────────────────────────────────

export const HOOK_META: Record<HookEvent, HookMeta> = {
  // System lifecycle
  'system:init':          { category: 'system',    priority: 100, desc: 'System initialization started' },
  'system:ready':         { category: 'system',    priority: 90,  desc: 'System fully initialized and ready' },
  'system:shutdown':      { category: 'system',    priority: 100, desc: 'System shutting down' },
  'system:heartbeat':     { category: 'system',    priority: 10,  desc: 'Periodic system heartbeat' },
  'system:degraded':      { category: 'system',    priority: 80,  desc: 'System running in degraded mode' },

  // Neural cognition
  'neural:intent-detected':     { category: 'neural',  priority: 50, desc: 'Intent classification completed' },
  'neural:route-selected':      { category: 'neural',  priority: 50, desc: 'Adaptive route selected for query' },
  'neural:context-updated':     { category: 'neural',  priority: 40, desc: 'Neural context frame updated' },
  'neural:coherence-check':     { category: 'neural',  priority: 30, desc: 'Coherence check performed' },
  'neural:learning-consolidated': { category: 'neural', priority: 20, desc: 'Learning patterns consolidated' },
  'neural:pattern-detected':    { category: 'neural',  priority: 50, desc: 'New pattern detected in context' },

  // Auto-skill
  'skill:pattern-detected': { category: 'skill', priority: 60, desc: 'Repeating pattern detected for extraction' },
  'skill:extracted':        { category: 'skill', priority: 60, desc: 'New skill extracted from pattern' },
  'skill:verified':         { category: 'skill', priority: 50, desc: 'Skill verification completed' },
  'skill:activated':        { category: 'skill', priority: 50, desc: 'Skill activated and available' },
  'skill:failed':           { category: 'skill', priority: 40, desc: 'Skill verification or activation failed' },
  'skill:optimized':        { category: 'skill', priority: 30, desc: 'Skill optimized based on usage' },
  'skill:deprecated':       { category: 'skill', priority: 30, desc: 'Skill deprecated and removed' },

  // Error correction
  'error:occurred':   { category: 'error', priority: 90, desc: 'Error occurred in system' },
  'error:diagnosed':  { category: 'error', priority: 80, desc: 'Error diagnosed with root cause' },
  'error:fixed':      { category: 'error', priority: 70, desc: 'Error auto-fix applied' },
  'error:learned':    { category: 'error', priority: 60, desc: 'Error pattern learned for future prevention' },
  'error:escalated':  { category: 'error', priority: 90, desc: 'Error escalated (auto-fix failed)' },

  // Memory cortex
  'memory:store':       { category: 'memory', priority: 50, desc: 'Memory stored to cortex tier' },
  'memory:recall':      { category: 'memory', priority: 40, desc: 'Memory recalled from cortex' },
  'memory:forget':      { category: 'memory', priority: 30, desc: 'Memory forgotten/removed' },
  'memory:consolidate': { category: 'memory', priority: 40, desc: 'Memory consolidation run' },
  'memory:corrupted':   { category: 'memory', priority: 90, desc: 'Memory corruption detected' },
  'memory:repaired':    { category: 'memory', priority: 70, desc: 'Memory corruption repaired' },

  // Evolution
  'evolution:check':        { category: 'evolution', priority: 40, desc: 'Evolution check initiated' },
  'evolution:cycle-start':  { category: 'evolution', priority: 60, desc: 'Self-evolution cycle started' },
  'evolution:cycle-end':    { category: 'evolution', priority: 60, desc: 'Self-evolution cycle completed' },
  'evolution:milestone':    { category: 'evolution', priority: 50, desc: 'Evolution milestone reached' },
  'evolution:auto-heal':    { category: 'evolution', priority: 70, desc: 'Auto-heal action triggered' },
  'evolution:refinement':   { category: 'evolution', priority: 40, desc: 'System refinement applied' },

  // Pulse daemon
  'pulse:tick':            { category: 'pulse', priority: 20, desc: 'Pulse daemon tick' },
  'pulse:health-ok':       { category: 'pulse', priority: 30, desc: 'Health check passed' },
  'pulse:health-warn':     { category: 'pulse', priority: 50, desc: 'Health check warning' },
  'pulse:health-critical': { category: 'pulse', priority: 90, desc: 'Health check critical' },
  'pulse:disk-cleanup':    { category: 'pulse', priority: 40, desc: 'Disk cleanup performed' },
  'pulse:log-rotate':      { category: 'pulse', priority: 40, desc: 'Log rotation performed' },
  'pulse:skill-extraction': { category: 'pulse', priority: 40, desc: 'Auto-skill extraction scan' },

  // Query lifecycle
  'query:received': { category: 'query', priority: 60, desc: 'Query received by system' },
  'query:analyzed': { category: 'query', priority: 50, desc: 'Query analysis completed' },
  'query:planned':  { category: 'query', priority: 50, desc: 'Execution plan created' },
  'query:executed': { category: 'query', priority: 50, desc: 'Query execution in progress' },
  'query:complete': { category: 'query', priority: 60, desc: 'Query execution completed' },
  'query:error':    { category: 'query', priority: 80, desc: 'Query execution error' },
  'query:retry':    { category: 'query', priority: 50, desc: 'Query execution retry' },

  // Unity pipeline phases
  'unity:enhance-start':   { category: 'unity', priority: 50, desc: 'Unity phase 0: ENHANCE started' },
  'unity:enhance-end':     { category: 'unity', priority: 50, desc: 'Unity phase 0: ENHANCE completed' },
  'unity:analyze-start':   { category: 'unity', priority: 50, desc: 'Unity phase 1: ANALYZE started' },
  'unity:analyze-end':     { category: 'unity', priority: 50, desc: 'Unity phase 1: ANALYZE completed' },
  'unity:plan-start':      { category: 'unity', priority: 50, desc: 'Unity phase 2: PLAN started' },
  'unity:plan-end':        { category: 'unity', priority: 50, desc: 'Unity phase 2: PLAN completed' },
  'unity:execute-start':   { category: 'unity', priority: 50, desc: 'Unity phase 3: EXECUTE started' },
  'unity:execute-end':     { category: 'unity', priority: 50, desc: 'Unity phase 3: EXECUTE completed' },
  'unity:step-complete':   { category: 'unity', priority: 40, desc: 'Unity pipeline step completed' },
  'unity:evolve-start':    { category: 'unity', priority: 50, desc: 'Unity phase 4: EVOLVE started' },
  'unity:evolve-end':      { category: 'unity', priority: 50, desc: 'Unity phase 4: EVOLVE completed' },
  'unity:reflect-start':   { category: 'unity', priority: 50, desc: 'Unity phase 5: REFLECT started' },
  'unity:reflect-end':     { category: 'unity', priority: 50, desc: 'Unity phase 5: REFLECT completed' },

  // Agent lifecycle
  'agent:spawned':  { category: 'agent', priority: 50, desc: 'Subagent spawned' },
  'agent:complete': { category: 'agent', priority: 50, desc: 'Subagent task completed' },
  'agent:error':    { category: 'agent', priority: 80, desc: 'Subagent error' },
  'agent:timeout':  { category: 'agent', priority: 80, desc: 'Subagent timeout' },

  // Swarm intelligence
  'swarm:consensus-start': { category: 'swarm', priority: 50, desc: 'Swarm consensus voting started' },
  'swarm:consensus-end':   { category: 'swarm', priority: 50, desc: 'Swarm consensus voting ended' },
  'swarm:parallel-start':  { category: 'swarm', priority: 50, desc: 'Swarm parallel execution started' },
  'swarm:parallel-end':    { category: 'swarm', priority: 50, desc: 'Swarm parallel execution ended' },
  'swarm:debate-start':    { category: 'swarm', priority: 50, desc: 'Swarm debate started' },
  'swarm:debate-end':      { category: 'swarm', priority: 50, desc: 'Swarm debate ended' },

  // Config
  'config:changed':  { category: 'config', priority: 60, desc: 'Configuration changed' },
  'config:reloaded': { category: 'config', priority: 50, desc: 'Configuration reloaded' },
  'config:error':    { category: 'config', priority: 80, desc: 'Configuration error' },

  // Plugin
  'plugin:enabled':   { category: 'plugin', priority: 60, desc: 'Plugin enabled' },
  'plugin:disabled':  { category: 'plugin', priority: 60, desc: 'Plugin disabled' },
  'plugin:installed': { category: 'plugin', priority: 50, desc: 'Plugin installed' },
  'plugin:error':     { category: 'plugin', priority: 80, desc: 'Plugin error' },
};

// ─── Internal Types ────────────────────────────────────────────────────────

interface RegisteredHandler {
  id: string;
  handler: HookHandler;
  priority: number;
}

interface HookStats {
  totalRegistrations: number;
  activeRegistrations: number;
  totalFired: number;
  eventsFired: Record<string, number>;
  errors: number;
  wildcardHandlers: number;
}

// ─── HookRegistry ──────────────────────────────────────────────────────────

export class HookRegistry {
  private handlers = new Map<string, RegisteredHandler[]>();
  private eventLog: EventLogEntry[] = [];
  private logPath: string | null = null;
  private stats: HookStats = {
    totalRegistrations: 0,
    activeRegistrations: 0,
    totalFired: 0,
    eventsFired: {},
    errors: 0,
    wildcardHandlers: 0,
  };
  private counter = 0;

  constructor(config?: { logPath?: string }) {
    if (config?.logPath) {
      this.logPath = config.logPath;
    }
  }

  // ─── Registration ───────────────────────────────────────────────────────

  /**
   * Register a handler for a specific hook event (or '*' for all events).
   * Returns a unique handler ID that can be used with unregister().
   */
  on(event: HookEvent | typeof WILDCARD, handler: HookHandler, priority = 50): string {
    const id = `hook_${++this.counter}_${Date.now()}`;
    const entry: RegisteredHandler = { id, handler, priority };

    if (!this.handlers.has(event)) {
      this.handlers.set(event, []);
    }

    const list = this.handlers.get(event)!;
    list.push(entry);

    // Keep sorted by priority (descending — higher = runs first)
    list.sort((a, b) => b.priority - a.priority);

    this.stats.totalRegistrations++;
    this.stats.activeRegistrations++;

    if (event === WILDCARD) {
      this.stats.wildcardHandlers++;
    }

    return id;
  }

  /** Register a one-time handler that auto-unregisters after first fire. */
  once(event: HookEvent | typeof WILDCARD, handler: HookHandler, priority = 50): string {
    const id = `hook_once_${++this.counter}_${Date.now()}`;

    const wrapper: HookHandler = async (evt, payload, ts) => {
      await handler(evt, payload, ts);
      this.unregister(id);
    };

    const entry: RegisteredHandler = { id, handler: wrapper, priority };

    if (!this.handlers.has(event)) {
      this.handlers.set(event, []);
    }

    const list = this.handlers.get(event)!;
    list.push(entry);
    list.sort((a, b) => b.priority - a.priority);

    this.stats.totalRegistrations++;
    this.stats.activeRegistrations++;

    if (event === WILDCARD) {
      this.stats.wildcardHandlers++;
    }

    return id;
  }

  /** Remove a handler by its ID. */
  unregister(handlerId: string): boolean {
    for (const [event, list] of this.handlers.entries()) {
      const idx = list.findIndex((h) => h.id === handlerId);
      if (idx !== -1) {
        list.splice(idx, 1);
        if (list.length === 0) {
          this.handlers.delete(event);
        }
        this.stats.activeRegistrations--;
        if (event === WILDCARD) {
          this.stats.wildcardHandlers--;
        }
        return true;
      }
    }
    return false;
  }

  /** Remove all handlers for a specific event (or all events if omitted). */
  clear(event?: HookEvent | typeof WILDCARD): void {
    if (event) {
      const list = this.handlers.get(event);
      if (list) {
        this.stats.activeRegistrations -= list.length;
        if (event === WILDCARD) {
          this.stats.wildcardHandlers -= list.length;
        }
        this.handlers.delete(event);
      }
    } else {
      this.handlers.clear();
      this.stats.activeRegistrations = 0;
      this.stats.wildcardHandlers = 0;
    }
  }

  // ─── Firing ──────────────────────────────────────────────────────────────

  /**
   * Fire a hook event synchronously. All handlers run, errors are caught
   * and logged (one failing handler does not prevent others from running).
   */
  fire(event: HookEvent, payload: HookPayload = {}): void {
    const ts = Date.now();

    // Log the event
    const logEntry: EventLogEntry = {
      iso: new Date(ts).toISOString(),
      event,
      payload: this.sanitizePayload(payload),
    };
    this.eventLog.push(logEntry);
    if (this.eventLog.length > MAX_EVENT_LOG) {
      this.eventLog.shift();
    }

    // Update stats
    this.stats.totalFired++;
    this.stats.eventsFired[event] = (this.stats.eventsFired[event] || 0) + 1;

    // Fire
    this.dispatch(event, payload, ts);
  }

  /**
   * Fire a hook event asynchronously. Returns results from all handlers,
   * including any errors. Use when hook handlers may do async work.
   */
  async fireAsync(event: HookEvent, payload: HookPayload = {}): Promise<Array<{ handlerId: string; error?: Error }>> {
    const ts = Date.now();

    const logEntry: EventLogEntry = {
      iso: new Date(ts).toISOString(),
      event,
      payload: this.sanitizePayload(payload),
    };
    this.eventLog.push(logEntry);
    if (this.eventLog.length > MAX_EVENT_LOG) {
      this.eventLog.shift();
    }

    this.stats.totalFired++;
    this.stats.eventsFired[event] = (this.stats.eventsFired[event] || 0) + 1;

    return this.dispatchAsync(event, payload, ts);
  }

  // ─── Dispatch ────────────────────────────────────────────────────────────

  private dispatch(event: HookEvent, payload: HookPayload, ts: number): void {
    const handlers = this.getHandlersFor(event);
    for (const { id, handler } of handlers) {
      try {
        const result = handler(event, payload, ts);
        // If it's a promise, catch it silently
        if (result instanceof Promise) {
          result.catch((err) => {
            this.stats.errors++;
            console.error(`[HookRegistry] Async handler ${id} failed for ${event}:`, err);
          });
        }
      } catch (err) {
        this.stats.errors++;
        console.error(`[HookRegistry] Handler ${id} failed for ${event}:`, err);
      }
    }
  }

  private async dispatchAsync(
    event: HookEvent,
    payload: HookPayload,
    ts: number,
  ): Promise<Array<{ handlerId: string; error?: Error }>> {
    const handlers = this.getHandlersFor(event);
    const results: Array<{ handlerId: string; error?: Error }> = [];

    for (const { id, handler } of handlers) {
      try {
        await handler(event, payload, ts);
        results.push({ handlerId: id });
      } catch (err) {
        this.stats.errors++;
        results.push({ handlerId: id, error: err instanceof Error ? err : new Error(String(err)) });
      }
    }

    return results;
  }

  // ─── Query ───────────────────────────────────────────────────────────────

  /** Get handlers for an event (event-specific first, then wildcards). */
  private getHandlersFor(event: HookEvent): RegisteredHandler[] {
    const specific = this.handlers.get(event) ?? [];
    const wildcard = this.handlers.get(WILDCARD) ?? [];
    return [...specific, ...wildcard];
  }

  /** Check if an event has any registered handlers. */
  hasHandlers(event: HookEvent): boolean {
    return (this.handlers.get(event)?.length ?? 0) > 0 || this.handlers.has(WILDCARD);
  }

  /** Count handlers for a specific event. */
  handlerCount(event?: HookEvent): number {
    if (event) {
      const specific = this.handlers.get(event)?.length ?? 0;
      const wildcard = this.handlers.get(WILDCARD)?.length ?? 0;
      return specific + wildcard;
    }
    return this.stats.activeRegistrations;
  }

  /** List all registered events and their handler counts. */
  listEvents(): Array<{ event: string; count: number; meta: HookMeta | null }> {
    const result: Array<{ event: string; count: number; meta: HookMeta | null }> = [];
    for (const [event] of this.handlers.entries()) {
      const list = this.handlers.get(event)!;
      const meta = event !== WILDCARD ? HOOK_META[event as HookEvent] : null;
      result.push({ event, count: list.length, meta });
    }
    result.sort((a, b) => a.event.localeCompare(b.event));
    return result;
  }

  /** List events grouped by category. */
  listByCategory(): Record<string, Array<{ event: string; count: number }>> {
    const grouped: Record<string, Array<{ event: string; count: number }>> = {};

    for (const [event] of this.handlers.entries()) {
      if (event === WILDCARD) continue;
      const meta = HOOK_META[event as HookEvent];
      const cat = meta?.category ?? 'unknown';
      if (!grouped[cat]) grouped[cat] = [];
      grouped[cat].push({ event, count: this.handlers.get(event)!.length });
    }

    return grouped;
  }

  // ─── Event Log ───────────────────────────────────────────────────────────

  getEventLog(limit = 100): EventLogEntry[] {
    return this.eventLog.slice(-limit);
  }

  clearEventLog(): void {
    this.eventLog = [];
  }

  async persistEventLog(): Promise<void> {
    if (!this.logPath) return;
    const dir = this.logPath.substring(0, this.logPath.lastIndexOf('/'));
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(this.logPath, JSON.stringify(this.eventLog.slice(-1000), null, 2), 'utf-8');
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  getStats(): HookStats & { categories: Record<string, number> } {
    const categories: Record<string, number> = {};
    for (const [event] of this.handlers.entries()) {
      if (event === WILDCARD) continue;
      const meta = HOOK_META[event as HookEvent];
      const cat = meta?.category ?? 'unknown';
      categories[cat] = (categories[cat] || 0) + (this.handlers.get(event)?.length ?? 0);
    }
    return { ...this.stats, categories };
  }

  // ─── Persistence ─────────────────────────────────────────────────────────

  async save(path: string): Promise<void> {
    const dir = path.substring(0, path.lastIndexOf('/'));
    await fs.mkdir(dir, { recursive: true });
    const data = {
      version: 4,
      ts: Date.now(),
      stats: this.stats,
      handlerCount: this.handlers.size,
    };
    await fs.writeFile(path, JSON.stringify(data, null, 2), 'utf-8');
  }

  // ─── Utilities ───────────────────────────────────────────────────────────

  /** Remove sensitive fields from payloads before logging. */
  private sanitizePayload(payload: HookPayload): HookPayload {
    const sensitive = ['password', 'secret', 'token', 'key', 'credential', 'auth'];
    const result: HookPayload = { ...payload };
    for (const key of Object.keys(result)) {
      if (sensitive.some((s) => key.toLowerCase().includes(s))) {
        result[key] = '***REDACTED***';
      }
    }
    return result;
  }
}
