#!/usr/bin/env node
import { MemoryCortex } from '../cortex/index.js';

const HOME = process.env.HOME || '/root';
const CORTEX_DIR = `${HOME}/.angelkernel-neural-data/memory/cortex`;

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];

  const cortex = new MemoryCortex(CORTEX_DIR);
  await cortex.initialize();

  switch (cmd) {
    case 'store': {
      const content = args[1];
      const source = args[2] || 'user';
      if (!content) { console.log('Usage: angel-cortex store "<content>" [source]'); process.exit(1); }
      const id = await cortex.l2.store(content, source);
      console.log(JSON.stringify({ status: 'stored', id }));
      break;
    }

    case 'recall': {
      const query = args.slice(1).join(' ');
      if (!query) { console.log('Usage: angel-cortex recall "<query>" [limit]'); process.exit(1); }
      const limit = parseInt(args[args.length - 1], 10);
      const actualLimit = isNaN(limit) ? 10 : limit;
      const results = await cortex.l2.recall(query, actualLimit);
      console.log(JSON.stringify(results, null, 2));
      break;
    }

    case 'l1-store': {
      const key = args[1];
      const value = args.slice(2).join(' ');
      if (!key || !value) { console.log('Usage: angel-cortex l1-store <key> <value>'); process.exit(1); }
      await cortex.l1.store(key, value);
      console.log(JSON.stringify({ status: 'stored', key }));
      break;
    }

    case 'l1-get': {
      const key = args[1];
      if (!key) { console.log('Usage: angel-cortex l1-get <key>'); process.exit(1); }
      const value = await cortex.l1.get(key);
      console.log(value ?? 'null');
      break;
    }

    case 'stats': {
      const stats = await cortex.stats();
      console.log(JSON.stringify(stats, null, 2));
      break;
    }

    case 'forget': {
      const days = parseInt(args[1], 10) || 30;
      const minImportance = parseInt(args[2], 10) || 3;
      const removed = await cortex.l2.forgetOlderThan(days, minImportance);
      console.log(JSON.stringify({ removed }));
      break;
    }

    default:
      console.log(`AngelKernel Cortex CLI
Usage:
  angel-cortex store "<c>" [src]    Store to L2 episodic
  angel-cortex recall "<q>" [lim]   Recall from L2
  angel-cortex l1-store <k> <v>     Store to L1 working
  angel-cortex l1-get <k>           Get from L1
  angel-cortex stats                Cortex statistics
  angel-cortex forget [days] [imp]  Forget old memories
`);
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
