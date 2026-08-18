#!/usr/bin/env node
import { HookRegistry } from '../hooks/registry.js';
import { NeuralEngine } from '../neural/synthesize.js';
import { MemoryCortex } from '../cortex/index.js';
import { ErrorCorrection } from '../error/correction.js';
import { UnityPipeline } from '../pipeline/index.js';

const HOME = process.env.HOME || '/root';
const BASE = `${HOME}/.angelkernel-neural-data`;

async function main() {
  const args = process.argv.slice(2);
  const query = args.join(' ');

  if (!query) {
    console.log(`AngelKernel Unity Engine v4.0
Usage: angel-unity <query>
Runs the full 7-phase pipeline: NEURAL → ENHANCE → ANALYZE → PLAN → EXECUTE → EVOLVE → REFLECT`);
    process.exit(1);
  }

  const hooks = new HookRegistry({ logPath: `${BASE}/store/event-log.json` });
  const neural = new NeuralEngine(`${BASE}/neural`);
  const cortex = new MemoryCortex(`${BASE}/memory/cortex`);
  const errorCorrection = new ErrorCorrection(`${BASE}/store`);
  const pipeline = new UnityPipeline(hooks, neural, cortex, errorCorrection);

  await neural.initialize();
  await cortex.initialize();
  await errorCorrection.initialize();

  const result = await pipeline.run(query);
  console.log(JSON.stringify(result, null, 2));

  const key = result.overallSuccess ? 'completed' : 'error';
  const label = result.overallSuccess ? '✓ Completed' : '✗ Failed';
  const elapsed = result.elapsed < 1000 ? `${result.elapsed}ms` : `${(result.elapsed / 1000).toFixed(1)}s`;
  console.error(`\n[${label}] ${result.steps.length} steps in ${elapsed}`);
  process.exit(result.overallSuccess ? 0 : 1);
}

main().catch((err) => { console.error('Unity fatal:', err); process.exit(1); });
