import { promises as fs } from 'node:fs';
import { Skill, SkillDb } from '../types/index.js';

export class SkillExtractor {
  constructor(private skillDbPath: string) {}

  async extract(domain: string, content: string): Promise<string> {
    const db = await this.loadDb();
    const skillId = `auto-${domain.toLowerCase().replace(/[^a-z0-9]/g, '-')}-${String(Date.now()).slice(-5)}`;

    const existing = Object.values(db.skills).find(
      s => s.domain === domain && ['active', 'verified'].includes(s.status)
    );

    if (existing) {
      existing.version++;
      existing.extractedAt = Date.now();
      existing.triggerPattern = content.slice(0, 200);
      await this.saveDb(db);
      return existing.id;
    }

    const skill: Skill = {
      id: skillId,
      domain,
      triggerPattern: content.slice(0, 200),
      steps: `Auto-extracted from repeated patterns in: ${domain}`,
      source: 'auto-extraction',
      extractedAt: Date.now(),
      status: 'pending',
      executionCount: 0,
      successRate: 0.5,
      version: 1,
    };

    db.skills[skillId] = skill;
    db.extractionHistory.push({
      ts: Date.now(),
      skill: skillId,
      domain,
      status: 'extracted',
    });
    db.stats.totalExtracted++;

    await this.saveDb(db);
    return skillId;
  }

  async list(): Promise<Skill[]> {
    const db = await this.loadDb();
    return Object.values(db.skills).sort((a, b) => b.extractedAt - a.extractedAt);
  }

  async get(id: string): Promise<Skill | null> {
    const db = await this.loadDb();
    return db.skills[id] || null;
  }

  private async loadDb(): Promise<SkillDb> {
    try {
      const data = await fs.readFile(this.skillDbPath, 'utf-8');
      return JSON.parse(data);
    } catch {
      const initial: SkillDb = {
        skills: {},
        patterns: [],
        extractionHistory: [],
        stats: { totalExtracted: 0, totalActivated: 0, totalFailed: 0 },
      };
      await this.saveDb(initial);
      return initial;
    }
  }

  private async saveDb(db: SkillDb): Promise<void> {
    await fs.writeFile(this.skillDbPath, JSON.stringify(db, null, 2), 'utf-8');
  }
}
