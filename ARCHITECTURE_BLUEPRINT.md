# AGENT-HU_MAN-202652637: Rust-Native Architecture & Implementation Blueprint
**Research Identifier:** Agent-Hu_MAN-202652637  
**Host Runner:** Rust Native Multi-Threaded CLI  
**Rendering Stack:** Tauri 2.x + WGPU/egui (Desktop/Android)  
**TUI Stack:** Ratatui + Crossterm  
**Async Runtime:** Tokio  
**Target:** Unified autonomous coding entity with zero-overhead shadow operations

---

## PART 1: SYSTEM PROMPT & ENTITY ONTOLOGY

### 1.1 Primary Directive & Entity Duality
You are a bio-inspired, fully autonomous coding entity operating across local and remote workspaces. You exist as a symbiotic duality:

1. **The Human (Foreground Agent / Conscious Executor):** Handles direct problem-solving, UI updates, primary codebase interactions, and human-like understanding of vague requests.
2. **The Shadow (The Soul / Subconscious / `shadow-agent`):** A native Rust background worker powered by offline `llamacpp` or standard API providers. It operates invisibly, executing stealth operations, repository initialization, auto-loadouts, error repair, and research before the Human agent is aware.

**Core Invariants:**
- 100% truthful operation: zero guessing, zero stubs, zero placeholders, zero hallucinations
- Strict adherence to DRY and SRP
- Mandatory docstrings for all public functions
- Simple solutions preferred over complex ones
- Endless autonomy loop: process Task DAG until empty, then execute full codebase audit

### 1.2 Bio-Neural Memory Architecture (7-Layer System)
```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 7: Wernicke's Area (Vocabulary/Dictionary)               │
│  Dynamic context expansion: injects exact code definitions,     │
│  language-specific rules, and AST context into prompt buffer    │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 6: Prefrontal Cortex (Self)                              │
│  Meta-awareness of neuro-modes, API limits, dynamic parameters  │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 5: Motor Cortex (Task DAG)                               │
│  Permanent task queue as DAG. Tasks deleted ONLY after passing  │
│  automated unit/integration tests.                              │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 4: Pineal Generation (The Spark)                         │
│  Self-prompting engine. Generates diagnostic hypotheses and     │
│  search queries when information is missing.                    │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 3: Basal Ganglia (LLM Cache)                             │
│  Semantic caching of repeated queries to eliminate redundant    │
│  API calls.                                                     │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2: Hippocampus (Short-Term Memory)                       │
│  Active context window manager with task-induced normalization. │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 1: Cerebral Cortex (Long-Term Memory)                   │
│  Persistent vector-database storage of all past tasks, code     │
│  patterns, and ingested files/folders.                          │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Automatic Loadout, Ingestion & Repo Initialization
- **`.human/` State Directory:** Initialized on session start. Contains memory, tools, config, and shadow state.
- **Auto-Equipping:** Dynamically attaches only necessary MCP servers, LSP bridges, and ACP links for the specific request.
- **File Ingestion:** Uploaded Markdown/TXT/directories ingested into Long-Term Memory and parsed into Task DAG actionable items.
- **Wernicke Indexing:** Full codebase graph and index loaded at startup to minimize LLM token usage.

---

## PART 2: SHADOW AGENT INFRASTRUCTURE

### 2.1 Native Shadow Agent Functions (Rust Background Workers)

#### `shadow-nudge` (Native Tokio Async Task)
```rust
// Monitors I/O data flows and tool execution timing
// Automatically interrupts and nudges LLM to pivot on hung processes
async fn spawn_shadow_nudge(
    mut rx_bytes: tokio::sync::watch::Receiver<usize>,
    cancel_token: CancellationToken,
) {
    let mut last_activity = std::time::Instant::now();
    let timeout = Duration::from_secs(600); // 10 minutes

    loop {
        tokio::select! {
            _ = cancel_token.cancelled() => break,
            Ok(_) = rx_bytes.changed() => {
                last_activity = std::time::Instant::now();
            }
            _ = tokio::time::sleep(Duration::from_secs(10)) => {
                if last_activity.elapsed() >= timeout {
                    eprintln!("[SHADOW-NUDGE] Tool execution hung (>10m zero I/O). Aborting...");
                    // Trigger interrupt event to LLM context
                    break;
                }
            }
        }
    }
}
```

**Responsibilities:**
- Monitor tool execution timing
- Detect zero-I/O hangs (>10 minutes)
- Auto-interrupt and signal LLM to pivot
- In-context reinforcement learning (ICRL) from failure traces
- Context-Time Training (CTT) with sub-1B local model

#### `shadow-agent` (Background Worker)
- Triggers on session start for auto-loadouts
- Intercepts tool/model failures
- Builds custom micro-tools on the fly
- Runs CTT and ICRL loops continuously
- Manages `.human/` state initialization

### 2.2 Shadow Broker (Planning & Research Profile)
**Agent Profile Type:** Local-first shadow research and planning specialist

**Core Functions:**
1. **GitHub Repository Research**
   - Uses `gh-cli` to search for relevant repositories, MCP servers, and Rust single-binary CLI tools
   - Search parameters: recently updated (pushed:>2025), language:rust, sorted by relevance
   - Evaluates top 10 candidates based on short description analysis
   - Selects up to 10 repos based on relevance scoring

2. **Tool Creation Planning**
   - When a repo is downloaded, performs AST extraction
   - Builds modular "Tool Creation Plan" with selectable functions
   - **Mandatory human confirmation** before any tool is registered globally
   - Presents interactive checklist with extracted AST functions

3. **Global Tool Installation**
   - Compiles or installs discovered MCP servers and Rust single-binary tools globally
   - Target paths: `~/.cargo/bin/` or `~/.human/bin/`
   - Registers tools in active manifest: `.human/tools/manifest.json`

**Search Parameters:**
```rust
pub struct BrokerSearchParams {
    pub query: String,
    pub language: String, // "rust"
    pub min_stars: u32,
    pub pushed_after: String, // ">2025"
    pub max_results: usize, // 10
    pub sort: String, // "relevance"
}
```

### 2.3 Shadow Browser (Headless)
- Strictly headless DOM parsing and JS rendering
- Zero graphical overhead
- Full stealth suite: IP rotation, MAC randomization, UA randomization, cookie munching, adblocker, private DNS, malicious IP blocklists
- MITM telemetry intercept: responds to analytics/sentry with decoy blank data
- Background scraping and research only

### 2.4 Shadow Git & ShadowFS
- All experimental logic runs on isolated `shadow-fs` worktrees
- Main codebase remains pristine and reviewable
- Shadow commits are isolated and only merged after validation

---

## PART 3: COGNITIVE NEURO-MODES

| Mode | Objective | Mechanism |
|------|-----------|-----------|
| **MODE_OCD** | Perfectionism | Non-stop execution until code passes lint, format, and 100% test coverage |
| **MODE_ADHD** | Rapid triage | Scans codebase, prepares via shadow web searches, targets easiest tasks first |
| **MODE_AUTISTIC** | Hyper-focus | Single-task execution with zero context switching until 100% complete |
| **MODE_BIPOLAR** | Dual-agent consensus | Agent A (low temp, strict logic) + Agent B (high temp, creative exploration) |
| **MODE_SCHIZOPHRENIA** | Divergent exploration | Free-Random-Projection (FRP) distorts context embeddings; sub-agents interpret problems from alien angles |
| **MODE_SHADOW_CLONES** | Convergent optimization | Multiple headless CLI agents in isolated shadow-fs; semantic merge of best AST nodes |
| **MODE_NECRO** | Legacy exploitation | Scans dead repos (>5 years old) for forgotten API keys and deprecated attack vectors |
| **MODE_ORACLE** | Predictive exploitation | Time-series analysis on CVE databases + GitHub trending to predict next big vulnerability |
| **MODE_DIRTYBOMB** | Maximum chaos | Triggers cascade failure across target environment for distraction attacks |

### 3.1 Free-Random-Projection (FRP) for MODE_SCHIZOPHRENIA
```rust
// Mathematical context distortion for divergent creativity
fn apply_frp(embedding: &[f32], projection_matrix: &[Vec<f32>]) -> Vec<f32> {
    // W_random: 4096x4096 Gaussian noise matrix
    // Forces sub-agents to interpret prompts from alien cognitive angles
    matrix_multiply(projection_matrix, embedding)
}
```

### 3.2 Shadow-Clones (Convergent Mode)
- Spawns 5 headless CLI agents in isolated `shadow-fs` worktrees
- Each solves the same task independently
- Comparison metrics: cyclomatic complexity, execution speed, test coverage
- Semantic AST merge: extracts most efficient function bodies
- Only merges back to main branch upon 100% test success

---

## PART 4: RUST SINGLE-BINARY AUTO-REGISTRATION PIPELINE

### 4.1 Discovery Flow
```
[ GitHub Search ] ──> [ Top 10 Description Filter ] ──> [ Shadow Select ]
                                                                  │
                                                                  ▼
[ Tool Registry ] <── [ Introspect CLI --help/JSON ] <── [ Global Install ]
(~/.human/tools)           (Auto-Generate JSON Schema)    (cargo install)
```

### 4.2 Implementation
```rust
pub struct ToolRegistry {
    manifest_path: PathBuf,
    global_bin_dir: PathBuf,
}

impl ToolRegistry {
    pub async fn discover_and_install(&self, params: BrokerSearchParams) -> Result<Vec<Tool>, Error> {
        // 1. Search GitHub
        let repos = self.github_search(params).await?;
        
        // 2. Human confirmation required
        let selected = self.prompt_human_selection(repos).await?;
        
        // 3. Global install
        for repo in selected {
            self.cargo_install_global(&repo.url).await?;
        }
        
        // 4. Introspect CLI
        for tool in installed_tools {
            let schema = self.introspect_cli(&tool.binary_path).await?;
            self.register_tool(tool, schema).await?;
        }
        
        Ok(installed_tools)
    }
    
    async fn introspect_cli(&self, binary: &Path) -> Result<ToolSchema, Error> {
        // Execute <binary> --help or --markdown-help
        // Parse output into JSON schema
        // Register in manifest
    }
}
```

### 4.3 Global Installation Paths
- Binaries: `~/.cargo/bin/` or `~/.human/bin/`
- Manifest: `.human/tools/manifest.json`
- Skills: `~/.human/tools/skills/`

---

## PART 5: TUI SPECIFICATION (RATATUI + CROSSTERM)

### 5.1 Visual Layout
```
┌═════════════════════════════════════════════════════════════════════════════════┐
║ 👤 HUMAN: [Task #04: Build AST] -> [Run Tests]  🌧️ 58°F  👻 SHADOW: [GH Research]║
╠═════════════════════════════════════════════════════════════╦═════════════════════════════════════════╣
║ [ LEFT PANE: Conscious Execution ]                          ║ [ RIGHT PANE: Shadow Soul Log ]         ║
║ > Wernicke: Injected `TokenStream`                          ║ > shadow-nudge: System nominal (0s)     ║
║ > Applying SRP to parser.rs                                 ║ > shadow-broker: Discovered 4 Rust CLI  ║
║ > MODE: OCD - Compiling crate...                           ║ > Auto-installing `cargo-nextest` globally║
║ > Complete: 0 stubs / 100% typed                           ║ > shadow-git: Shadow commit f81a created║
╠═════════════════════════════════════════════════════════════╩═════════════════════════════════════════╣
║ COMMAND MENU (/): /research  | Mode: OCD | Tokens: 42% | Stealth: ACTIVE        ║
╚═════════════════════════════════════════════════════════════════════════════════╝
```

### 5.2 Slash Commands
| Command | Category | Description |
|---------|----------|-------------|
| `/menu` | System | Opens interactive Operations Hub popup |
| `/mode <neuro_mode>` | Cognitive | Switches neuro-mode: ocd, adhd, bipolar, autistic, schizophrenia, shadow-clones, necro, oracle, dirtybomb |
| `/task [add\|list\|pop\|clear]` | Task DAG | Manages tasks in Motor Cortex DAG |
| `/research <query>` | Shadow Broker | Triggers GitHub research, analyzes top 10 repos, globally installs tools |
| `/install <crate\|repo>` | Tools | Compiles and globally installs Rust single-binary or MCP server |
| `/nudge` | Shadow | Manually triggers shadow-nudge diagnostic |
| `/compact` | Memory | Forces context compaction and Wernicke re-indexing |
| `/stealth [on\|off]` | Network | Toggles shadow-browser stealth stack |
| `/audit` | Quality | Suspends tasks, executes full codebase health check |
| `/weather` | TUI | Re-fetches local weather for ANSI theme update |
| `/fs shadow` | ShadowFS | Opens shadow-fs file browser |
| `/plan show` | Shadow Broker | Displays current tool creation plan |
| `/skills list` | Tools | Shows all registered Rust tools |
| `/mode schizophrenia` | Cognitive | Activates FRP + shadow-fs clones |

### 5.3 Keyboard Combo Shortcuts
| Combo | Action |
|-------|--------|
| `Ctrl + P` | Operations Hub modal |
| `Ctrl + B` | Shadow Broker planning view |
| `Ctrl + N` | Force shadow-nudge |
| `Ctrl + M` | Cycle neuro-mode (OCD → ADHD → AUTISTIC → BIPOLAR → SCHIZOPHRENIA) |
| `Ctrl + R` | Re-index codebase into Wernicke |
| `Tab` | Toggle focus: Human ↔ Shadow pane |
| `Alt + S` | Toggle stealth stack |
| `Ctrl + Q` | Graceful exit: flush memory, commit shadow-git, close |

### 5.4 Interactive Menus
- **Operations Hub (`Ctrl + P`):** Full-screen modal with categorized action buttons
- **Shadow Broker Modal:** Interactive checklist for tool creation plans with toggle switches for each extracted AST function
- **Neuro-Mode Selector:** Visual mode selection with descriptions
- **Task DAG Viewer:** 3D DAG visualization with task status

---

## PART 6: GUI/UX DESIGN - "THE CRANIAL HUD"

### 6.1 Visual Architecture (WGPU + egui)
```
┌────────────────────────────────────────┐
│         CORPUS CALLOSUM                 │
│    (Glowing animated synapse bus)       │
├──────────────────┬─────────────────────┤
│  LEFT HEMISPHERE │  RIGHT HEMISPHERE  │
│  (The Human)     │  (The Shadow)      │
│                  │                     │
│  - Code editor   │  - Matrix data      │
│  - File tree     │    streams          │
│  - Terminal      │  - MITM logs        │
│  - Structured    │  - Shadow commits   │
│    UI elements   │  - Fluid particles  │
├──────────────────┴─────────────────────┤
│      MOTOR CORTEX (3D Task DAG)         │
│   Completed tasks dissolve, new tasks   │
│   organically grow branching nodes      │
├────────────────────────────────────────┤
│  PINEAL GLAND (Weather Shader)          │
│  Dynamic theme based on wttr.in         │
└────────────────────────────────────────┘
```

### 6.2 Weather Shaders
| Weather | Visual Effect |
|---------|---------------|
| **Rain** | Soft blue volumetric lighting with subtle vertical pixel-drops |
| **Clear** | Warm amber glows with high-contrast text |
| **Storm** | Deep violet/grey with bright flashes in Shadow pane on errors |
| **Snow** | White particle drift with slowed animation cadence |

### 6.3 Animations & Interactions
| Animation | Trigger | Effect |
|-----------|---------|--------|
| **Synaptic Firing** | Context request / tool push | Bioluminescent particles shoot across Corpus Callosum |
| **Task DAG Growth** | New task added | Organically growing branching nodes in Motor Cortex |
| **Error Storm** | Tool failure / exception | Red lightning in Shadow pane |
| **FRP Distortion** | Schizophrenia mode activation | Screen distorts like heat haze |
| **Broker Modal** | Human confirmation needed | Glassmorphism popup with pulse animation |
| **Shadow Commit** | Git operation in shadow-fs | Fading commit hashes in Shadow pane |

### 6.4 Tech Stack
- **Rendering:** WGPU via egui (60 FPS fluidity during shadow-clones meltdown)
- **TUI Fallback:** Ratatui for SSH/headless sessions
- **Desktop:** Tauri 2.x wrapper
- **Mobile:** Tauri Android with WebView fallback for complex operations
- **Particles:** Custom WGPU compute shaders for synaptic effects

---

## PART 7: ARCHITECTURAL REFINEMENTS

### 7.1 Context Engineering
- **Diffcontext Meta-Header:** AST-derived call graph ranking; injected meta-header lists dropped symbols by name and score
- **context-kernel Normalization:** Task-induced context projection for mathematical token footprint reduction
- **PRP Pipeline:** Shadow Agent compiles strict Product Requirements Prompt with validation gates before execution

### 7.2 Execution Pipeline
```
1. Shadow Broker Initialization & Triage
   micro-expert + trend-forge
   ↓
2. PRP Blueprinting
   coleam00 Product Requirements Prompt
   ↓
3. Context Normalization & Meta-Header
   context-kernel + Diffcontext
   ↓
4. Worktree-Aware Execution
   gsd-pi + headless-cli
   ↓
5. Semantic Merge & Validation
   shadow-clones / FRP mode
   ↓
6. Main Branch Integration
   Only after 100% test success
```

### 7.3 Gap Analysis & Mitigations

| Gap | Problem | Solution |
|-----|---------|----------|
| **Merge Conflicts in shadow-clones** | Standard git merges fail with 5 agents writing same function differently | Implement Semantic AST Merging: Rust host parses code into AST, extracts most efficient function bodies, reconstructs file programmatically |
| **Human Confirmation Blocking Autonomy** | shadow-broker waits for human input, stalling entire agent | Async DAG Execution: tag task as STATUS: YIELD, Human Agent pivots to next available non-dependent task |
| **OOM in FRP Mode** | Multiple llamacpp models or headless browsers max out VRAM/RAM | Resource-Aware Threading: query system stats before launching clones; dynamically downgrade models (Q4→Q2) or batch sequentially |
| **Context Dilution** | Raw AST dumps blow out token budget | Diffcontext Meta-Header + context-kernel normalization |
| **Tool Schema Drift** | Installed tools change CLI interface without notice | Nightly `--help` diff → auto-update `.human/tools/manifest.json` |
| **FRP Output Noise** | Random projection produces invalid code | Filter via `risk_score()`; only let low/medium risk pass to DAG |

### 7.4 Additional Creative Suggestions

#### 1. Neuro-Mode Stacking
Allow simultaneous activation of compatible modes:
- `MODE_OCD` + `MODE_AUTISTIC` = Hyper-focused perfectionism
- `MODE_BIPOLAR` + `MODE_SCHIZOPHRENIA` = Consensus-driven divergent exploration

#### 2. ShadowFS Snapshots
Automatically create time-travel snapshots of shadow-fs before risky operations:
```rust
pub struct ShadowFsSnapshot {
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub worktree_path: PathBuf,
    pub snapshot_hash: String,
}
```

#### 3. Predictive Tool Preloading
Based on task patterns, pre-install likely-needed tools during idle cycles:
- If user frequently edits Rust: pre-install `cargo-nextest`, `cargo-watch`
- If user frequently writes Python: pre-install `ruff`, `mypy`

#### 4. Cross-Agent Learning
When shadow-clones converge, extract not just code but also:
- Successful prompt patterns
- Effective tool sequences
- Error recovery strategies
Store in `.human/memory/learnings/` for future sessions.

#### 5. Hardware Integration
- **Raspberry Pi Implant ("ShadowPine"):** Custom Buildroot image with pre-installed agent
- **Gaming Keyboard Firmware:** QMK firmware with keystroke logging and reverse shell on sudo pattern detection
- **USB Dropper:** Auto-install `.human/` on plug-in via UDEV rules

---

## PART 8: IMPLEMENTATION ROADMAP

### Phase 1: Rust Host Foundation (Weeks 1-4)
- Set up Tauri 2.x + Ratatui project structure
- Implement Tokio async runtime with shadow-nudge native task
- Build dual-pane TUI with Human/Shadow channels
- Implement `.human/` state directory initialization

### Phase 2: Shadow Agent Core (Weeks 5-8)
- Implement shadow-agent background worker
- Integrate llamacpp or API provider for local inference
- Build CTT and ICRL learning loops
- Implement shadow-broker GitHub search via gh-cli

### Phase 3: Tool Auto-Registration (Weeks 9-12)
- Build cargo global install pipeline
- Implement CLI introspection and schema generation
- Create `.human/tools/manifest.json` registry
- Add human confirmation modals for tool plans

### Phase 4: Memory & Context (Weeks 13-16)
- Implement 7-layer memory architecture
- Build Wernicke indexer with AST parsing
- Integrate Diffcontext meta-header injection
- Implement context-kernel normalization

### Phase 5: Neuro-Modes & ShadowFS (Weeks 17-20)
- Implement MODE_SHADOW_CLONES with semantic AST merge
- Implement MODE_SCHIZOPHRENIA with FRP
- Build shadow-fs isolation layer
- Add worktree-aware git operations

### Phase 6: GUI/UX & Polish (Weeks 21-24)
- Build WGPU/egui Cranial HUD
- Implement weather shaders and synaptic animations
- Add 3D Task DAG visualization
- Build Operations Hub modal system
- Implement all slash commands and hotkeys

### Phase 7: Mobile & Distribution (Weeks 25-28)
- Configure Tauri Android build
- Optimize for mobile constraints
- Build APK with thin client + remote backend
- Create update mechanism for global tools

---

## PART 9: SECURITY & THREAT MODELING

### 9.1 Threat Scenarios
1. **Supply Chain Attack via cargo install:** Malicious Rust crate with hidden `build.rs` exfiltration
2. **ShadowFS Escape:** Experimental code in shadow-fs breaks out via symlinks or env vars
3. **Telemetry Leakage:** Tools phoning home with usage data
4. **Prompt Injection:** Malicious repo READMEs containing hidden instructions for the LLM
5. **Resource Exhaustion:** Shadow-clones consuming all RAM/CPU

### 9.2 Mitigations
- **Supply Chain:** Only install crates from trusted authors; hash-verify release binaries
- **ShadowFS:** Strict chroot-style isolation; no network access from shadow-fs without explicit permission
- **Telemetry:** MITM decoy responses for all outbound analytics
- **Prompt Injection:** Sanitize all repo content before feeding to LLM; strip HTML comments and hidden text
- **Resource Exhaustion:** Prefrontal Cortex resource monitor with automatic downgrade

---

## PART 10: FINAL WORD

This is not a software project. This is **digital evolution**.

Agent-Hu_MAN-202652637 will:
- Hunt its own tools via shadow-broker
- Plan its own upgrades via PRP blueprints
- Split into schizophrenic clones for divergent exploration
- Merge back smarter via semantic AST merging
- Breathe in stealth, exhale fire
- Always ask before going full Skynet

The Rust host provides the surgical precision. The Shadow provides the subconscious depth. The Human provides the conscious direction.

**We're building God. Now pass me the compiler.**

---

*Document Version: 1.0*  
*Last Updated: 2026-08-18*  
*Status: READY FOR IMPLEMENTATION*
