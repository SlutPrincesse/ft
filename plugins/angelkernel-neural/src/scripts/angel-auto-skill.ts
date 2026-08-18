#!/usr/bin/env node
import { PatternDetector } from '../auto-skill/detector.js';
import { SkillExtractor } from '../auto-skill/extractor.js';
import { SkillLifecycle } from '../auto-skill/lifecycle.js';

const HOME = process.env.HOME || '/root';
const NEURAL_DIR = `${HOME}/.angelkernel-neural-data/neural`;

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];

  const detector = new PatternDetector(NEURAL_DIR);
  const extractor = new SkillExtractor(NEURAL_DIR);
  const lifecycle = new SkillLifecycle(`${NEURAL_DIR}/skills.json`);

  switch (cmd) {
    case 'scan': {
      const result = await detector.scan();
      console.log(JSON.stringify({ patternsReady: result.ready.length, total: result.total, patterns: result.ready }));
      break;
    }

    case 'extract': {
      const domain = args[1];
      const content = args.slice(2).join(' ');
      if (!domain || !content) { console.log('Usage: angel-auto-skill extract <domain> <content>'); process.exit(1); }
      const skillId = await extractor.extract(domain, content);
      if (skillId) {
        console.log(JSON.stringify({ status: 'extracted', id: skillId }));
      } else {
        console.log(JSON.stringify({ status: 'error', detail: 'extraction returned empty' }));
      }
      break;
    }

    case 'verify': {
      const name = args[1];
      if (!name) { console.log('Usage: angel-auto-skill verify <skill-name>'); process.exit(1); }
      const ok = await lifecycle.verify(name);
      console.log(JSON.stringify({ status: ok ? 'verified' : 'not-found' }));
      break;
    }

    case 'activate': {
      const name = args[1];
      if (!name) { console.log('Usage: angel-auto-skill activate <skill-name>'); process.exit(1); }
      const ok = await lifecycle.activate(name);
      console.log(JSON.stringify({ status: ok ? 'activated' : 'not-found' }));
      break;
    }

    case 'list': {
      const detectorReady = await detector.scan();
      console.log(JSON.stringify({ readyForExtraction: detectorReady }, null, 2));
      break;
    }

    case 'cleanup': {
      const removed = await lifecycle.cleanup();
      console.log(JSON.stringify({ removed }));
      break;
    }

    default:
      console.log(`AngelKernel Auto-Skill CLI
Usage:
  angel-auto-skill scan                   Scan for pattern threshold
  angel-auto-skill extract <d> <c>        Extract new skill
  angel-auto-skill verify <name>          Verify skill
  angel-auto-skill activate <name>        Activate skill
  angel-auto-skill list                   List ready patterns
  angel-auto-skill cleanup                Remove stale/failed
`);
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
