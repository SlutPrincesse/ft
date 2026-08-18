import { promises as fs } from 'node:fs';
import { L3Entry } from '../types/index.js';

const L3_FILE = 'l3-semantic.json';

export class L3SemanticMemory {
  private entries: L3Entry[] = [];
  private path: string;

  constructor(private cortexDir: string) {
    this.path = `${cortexDir}/${L3_FILE}`;
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
    concept: string,
    content: string,
    source: string,
    confidence = 5,
    tags: string[] = [],
    related: string[] = [],
  ): Promise<{ id: string; deduplicated: boolean }> {
    // Deduplication: check existing by concept name
    const existing = this.entries.find(
      (e) => e.concept.toLowerCase() === concept.toLowerCase(),
    );

    if (existing) {
      // Merge: update if new content has higher confidence
      if (confidence > existing.confidence) {
        existing.content = content;
        existing.confidence = confidence;
        existing.source = source;
        existing.consolidatedAt = Date.now();
        existing.accessCount++;
        const tagSet = new Set([...existing.tags, ...tags]);
        existing.tags = Array.from(tagSet);
        const relSet = new Set([...existing.related, ...related]);
        existing.related = Array.from(relSet);
        await this.persist();
      }
      return { id: existing.id, deduplicated: true };
    }

    const id = `l3_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.entries.push({
      id,
      concept,
      content,
      source,
      confidence,
      related,
      tags,
      consolidatedAt: Date.now(),
      accessCount: 1,
    });
    await this.persist();
    return { id, deduplicated: false };
  }

  async recall(query: string, limit = 10, minConfidence = 0): Promise<L3Entry[]> {
    const q = query.toLowerCase();
    let results = this.entries.filter((e) => {
      if (e.confidence < minConfidence) return false;
      return (
        e.concept.toLowerCase().includes(q) ||
        e.content.toLowerCase().includes(q) ||
        e.tags.some((t) => t.toLowerCase().includes(q)) ||
        e.related.some((r) => r.toLowerCase().includes(q))
      );
    });

    results.sort((a, b) => {
      if (b.confidence !== a.confidence) return b.confidence - a.confidence;
      return b.accessCount - a.accessCount;
    });

    // Bump access counts
    for (const r of results) {
      r.accessCount++;
    }
    if (results.length > 0) await this.persist();

    return results.slice(0, limit);
  }

  async getByConcept(concept: string): Promise<L3Entry | null> {
    const entry = this.entries.find(
      (e) => e.concept.toLowerCase() === concept.toLowerCase(),
    );
    if (entry) {
      entry.accessCount++;
      await this.persist();
    }
    return entry ?? null;
  }

  async consolidate(entries: Array<{ concept: string; content: string; source: string; confidence: number }>): Promise<number> {
    let stored = 0;
    for (const e of entries) {
      const result = await this.store(e.concept, e.content, e.source, e.confidence);
      if (!result.deduplicated) stored++;
    }
    return stored;
  }

  async deleteLowConfidence(threshold = 3): Promise<number> {
    const before = this.entries.length;
    this.entries = this.entries.filter((e) => e.confidence >= threshold || e.accessCount > 1);
    const removed = before - this.entries.length;
    if (removed > 0) await this.persist();
    return removed;
  }

  async clear(): Promise<void> {
    this.entries = [];
    await this.persist();
  }

  getAll(): L3Entry[] {
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
