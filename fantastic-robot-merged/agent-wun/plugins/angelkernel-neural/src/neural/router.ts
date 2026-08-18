import { promises as fs } from 'node:fs';
import { join } from 'node:path';
import { IntentCategory, IntentResult, RouteEntry, RouteCache } from '../types/index.js';

export class AdaptiveRouter {
  private routeCachePath: string;

  constructor(private neuralDir: string) {
    this.routeCachePath = join(neuralDir, 'routes.json');
  }

  async route(query: string, intentResult: IntentResult): Promise<{
    intent: IntentCategory;
    agents: string[];
    skills: string[];
  }> {
    const { intent, agents, skills } = intentResult;

    await this.updateCache(intent, agents.join(' '), skills.join(' '));

    const cache = await this.loadCache();
    const cached = cache[intent];
    if (cached && cached.count > 1) {
      // Use historical agents if available and intent matches
      const histAgents = cached.agents ? cached.agents.split(' ').filter(Boolean) : [];
      const histSkills = cached.skills ? cached.skills.split(' ').filter(Boolean) : [];
      return {
        intent,
        agents: histAgents.length > 0 ? histAgents : agents,
        skills: histSkills.length > 0 ? histSkills : skills,
      };
    }

    return { intent, agents, skills };
  }

  async getRouteStats(): Promise<RouteCache> {
    return this.loadCache();
  }

  async getRouteForIntent(intent: IntentCategory): Promise<RouteEntry | null> {
    const cache = await this.loadCache();
    return cache[intent] || null;
  }

  private async updateCache(intent: IntentCategory, agents: string, skills: string): Promise<void> {
    const cache = await this.loadCache();
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

  async recordSuccess(intent: IntentCategory, success: boolean): Promise<void> {
    const cache = await this.loadCache();
    if (cache[intent]) {
      const entry = cache[intent];
      const total = entry.count;
      const currentRate = entry.successRate;
      // Exponential moving average
      entry.successRate = currentRate + (success ? 1 : -1) * (currentRate * 0.1);
      entry.successRate = Math.max(0, Math.min(1, entry.successRate));
    }
    await fs.writeFile(this.routeCachePath, JSON.stringify(cache, null, 2), 'utf-8');
  }

  private async loadCache(): Promise<RouteCache> {
    try {
      const data = await fs.readFile(this.routeCachePath, 'utf-8');
      return JSON.parse(data) as RouteCache;
    } catch {
      const initial: RouteCache = {};
      await fs.writeFile(this.routeCachePath, JSON.stringify(initial, null, 2), 'utf-8');
      return initial;
    }
  }
}
