import { promises as fs } from 'node:fs';
import { L1Entry, CortexStats } from '../types/index.js';

const L1_FILE = 'l1-working.json';
const DEFAULT_TTL_MS = 30 * 60 * 1000; // 30 minutes

export class L1WorkingMemory {
  private entries: L1Entry[] = [];
  private path: string;

  constructor(private cortexDir: string) {
    this.path = `${cortexDir}/${L1_FILE}`;
  }

  async initialize(): Promise<void> {
    try {
      const data = await fs.readFile(this.path, 'utf-8');
      this.entries = JSON.parse(data);
      this.evictExpired();
    } catch {
      this.entries = [];
      await this.persist();
    }
  }

  async store(key: string, value: string, ttlMs = DEFAULT_TTL_MS): Promise<void> {
    this.evictExpired();

    const existing = this.entries.find((e) => e.key === key);
    const now = Date.now();

    if (existing) {
      existing.value = value;
      existing.ttl = ttlMs;
      existing.createdAt = now;
      existing.expiresAt = now + ttlMs;
    } else {
      this.entries.push({
        key,
        value,
        ttl: ttlMs,
        createdAt: now,
        expiresAt: now + ttlMs,
      });
    }

    await this.persist();
  }

  async get(key: string): Promise<string | null> {
    this.evictExpired();
    const entry = this.entries.find((e) => e.key === key);
    return entry ? entry.value : null;
  }

  async delete(key: string): Promise<boolean> {
    const before = this.entries.length;
    this.entries = this.entries.filter((e) => e.key !== key);
    if (this.entries.length !== before) {
      await this.persist();
      return true;
    }
    return false;
  }

  async clear(): Promise<void> {
    this.entries = [];
    await this.persist();
  }

  getAll(): L1Entry[] {
    this.evictExpired();
    return [...this.entries];
  }

  count(): number {
    this.evictExpired();
    return this.entries.length;
  }

  keys(): string[] {
    this.evictExpired();
    return this.entries.map((e) => e.key);
  }

  private evictExpired(): void {
    const now = Date.now();
    this.entries = this.entries.filter((e) => e.expiresAt > now);
  }

  private async persist(): Promise<void> {
    await fs.mkdir(this.cortexDir, { recursive: true });
    await fs.writeFile(this.path, JSON.stringify(this.entries, null, 2), 'utf-8');
  }
}
