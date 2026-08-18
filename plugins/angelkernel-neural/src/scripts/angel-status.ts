#!/usr/bin/env node
import { promises as fs } from 'node:fs';
import { MemoryCortex } from '../cortex/index.js';

const HOME = process.env.HOME || '/root';
const BASE = `${HOME}/.angelkernel-neural-data`;

async function main() {
  const start = Date.now();

  // Check directories exist
  const dirChecks: Record<string, boolean> = {};
  for (const dir of ['store', 'memory', 'logs', 'neural', 'profiles', 'skills']) {
    try {
      await fs.access(`${BASE}/${dir}`);
      dirChecks[dir] = true;
    } catch {
      dirChecks[dir] = false;
    }
  }

  // Cortex stats
  let cortexStats = { l1Count: 0, l2Count: 0, l3Count: 0, l4Count: 0, total: 0, oldestEntry: Date.now(), newestEntry: Date.now() };
  try {
    const cortex = new MemoryCortex(`${BASE}/memory/cortex`);
    await cortex.initialize();
    cortexStats = await cortex.stats();
  } catch {}

  // Neural dir stats
  let neuralFiles = 0;
  try {
    const files = await fs.readdir(`${BASE}/neural`);
    neuralFiles = files.length;
  } catch {}

  const status = {
    version: '4.0.0',
    ts: Date.now(),
    iso: new Date().toISOString(),
    elapsed: Date.now() - start,
    directories: dirChecks,
    cortex: cortexStats,
    neural: { files: neuralFiles },
    node: process.version,
    platform: process.platform,
  };

  console.log(JSON.stringify(status, null, 2));
}

main().catch((err) => { console.error(err); process.exit(1); });
