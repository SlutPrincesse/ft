# Universal CLI Skills Index

This repository provides two cross-agent skills. Load them into your coding CLI agent's skills directory to make them available.

## Skills

### skill-creator
**Trigger:** When the user wants to create a new skill or update an existing skill that extends the agent's capabilities with specialized knowledge, workflows, or tool integrations.

**What it does:**
- Guides the skill creation process from concrete examples through validation
- Enforces concise, context-efficient skill design
- Scaffolds `SKILL.md`, `agents/openai.yaml`, and optional `scripts/`, `references/`, `assets/`
- Validates frontmatter format and naming rules

**Usage:**
```bash
python3 skills/skill-creator/scripts/init_skill.py <skill-name> --path <output-directory>
python3 skills/skill-creator/scripts/quick_validate.py <path/to/skill-folder>
```

### plugin-creator
**Trigger:** When the user needs to create a new personal plugin, add optional plugin structure, generate or update marketplace entries, or update an existing local plugin during development.

**What it does:**
- Scaffolds a plugin directory with `.codex-plugin/plugin.json`
- Creates or updates `~/.agents/plugins/marketplace.json`
- Supports optional `skills/`, `hooks/`, `scripts/`, `assets/`, `.mcp.json`, `.app.json`
- Validates plugin manifests and agent metadata
- Provides cachebuster update flow for local plugin iteration

**Usage:**
```bash
python3 skills/plugin-creator/scripts/create_basic_plugin.py <plugin-name>
python3 skills/plugin-creator/scripts/validate_plugin.py <plugin-path>
python3 skills/plugin-creator/scripts/update_plugin_cachebuster.py <plugin-path>
```

## When to Use Which

| Scenario | Skill |
|----------|-------|
| Building a reusable domain guide or workflow | `skill-creator` |
| Adding scripts, references, or assets to an agent | `skill-creator` |
| Scaffolding a new plugin package | `plugin-creator` |
| Updating a plugin during development | `plugin-creator` |
| Managing marketplace entries | `plugin-creator` |
