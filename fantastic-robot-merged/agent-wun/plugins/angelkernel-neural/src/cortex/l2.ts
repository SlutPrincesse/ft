import { promises as fs } from 'node:fs';
import { L2Entry } from '../types/index.js';

const L2_FILE = 'l2-episodic.json';

export class L2EpisodicMemory {
  private entries: L2Entry[] = [];
  private path: string;

  constructor(private cortexDir: string) {
    this.path = `${cortexDir}/${L2_FILE}`;
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
    content: string,
    source: string,
    importance = 5,
    tags: string[] = [],
    metadata: Record<string, unknown> = {},
  ): Promise<string> {
    const id = `l2_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.entries.push({
      id,
      content,
      source,
      importance,
      metadata,
      createdAt: Date.now(),
      tags,
    });
    await this.persist();
    return id;
  }

  async recall(query: string, limit = 10, minImportance = 0): Promise<L2Entry[]> {
    const q = query.toLowerCase();
    let results = this.entries.filter((e) => {
      if (e.importance < minImportance) return false;
      return (
        e.content.toLowerCase().includes(q) ||
        e.source.toLowerCase().includes(q) ||
        e.tags.some((t) => t.toLowerCase().includes(q))
      );
    });

    // Sort by importance descending, then recency descending
    results.sort((a, b) => {
      if (b.importance !== a.importance) return b.importance - a.importance;
      return b.createdAt - a.createdAt;
    });

    return results.slice(0, limit);
  }

  async getById(id: string): Promise<L2Entry | null> {
    return this.entries.find((e) => e.id === id) ?? null;
  }

  async updateImportance(id: string, importance: number): Promise<boolean> {
    const entry = this.entries.find((e) => e.id === id);
    if (!entry) return false;
    entry.importance = Math.max(0, Math.min(10, importance));
    await this.persist();
    return true;
  }

  async delete(id: string): Promise<boolean> {
    const before = this.entries.length;
    this.entries = this.entries.filter((e) => e.id !== id);
    if (this.entries.length !== before) {
      await this.persist();
      return true;
    }
    return false;
  }

  async forgetOlderThan(days: number, minImportance = 0): Promise<number> {
    const cutoff = Date.now() - days * 86400 * 1000;
    const before = this.entries.length;
    this.entries = this.entries.filter((e) => e.createdAt >= cutoff || e.importance > minImportance);
    const removed = before - this.entries.length;
    if (removed > 0) await this.persist();
    return removed;
  }

  async clear(): Promise<void> {
    this.entries = [];
    await this.persist();
  }

  getAll(): L2Entry[] {
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
