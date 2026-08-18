#!/usr/bin/env node
import { promises as fs } from 'node:fs';
import { HookRegistry } from '../hooks/registry.js';
import { NeuralEngine } from '../neural/synthesize.js';
import { MemoryCortex } from '../cortex/index.js';
import { ErrorCorrection } from '../error/correction.js';
import { CoherenceModel } from '../neural/coherence.js';
import { PulseDaemon } from '../pulse/index.js';

const HOME = process.env.HOME || '/root';
const BASE = `${HOME}/.angelkernel-neural-data`;

interface DiagnosticResult {
  component: string;
  status: 'ok' | 'warn' | 'critical' | 'missing';
  detail: string;
  latency?: number;
}

async function main() {
  const start = Date.now();
  const results: DiagnosticResult[] = [];

  // Check directories
  const dirs = ['store', 'memory', 'logs', 'neural', 'profiles', 'skills', 'plugins'];
  for (const dir of dirs) {
    const dStart = Date.now();
    try {
      await fs.access(`${BASE}/${dir}`);
      results.push({ component: `dir:${dir}`, status: 'ok', detail: 'Accessible', latency: Date.now() - dStart });
    } catch {
      results.push({ component: `dir:${dir}`, status: 'missing', detail: 'Directory not found' });
    }
  }

  // Check core files
  const files = [
    ['config/angel.conf', 'Config'],
    ['store/evolution/evolution.json', 'Evolution DB'],
    ['neural/routes.json', 'Route Cache'],
  ];
  for (const [rel, name] of files) {
    try {
      await fs.access(`${BASE}/${rel}`);
      results.push({ component: `file:${name}`, status: 'ok', detail: 'Found' });
    } catch {
      results.push({ component: `file:${name}`, status: 'missing', detail: 'Not found (will be created)' });
    }
  }

  // Check node version
  const nodeMaj = parseInt(process.version.slice(1).split('.')[0], 10);
  results.push({
    component: 'node-version',
    status: nodeMaj >= 18 ? 'ok' : 'critical',
    detail: `Node ${process.version} (need >=18)`,
  });

  // Attempt quick neural init
  try {
    const neural = new NeuralEngine(`${BASE}/neural`);
    await neural.initialize();
    results.push({ component: 'neural-engine', status: 'ok', detail: 'Initialized' });
  } catch (err) {
    results.push({ component: 'neural-engine', status: 'warn', detail: `Init issue: ${err}` });
  }

  // Attempt quick cortex init
  try {
    const cortex = new MemoryCortex(`${BASE}/memory/cortex`);
    await cortex.initialize();
    results.push({ component: 'memory-cortex', status: 'ok', detail: 'Initialized' });
  } catch (err) {
    results.push({ component: 'memory-cortex', status: 'warn', detail: `Init issue: ${err}` });
  }

  const criticalCount = results.filter((r) => r.status === 'critical').length;
  const warnCount = results.filter((r) => r.status === 'warn').length;
  const missingCount = results.filter((r) => r.status === 'missing').length;

  const overall: DiagnosticResult = {
    component: 'overall',
    status: criticalCount > 0 ? 'critical' : missingCount > 0 ? 'warn' : 'ok',
    detail: `${results.filter((r) => r.status === 'ok').length} ok, ${warnCount} warn, ${criticalCount} critical, ${missingCount} missing in ${Date.now() - start}ms`,
  };

  console.log(JSON.stringify({ diagnostics: results, overall }, null, 2));
  process.exit(overall.status === 'critical' ? 1 : 0);
}

main().catch((err) => { console.error('Doctor fatal:', err); process.exit(1); });
