import { promises as fs } from 'node:fs';
import { Skill, SkillDb, SkillStatus } from '../types/index.js';

const STALE_PENDING_DAYS = 7;
const STALE_FAILED_DAYS = 1;

export class SkillLifecycle {
  constructor(private skillDbPath: string) {}

  async verify(skillId: string): Promise<boolean> {
    const db = await this.loadDb();
    const skill = db.skills[skillId];
    if (!skill) return false;

    skill.status = 'verified';
    skill.verifiedAt = Date.now();
    await this.saveDb(db);
    return true;
  }

  async activate(skillId: string): Promise<boolean> {
    const db = await this.loadDb();
    const skill = db.skills[skillId];
    if (!skill) return false;

    skill.status = 'active';
    skill.activatedAt = Date.now();
    db.stats.totalActivated++;
    await this.saveDb(db);
    return true;
  }

  async deprecate(skillId: string): Promise<boolean> {
    const db = await this.loadDb();
    const skill = db.skills[skillId];
    if (!skill) return false;

    skill.status = 'deprecated';
    await this.saveDb(db);
    return true;
  }

  async markFailed(skillId: string): Promise<void> {
    const db = await this.loadDb();
    if (db.skills[skillId]) {
      db.skills[skillId].status = 'failed';
      db.stats.totalFailed++;
      await this.saveDb(db);
    }
  }

  async cleanup(): Promise<number> {
    const db = await this.loadDb();
    const now = Date.now();
    const sevenDays = STALE_PENDING_DAYS * 86400 * 1000;
    const oneDay = STALE_FAILED_DAYS * 86400 * 1000;
    let removed = 0;

    for (const [id, skill] of Object.entries(db.skills)) {
      if (skill.status === 'pending' && now - skill.extractedAt > sevenDays) {
        delete db.skills[id];
        removed++;
      } else if (skill.status === 'failed' && now - skill.extractedAt > oneDay) {
        delete db.skills[id];
        removed++;
      }
    }

    if (removed > 0) {
      await this.saveDb(db);
    }
    return removed;
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
