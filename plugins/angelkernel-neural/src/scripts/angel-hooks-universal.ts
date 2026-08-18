#!/usr/bin/env node
import { HookRegistry, HOOK_META } from '../hooks/registry.js';

const HOME = process.env.HOME || '/root';
const LOG_PATH = `${HOME}/.angelkernel-neural-data/store/event-log.json`;

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];

  const hooks = new HookRegistry({ logPath: LOG_PATH });

  switch (cmd) {
    case 'register-all': {
      for (const event of Object.keys(HOOK_META)) {
        hooks.on(event as any, async () => {});
      }
      await hooks.save(`${HOME}/.angelkernel-neural-data/store/hooks.json`);
      console.log(JSON.stringify({ status: 'registered', count: Object.keys(HOOK_META).length }));
      break;
    }

    case 'fire': {
      const event = args[1] as any;
      const payload = args.slice(2).join(' ');
      if (!event) { console.log('Usage: angel-hooks fire <event> [payload]'); process.exit(1); }
      await hooks.fire(event, { payload });
      console.log(JSON.stringify({ event, fired: true }));
      break;
    }

    case 'list': {
      const category = args[1];
      if (category) {
        const grouped = hooks.listByCategory();
        const catEvents = grouped[category] ?? [];
        console.log(JSON.stringify({ category, events: catEvents }));
      } else {
        console.log(JSON.stringify(hooks.listEvents(), null, 2));
      }
      break;
    }

    case 'stats': {
      console.log(JSON.stringify(hooks.getStats(), null, 2));
      break;
    }

    default:
      console.log(`AngelKernel Hooks CLI
Usage:
  angel-hooks register-all                 Register all 79 events
  angel-hooks fire <event> [payload]       Fire a hook event
  angel-hooks list [category]              List events by category
  angel-hooks stats                        Hook system statistics
`);
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
