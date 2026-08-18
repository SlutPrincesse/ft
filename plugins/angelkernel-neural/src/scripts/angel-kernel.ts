#!/usr/bin/env node
import { HookRegistry } from '../hooks/registry.js';
import { NeuralEngine } from '../neural/synthesize.js';
import { MemoryCortex } from '../cortex/index.js';
import { ErrorCorrection } from '../error/correction.js';
import { SwarmIntelligence } from '../swarm/index.js';
import { UnityPipeline } from '../pipeline/index.js';
import { PulseDaemon } from '../pulse/index.js';
import { CoherenceModel } from '../neural/coherence.js';

const HOME = process.env.HOME || '/root';
const BASE = `${HOME}/.angelkernel-neural-data`;

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0] || '--help';

  const neuralDir = `${BASE}/neural`;
  const storeDir = `${BASE}/store`;
  const logDir = `${BASE}/logs`;
  const memoryDir = `${BASE}/memory`;
  const cortexDir = `${BASE}/memory/cortex`;

  const hooks = new HookRegistry({ logPath: `${storeDir}/event-log.json` });
  const coherence = new CoherenceModel(neuralDir);
  const neural = new NeuralEngine(neuralDir);
  const cortex = new MemoryCortex(cortexDir);
  const errorCorrection = new ErrorCorrection(storeDir);
  const swarm = new SwarmIntelligence();
  const pipeline = new UnityPipeline(hooks, neural, cortex, errorCorrection);
  const pulse = new PulseDaemon(hooks, coherence, { storeDir, logDir, memoryDir, neuralDir });

  await hooks.fire('system:init', { args });
  await neural.initialize();
  await cortex.initialize();
  await errorCorrection.initialize();
  await hooks.fire('system:ready', { args });

  switch (cmd) {
    case 'query':
    case 'run': {
      const query = args.slice(1).join(' ');
      if (!query) { console.log('Usage: angel-kernel run <query>'); process.exit(1); }
      const result = await pipeline.run(query);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'pulse': {
      const report = await pulse.tick();
      console.log(JSON.stringify(report, null, 2));
      break;
    }

    case 'neural': {
      const sub = args[1];
      if (sub === 'synthesize') {
        const query = args.slice(2).join(' ');
        if (!query) { console.log('Usage: angel-kernel neural synthesize <query>'); process.exit(1); }
        const result = await neural.synthesize(query);
        console.log(JSON.stringify(result, null, 2));
      } else {
        console.log('Usage: angel-kernel neural synthesize <query>');
      }
      break;
    }

    case 'cortex': {
      const sub = args[1];
      if (sub === 'stats') {
        const stats = await cortex.stats();
        console.log(JSON.stringify(stats, null, 2));
      } else {
        console.log('Usage: angel-kernel cortex stats');
      }
      break;
    }

    case 'status': {
      const cortexStats = await cortex.stats();
      const report = {
        version: '4.0.0',
        hooks: hooks.getStats(),
        cortex: cortexStats,
        errorCorrection: errorCorrection.getStats(),
      };
      console.log(JSON.stringify(report, null, 2));
      break;
    }

    default:
      console.log(`AngelKernel Neural v4.0
Usage:
  angel-kernel run <query>        Run full pipeline
  angel-kernel pulse              Run pulse daemon tick
  angel-kernel neural synthesize  Neural intent classification
  angel-kernel cortex stats       Memory cortex statistics
  angel-kernel status             System status
`);
  }

  await hooks.fire('system:shutdown', { cmd });
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
