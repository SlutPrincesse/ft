import { L1WorkingMemory } from './l1.js';
import { L2EpisodicMemory } from './l2.js';
import { L3SemanticMemory } from './l3.js';
import { L4ProceduralMemory } from './l4.js';
import { CortexStats } from '../types/index.js';

export { L1WorkingMemory } from './l1.js';
export { L2EpisodicMemory } from './l2.js';
export { L3SemanticMemory } from './l3.js';
export { L4ProceduralMemory } from './l4.js';

export class MemoryCortex {
  public l1: L1WorkingMemory;
  public l2: L2EpisodicMemory;
  public l3: L3SemanticMemory;
  public l4: L4ProceduralMemory;

  constructor(private cortexDir: string) {
    this.l1 = new L1WorkingMemory(cortexDir);
    this.l2 = new L2EpisodicMemory(cortexDir);
    this.l3 = new L3SemanticMemory(cortexDir);
    this.l4 = new L4ProceduralMemory(cortexDir);
  }

  async initialize(): Promise<void> {
    await this.l1.initialize();
    await this.l2.initialize();
    await this.l3.initialize();
    await this.l4.initialize();
  }

  async stats(): Promise<CortexStats> {
    const allEntries = [
      ...this.l1.getAll(),
      ...this.l2.getAll(),
      ...this.l3.getAll(),
      ...this.l4.getAll(),
    ];

    const timestamps = allEntries.map((e: any) => e.createdAt ?? e.consolidatedAt ?? 0).filter(Boolean);
    const now = Date.now();

    return {
      l1Count: this.l1.count(),
      l2Count: this.l2.count(),
      l3Count: this.l3.count(),
      l4Count: this.l4.count(),
      total: this.l1.count() + this.l2.count() + this.l3.count() + this.l4.count(),
      oldestEntry: timestamps.length > 0 ? Math.min(...timestamps) : now,
      newestEntry: timestamps.length > 0 ? Math.max(...timestamps) : now,
    };
  }
}
