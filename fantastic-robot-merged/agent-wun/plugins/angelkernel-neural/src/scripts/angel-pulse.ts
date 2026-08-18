#!/usr/bin/env node
import { HookRegistry } from '../hooks/registry.js';
import { CoherenceModel } from '../neural/coherence.js';
import { PulseDaemon } from '../pulse/index.js';

const HOME = process.env.HOME || '/root';
const NEURAL_DIR = `${HOME}/.angelkernel-neural-data/neural`;
const STORE_DIR = `${HOME}/.angelkernel-neural-data/store`;
const LOG_DIR = `${HOME}/.angelkernel-neural-data/logs`;
const MEMORY_DIR = `${HOME}/.angelkernel-neural-data/memory`;

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0] || 'tick';

  const hooks = new HookRegistry();
  const coherence = new CoherenceModel(NEURAL_DIR);
  const pulse = new PulseDaemon(hooks, coherence, { storeDir: STORE_DIR, logDir: LOG_DIR, memoryDir: MEMORY_DIR, neuralDir: NEURAL_DIR });

  await coherence.initialize();

  switch (cmd) {
    case 'tick': {
      const report = await pulse.tick();
      console.log(JSON.stringify(report, null, 2));
      break;
    }

    default:
      console.log(`AngelKernel Pulse CLI
Usage:
  angel-pulse tick    Run a pulse daemon tick (health + cleanup + rotate)
`);
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
