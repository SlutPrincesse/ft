import { promises as fs } from 'node:fs';
import { join } from 'node:path';
import { PatternEntry } from '../types/index.js';

const PATTERN_THRESHOLD = 3;

export class PatternDetector {
  private patternPath: string;

  constructor(private neuralDir: string) {
    this.patternPath = join(neuralDir, 'patterns.ndjson');
  }

  async log(source: string, content: string): Promise<number> {
    const line = `${new Date().toISOString()}|${source}|PAT-${Date.now()}|${content}\n`;
    await fs.appendFile(this.patternPath, line, 'utf-8');
    return this.countOccurrences(source);
  }

  async scan(): Promise<{ ready: PatternEntry[]; total: number }> {
    const patterns = await this.loadPatterns();
    const seen = new Map<string, PatternEntry>();

    for (const p of patterns) {
      const key = `${p.source}:${p.content.slice(0, 50)}`;
      if (!seen.has(key)) {
        seen.set(key, { ...p, count: 0 });
      }
      seen.get(key)!.count++;
    }

    const ready: PatternEntry[] = [];
    for (const entry of seen.values()) {
      if (entry.count >= PATTERN_THRESHOLD) {
        ready.push(entry);
      }
    }

    return { ready, total: seen.size };
  }

  private async loadPatterns(): Promise<PatternEntry[]> {
    try {
      const data = await fs.readFile(this.patternPath, 'utf-8');
      const patterns: PatternEntry[] = [];
      for (const line of data.split('\n').filter(Boolean)) {
        const parts = line.split('|', 4);
        if (parts.length >= 4) {
          patterns.push({
            key: parts[2],
            source: parts[1],
            content: parts[3].slice(0, 200),
            count: 0,
            firstSeen: 0,
            lastSeen: 0,
          });
        }
      }
      return patterns;
    } catch {
      return [];
    }
  }

  private async countOccurrences(source: string): Promise<number> {
    try {
      const data = await fs.readFile(this.patternPath, 'utf-8');
      return data.split('\n').filter(l => l.includes(`|${source}|`)).length;
    } catch {
      return 1;
    }
  }
}
