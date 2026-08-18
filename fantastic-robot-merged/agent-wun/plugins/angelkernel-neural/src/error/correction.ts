import { promises as fs } from 'node:fs';
import { ErrorPattern, ErrorDb, HookEvent } from '../types/index.js';

const ERROR_DB_FILE = 'error-correction.json';
const MIN_PATTERN_LENGTH = 8;
const TRIAD_THRESHOLD = 3;

interface ErrorFixResult {
  fixed: boolean;
  original: string;
  corrected?: string;
  fixType?: string;
  patternKey?: string;
}

interface ErrorCorrectionStats {
  totalErrors: number;
  uniquePatterns: number;
  totalFixes: number;
  triadsDetected: number;
  patternFrequency: Record<string, number>;
}

export class ErrorCorrection {
  private db: ErrorDb;
  private dbPath: string;
  private stats: ErrorCorrectionStats = {
    totalErrors: 0,
    uniquePatterns: 0,
    totalFixes: 0,
    triadsDetected: 0,
    patternFrequency: {},
  };

  constructor(private storeDir: string) {
    this.dbPath = `${storeDir}/${ERROR_DB_FILE}`;
    this.db = this.emptyDb();
  }

  async initialize(): Promise<void> {
    try {
      const data = await fs.readFile(this.dbPath, 'utf-8');
      this.db = JSON.parse(data);
      this.stats.uniquePatterns = this.db.patterns.length;
    } catch {
      this.db = this.emptyDb();
      await this.persist();
    }
  }

  /**
   * Record an error for pattern detection and auto-correction.
   * If the same pattern repeats TRIAD_THRESHOLD+ times, auto-fix triggers.
   */
  async record(message: string, context: string): Promise<ErrorFixResult | null> {
    this.stats.totalErrors++;

    const normalized = this.normalize(message);
    const key = this.makeKey(normalized);
    const ts = Date.now();

    const existing = this.db.patterns.find((p) => p.key === key);
    if (existing) {
      existing.count++;
      existing.lastSeen = ts;
      existing.context = context;
    } else {
      this.db.patterns.push({
        key,
        original: message,
        count: 1,
        firstSeen: ts,
        lastSeen: ts,
        context,
      });
      this.stats.uniquePatterns++;
    }

    this.stats.patternFrequency[key] = (this.stats.patternFrequency[key] || 0) + 1;

    // Check triad — 3+ occurrences triggers auto-fix attempt
    const pattern = existing || this.db.patterns[this.db.patterns.length - 1];
    if (pattern.count >= TRIAD_THRESHOLD) {
      this.stats.triadsDetected++;
      const fixResult = this.attemptAutoFix(message, key);
      if (fixResult.fixed) {
        this.stats.totalFixes++;
        this.db.fixes.push(`${fixResult.fixType}: ${message} -> ${fixResult.corrected}`);
        this.db.learnings.push(`Learned: ${fixResult.fixType} for pattern '${key}'`);
      }
      await this.persist();
      return fixResult;
    }

    // Persist every 10 errors
    if (this.stats.totalErrors % 10 === 0) {
      await this.persist();
    }

    return null;
  }

  /**
   * Check if error is a common recurring one and return known fix.
   */
  async diagnose(message: string): Promise<{ pattern: ErrorPattern | null; count: number }> {
    const normalized = this.normalize(message);
    const key = this.makeKey(normalized);
    const pattern = this.db.patterns.find((p) => p.key === key) ?? null;
    return { pattern, count: pattern?.count ?? 0 };
  }

  /**
   * Return all learnings extracted from error patterns.
   */
  getLearnings(): string[] {
    return [...this.db.learnings];
  }

  /**
   * Return error correction stats.
   */
  getStats(): ErrorCorrectionStats {
    return { ...this.stats };
  }

  /**
   * Clean old patterns (older than 30 days, count < 3).
   */
  async prune(maxAgeDays = 30): Promise<number> {
    const cutoff = Date.now() - maxAgeDays * 86400 * 1000;
    const before = this.db.patterns.length;
    this.db.patterns = this.db.patterns.filter(
      (p) => p.lastSeen >= cutoff || p.count >= TRIAD_THRESHOLD,
    );
    const removed = before - this.db.patterns.length;
    this.stats.uniquePatterns = this.db.patterns.length;
    if (removed > 0) await this.persist();
    return removed;
  }

  /**
   * Reset all error correction data.
   */
  async reset(): Promise<void> {
    this.db = this.emptyDb();
    this.stats = {
      totalErrors: 0,
      uniquePatterns: 0,
      totalFixes: 0,
      triadsDetected: 0,
      patternFrequency: {},
    };
    await this.persist();
  }

  // ─── Private ───────────────────────────────────────────────────────

  private emptyDb(): ErrorDb {
    return {
      created: new Date().toISOString(),
      patterns: [],
      fixes: [],
      learnings: [],
    };
  }

  /**
   * Normalize error messages by collapsing variable content (numbers,
   * paths, timestamps, UUIDs, hex values, memory addresses).
   */
  private normalize(msg: string): string {
    let s = msg;

    // Collapse UUIDs
    s = s.replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, '<UUID>');

    // Collapse hex (memory addresses, hashes)
    s = s.replace(/\b0x[0-9a-f]{4,}\b/gi, '<HEX>');

    // Collapse file paths (absolute and relative)
    s = s.replace(/\/(?:[^/\s]+\/)+[^/\s]*/g, '<PATH>');

    // Collapse numbers (including floating point)
    s = s.replace(/\b\d+(?:\.\d+)?\b/g, '<N>');

    // Collapse timestamps (ISO 8601)
    s = s.replace(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?/g, '<TS>');

    // Collapse durations like "1234ms", "5.2s"
    s = s.replace(/\b\d+(?:\.\d+)?(?:ms|s|μs|ns)\b/g, '<DUR>');

    // Collapse port numbers
    s = s.replace(/:\d{2,5}(?:\/|$|\s)/g, ':<PORT> ');

    // Collapse stack-trace line numbers
    s = s.replace(/:(\d+):(\d+)/g, ':<L>:<C>');

    // Collapse version numbers (semver)
    s = s.replace(/\b\d+\.\d+\.\d+(?:-\w+(?:\.\d+)?)?\b/g, '<VER>');

    // Normalize whitespace
    s = s.replace(/\s+/g, ' ').trim();

    return s;
  }

  private makeKey(normalized: string): string {
    if (normalized.length < MIN_PATTERN_LENGTH) {
      // Use first meaningful segment for short messages
      const parts = normalized.split(/:|\s/);
      return parts.find((p) => p.length >= 4) ?? normalized;
    }
    // Use first 120 chars as key (collisions intentional — same root error)
    return normalized.substring(0, 120);
  }

  /**
   * Attempt to auto-fix known error patterns using regex replacement.
   * Returns a fix result when a known pattern matches.
   */
  private attemptAutoFix(message: string, key: string): ErrorFixResult {
    // Common fix patterns
    const fixes: Array<{ pattern: RegExp; replacement: string; type: string }> = [
      // ENOENT errors → suggest mkdir
      { pattern: /ENOENT.*no such file or directory/i, replacement: '', type: 'mkdir-parent' },
      // EACCES → suggest chmod
      { pattern: /EACCES.*permission denied/i, replacement: '', type: 'chmod-fix' },
      // ECONNREFUSED → suggest retry
      { pattern: /ECONNREFUSED/i, replacement: '', type: 'retry-connection' },
      // ETIMEOUT → suggest retry with backoff
      { pattern: /ETIMEDOUT|timeout/i, replacement: '', type: 'retry-backoff' },
      // Module not found → suggest install
      { pattern: /cannot find module|module not found/i, replacement: '', type: 'install-module' },
      // JSON parse error → suggest validate
      { pattern: /unexpected token.*json|json.*parse/i, replacement: '', type: 'validate-json' },
      // Syntax error
      { pattern: /syntaxerror/i, replacement: '', type: 'syntax-check' },
      // Out of memory
      { pattern: /out of memory|cannot allocate memory/i, replacement: '', type: 'memory-limit' },
      // Disk full
      { pattern: /no space left on device/i, replacement: '', type: 'disk-cleanup' },
      // Address in use
      { pattern: /address already in use|eaddrinuse/i, replacement: '', type: 'port-conflict' },
    ];

    for (const fix of fixes) {
      if (fix.pattern.test(message)) {
        return {
          fixed: true,
          original: message,
          corrected: message.replace(fix.pattern, `[auto-fix: ${fix.type}]`),
          fixType: fix.type,
          patternKey: key,
        };
      }
    }

    return { fixed: false, original: message };
  }

  private async persist(): Promise<void> {
    const dir = this.storeDir;
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(this.dbPath, JSON.stringify(this.db, null, 2), 'utf-8');
  }
}
