#!/usr/bin/env node
import { NeuralEngine } from '../neural/synthesize.js';
import { CoherenceModel } from '../neural/coherence.js';
import { IntentClassifier } from '../neural/engine.js';

const HOME = process.env.HOME || '/root';
const NEURAL_DIR = `${HOME}/.angelkernel-neural-data/neural`;

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];

  const neural = new NeuralEngine(NEURAL_DIR);
  const classifier = new IntentClassifier(NEURAL_DIR);
  const coherence = new CoherenceModel(NEURAL_DIR);
  await neural.initialize();

  switch (cmd) {
    case 'synthesize': {
      const query = args.slice(1).join(' ');
      if (!query) { console.log('Usage: angel-neural synthesize "<query>"'); process.exit(1); }
      const result = await neural.synthesize(query);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'classify': {
      const query = args.slice(1).join(' ');
      if (!query) { console.log('Usage: angel-neural classify "<query>"'); process.exit(1); }
      const result = await classifier.classify(query);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'context-update': {
      const domain = args[1];
      const content = args.slice(2).join(' ');
      if (!domain || !content) { console.log('Usage: angel-neural context-update <domain> <content>'); process.exit(1); }
      await coherence.updateIntentContext(domain as any, content);
      console.log(JSON.stringify({ status: 'ok', domain, content }));
      break;
    }

    case 'context-get': {
      const domain = args[1];
      const ctx = domain ? await coherence.getContext(domain as any) : await coherence.getContext();
      console.log(JSON.stringify(ctx ?? { status: 'empty' }));
      break;
    }

    case 'coherence': {
      const report = await coherence.checkCoherence();
      console.log(JSON.stringify(report, null, 2));
      break;
    }

    default:
      console.log(`AngelKernel Neural CLI
Usage:
  angel-neural synthesize "<query>"     Full neural pipeline
  angel-neural classify "<query>"       Intent classification only
  angel-neural context-update <d> <c>  Update context
  angel-neural context-get [domain]     Show context
  angel-neural coherence                Coherence check
`);
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
