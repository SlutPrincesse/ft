#!/usr/bin/env node
import { SwarmIntelligence } from '../swarm/index.js';

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];

  const swarm = new SwarmIntelligence();

  switch (cmd) {
    case 'consensus': {
      const question = args.slice(1).join(' ');
      if (!question) { console.log('Usage: angel-swarm consensus "<question>"'); process.exit(1); }
      const result = await swarm.consensus(question, ['yes', 'no', 'maybe']);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'parallel': {
      const tasks = args.slice(1);
      if (tasks.length < 2) { console.log('Usage: angel-swarm parallel "<task1>" "<task2>" ...'); process.exit(1); }
      const results = await swarm.parallel(tasks);
      console.log(JSON.stringify(results, null, 2));
      break;
    }

    case 'debate': {
      const topic = args.slice(1).join(' ');
      if (!topic) { console.log('Usage: angel-swarm debate "<topic>"'); process.exit(1); }
      const result = await swarm.debate(topic, ['@thinker', '@researcher'], ['@critic', '@architect']);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    default:
      console.log(`AngelKernel Swarm CLI
Usage:
  angel-swarm consensus "<question>"      Democratic consensus
  angel-swarm parallel "<t1>" "<t2>" ...  Parallel execution
  angel-swarm debate "<topic>"            Pro/con debate
`);
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
