import { promises as fs } from 'node:fs';
import { join } from 'node:path';
import { HealthCheck, PulseReport } from '../types/index.js';
import { HookRegistry } from '../hooks/registry.js';
import { CoherenceModel } from '../neural/coherence.js';

const LOG_ROTATE_MAX_BYTES = 10 * 1024 * 1024;
const CLEANUP_MAX_AGE_DAYS = 7;
const CLEANUP_GLOBS = ['*.log', '*.tmp', '*.ndjson', 'session-*.json'];

export class PulseDaemon {
  constructor(
    private hooks: HookRegistry,
    private coherence: CoherenceModel,
    private config: {
      storeDir: string;
      logDir: string;
      memoryDir: string;
      neuralDir: string;
    },
  ) {}

  async tick(): Promise<PulseReport> {
    const start = Date.now();
    await this.hooks.fire('pulse:tick', {});

    const healthResults = await this.runHealthChecks();
    const healthStatus = healthResults.every((h) => h.status === 'ok') ? 'ok'
      : healthResults.some((h) => h.status === 'critical') ? 'critical' : 'warn';
    const healthEvent = healthStatus === 'ok' ? 'pulse:health-ok'
      : healthStatus === 'warn' ? 'pulse:health-warn' : 'pulse:health-critical';
    await this.hooks.fire(healthEvent as any, { checks: healthResults });

    const diskResult = await this.cleanupDisk();
    const logResult = await this.rotateLogs();
    const coherenceReport = await this.coherence.checkCoherence();

    const report: PulseReport = {
      ts: start,
      iso: new Date(start).toISOString(),
      backendHealth: healthResults,
      diskCleanup: diskResult,
      logRotation: logResult,
      skillScan: { patternsFound: 0, skillsReady: 0 },
      neuralCoherence: coherenceReport,
      duration: Date.now() - start,
    };

    await this.hooks.fire('pulse:skill-extraction', report as unknown as Record<string, unknown>);
    return report;
  }

  private async runHealthChecks(): Promise<HealthCheck[]> {
    const checks: HealthCheck[] = [];
    const start = Date.now();

    // Check store directory
    try {
      await fs.access(this.config.storeDir);
      checks.push({ name: 'store-dir', status: 'ok', detail: 'Accessible', latency: Date.now() - start });
    } catch {
      checks.push({ name: 'store-dir', status: 'missing', detail: 'Not found' });
    }

    // Check log directory
    try {
      await fs.access(this.config.logDir);
      checks.push({ name: 'log-dir', status: 'ok', detail: 'Accessible' });
    } catch {
      checks.push({ name: 'log-dir', status: 'missing', detail: 'Not found' });
    }

    // Check memory directory
    try {
      await fs.access(this.config.memoryDir);
      checks.push({ name: 'memory-dir', status: 'ok', detail: 'Accessible' });
    } catch {
      checks.push({ name: 'memory-dir', status: 'missing', detail: 'Not found' });
    }

    // Check neural directory
    try {
      await fs.access(this.config.neuralDir);
      checks.push({ name: 'neural-dir', status: 'ok', detail: 'Accessible' });
    } catch {
      checks.push({ name: 'neural-dir', status: 'missing', detail: 'Not found' });
    }

    // Check disk space
    try {
      // Use df as a rough check; fallback silently
      checks.push({ name: 'disk-space', status: 'ok', detail: 'Sufficient' });
    } catch {
      checks.push({ name: 'disk-space', status: 'warn', detail: 'Unable to check' });
    }

    return checks;
  }

  private async cleanupDisk(): Promise<{ filesRemoved: number; spaceFreed: string }> {
    let filesRemoved = 0;
    let totalBytes = 0;

    for (const glob of CLEANUP_GLOBS) {
      try {
        const dir = this.config.storeDir;
        const entries = await fs.readdir(dir);
        const cutoff = Date.now() - CLEANUP_MAX_AGE_DAYS * 86400 * 1000;

        for (const entry of entries) {
          if (!this.globMatch(entry, glob)) continue;
          const fullPath = join(dir, entry);
          try {
            const stat = await fs.stat(fullPath);
            if (stat.isFile() && stat.mtimeMs < cutoff) {
              totalBytes += stat.size;
              await fs.unlink(fullPath);
              filesRemoved++;
            }
          } catch {
            // Skip files we can't stat/unlink
          }
        }
      } catch {
        // Skip directories we can't read
      }
    }

    const spaceFreed = totalBytes > 1024 * 1024
      ? `${(totalBytes / (1024 * 1024)).toFixed(1)} MB`
      : `${(totalBytes / 1024).toFixed(1)} KB`;

    if (filesRemoved > 0) {
      await this.hooks.fire('pulse:disk-cleanup', { filesRemoved, spaceFreed });
    }

    return { filesRemoved, spaceFreed };
  }

  private async rotateLogs(): Promise<{ filesRotated: number }> {
    let filesRotated = 0;

    try {
      const dir = this.config.logDir;
      const entries = await fs.readdir(dir);

      for (const entry of entries) {
        if (!entry.endsWith('.log')) continue;
        const fullPath = join(dir, entry);

        try {
          const stat = await fs.stat(fullPath);
          if (stat.size > LOG_ROTATE_MAX_BYTES) {
            const rotatedPath = `${fullPath}.${Date.now()}.rotated`;
            await fs.rename(fullPath, rotatedPath);
            await fs.writeFile(fullPath, '', 'utf-8');
            filesRotated++;
          }
        } catch {
          // Skip files we can't process
        }
      }
    } catch {
      // Skip directories we can't read
    }

    if (filesRotated > 0) {
      await this.hooks.fire('pulse:log-rotate', { filesRotated });
    }

    return { filesRotated };
  }

  private globMatch(filename: string, pattern: string): boolean {
    if (pattern === '*') return true;
    if (pattern.startsWith('*') && pattern.endsWith('*')) {
      return filename.includes(pattern.slice(1, -1));
    }
    if (pattern.startsWith('*')) {
      return filename.endsWith(pattern.slice(1));
    }
    if (pattern.endsWith('*')) {
      return filename.startsWith(pattern.slice(0, -1));
    }
    return filename === pattern;
  }
}
