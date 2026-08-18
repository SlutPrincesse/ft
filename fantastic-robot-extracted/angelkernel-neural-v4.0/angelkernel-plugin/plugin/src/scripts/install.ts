#!/usr/bin/env node
import { promises as fs } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HOME = process.env.HOME || '/root';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PLUGIN_SRC = join(__dirname, '..', '..');
const OPENCODE_PLUGINS = `${HOME}/.opencode/plugins/angelkernel-neural`;
const MARKETPLACE_FILE = `${HOME}/.agents/plugins/marketplace.json`;

async function main() {
  console.log('Installing AngelKernel Neural v4.0 plugin...\n');

  // Step 1: Create symlink
  try {
    await fs.mkdir(join(HOME, '.opencode', 'plugins'), { recursive: true });
    // Remove existing symlink if any
    try { await fs.unlink(OPENCODE_PLUGINS); } catch {}
    await fs.symlink(PLUGIN_SRC, OPENCODE_PLUGINS, 'dir');
    console.log(`  ✓ Symlinked: ${OPENCODE_PLUGINS} → ${PLUGIN_SRC}`);
  } catch (err) {
    console.log(`  ⚠ Symlink: ${err}`);
  }

  // Step 2: Create marketplace entry
  try {
    await fs.mkdir(join(HOME, '.agents', 'plugins'), { recursive: true });

    let marketplace: { plugins?: any[] } = {};
    try {
      const data = await fs.readFile(MARKETPLACE_FILE, 'utf-8');
      marketplace = JSON.parse(data);
    } catch {
      marketplace = {};
    }

    if (!Array.isArray(marketplace.plugins)) {
      marketplace.plugins = [];
    }

    const existing = marketplace.plugins.findIndex(
      (p: any) => p.name === 'angelkernel-neural',
    );

    const entry = {
      name: 'angelkernel-neural',
      path: OPENCODE_PLUGINS,
      version: '4.0.0',
      description: 'AngelKernel v4.0 Neural — Autonomous Neural Cognition OS',
      enabled: true,
    };

    if (existing >= 0) {
      marketplace.plugins[existing] = entry;
      console.log('  ✓ Updated marketplace entry');
    } else {
      marketplace.plugins.push(entry);
      console.log('  ✓ Created marketplace entry');
    }

    await fs.writeFile(MARKETPLACE_FILE, JSON.stringify(marketplace, null, 2), 'utf-8');
  } catch (err) {
    console.log(`  ⚠ Marketplace: ${err}`);
  }

  // Step 3: Ensure data directories
  const dirs = [
    `${HOME}/.angelkernel-neural-data/store`,
    `${HOME}/.angelkernel-neural-data/memory/cortex`,
    `${HOME}/.angelkernel-neural-data/neural`,
    `${HOME}/.angelkernel-neural-data/logs`,
  ];
  for (const dir of dirs) {
    await fs.mkdir(dir, { recursive: true });
  }
  console.log('  ✓ Data directories created');

  // Step 4: Initialize empty data files
  const initFiles: Record<string, unknown> = {
    [`${HOME}/.angelkernel-neural-data/neural/skills.json`]: { skills: {}, patterns: [], extractionHistory: [], stats: { totalExtracted: 0, totalActivated: 0, totalFailed: 0 } },
    [`${HOME}/.angelkernel-neural-data/neural/routes.json`]: {},
    [`${HOME}/.angelkernel-neural-data/neural/coherence.json`]: null,
    [`${HOME}/.angelkernel-neural-data/store/error-correction.json`]: { created: new Date().toISOString(), patterns: [], fixes: [], learnings: [] },
    [`${HOME}/.angelkernel-neural-data/store/event-log.json`]: [],
  };

  for (const [path, defaultData] of Object.entries(initFiles)) {
    try {
      await fs.access(path);
    } catch {
      await fs.mkdir(path.substring(0, path.lastIndexOf('/')), { recursive: true });
      if (defaultData !== null) {
        await fs.writeFile(path, JSON.stringify(defaultData, null, 2), 'utf-8');
      }
    }
  }
  console.log('  ✓ Data files initialized');

  console.log(`\n✅ AngelKernel Neural v4.0 installed successfully!
Plugin path: ${OPENCODE_PLUGINS}
Marketplace: ${MARKETPLACE_FILE}

Run \`angel-status\` to verify installation.
`);
}

main().catch((err) => {
  console.error('Install failed:', err);
  process.exit(1);
});
