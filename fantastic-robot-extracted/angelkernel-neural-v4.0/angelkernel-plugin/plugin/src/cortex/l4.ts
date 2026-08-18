import { promises as fs } from 'node:fs';
import { L4Entry } from '../types/index.js';

const L4_FILE = 'l4-procedural.json';

export class L4ProceduralMemory {
  private entries: L4Entry[] = [];
  private path: string;

  constructor(private cortexDir: string) {
    this.path = `${cortexDir}/${L4_FILE}`;
  }

  async initialize(): Promise<void> {
    try {
      const data = await fs.readFile(this.path, 'utf-8');
      this.entries = JSON.parse(data);
    } catch {
      this.entries = [];
      await this.persist();
    }
  }

  async store(
    name: string,
    domain: string,
    steps: string,
    source: string,
  ): Promise<{ id: string; updated: boolean }> {
    const existing = this.entries.find(
      (e) => e.name.toLowerCase() === name.toLowerCase(),
    );

    if (existing) {
      existing.steps = steps;
      existing.version++;
      existing.successRate = existing.successRate || 0.5;
      existing.lastUsed = Date.now();
      await this.persist();
      return { id: existing.id, updated: true };
    }

    const id = `l4_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.entries.push({
      id,
      name,
      domain,
      steps,
      source,
      version: 1,
      successRate: 0.5,
      createdAt: Date.now(),
      lastUsed: Date.now(),
    });
    await this.persist();
    return { id, updated: false };
  }

  async recall(domain: string, limit = 10): Promise<L4Entry[]> {
    const d = domain.toLowerCase();
    let results = this.entries.filter(
      (e) =>
        e.domain.toLowerCase().includes(d) ||
        e.name.toLowerCase().includes(d) ||
        e.steps.toLowerCase().includes(d),
    );

    results.sort((a, b) => b.successRate - a.successRate || b.version - a.version);

    for (const r of results) {
      r.lastUsed = Date.now();
    }
    if (results.length > 0) await this.persist();

    return results.slice(0, limit);
  }

  async getByName(name: string): Promise<L4Entry | null> {
    const entry = this.entries.find(
      (e) => e.name.toLowerCase() === name.toLowerCase(),
    );
    if (entry) {
      entry.lastUsed = Date.now();
      await this.persist();
    }
    return entry ?? null;
  }

  async recordSuccess(name: string): Promise<void> {
    const entry = this.entries.find(
      (e) => e.name.toLowerCase() === name.toLowerCase(),
    );
    if (!entry) return;
    entry.successRate = Math.min(1.0, entry.successRate + 0.05);
    entry.lastUsed = Date.now();
    await this.persist();
  }

  async recordFailure(name: string): Promise<void> {
    const entry = this.entries.find(
      (e) => e.name.toLowerCase() === name.toLowerCase(),
    );
    if (!entry) return;
    entry.successRate = Math.max(0, entry.successRate - 0.1);
    entry.lastUsed = Date.now();
    await this.persist();
  }

  async deleteUnused(days: number, maxSuccessRate = 0.3): Promise<number> {
    const cutoff = Date.now() - days * 86400 * 1000;
    const before = this.entries.length;
    this.entries = this.entries.filter(
      (e) => e.lastUsed >= cutoff || e.successRate > maxSuccessRate,
    );
    const removed = before - this.entries.length;
    if (removed > 0) await this.persist();
    return removed;
  }

  async clear(): Promise<void> {
    this.entries = [];
    await this.persist();
  }

  getAll(): L4Entry[] {
    return [...this.entries];
  }

  count(): number {
    return this.entries.length;
  }

  private async persist(): Promise<void> {
    await fs.mkdir(this.cortexDir, { recursive: true });
    await fs.writeFile(this.path, JSON.stringify(this.entries, null, 2), 'utf-8');
  }
}
