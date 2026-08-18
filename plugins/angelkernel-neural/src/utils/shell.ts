import { execFile, spawn } from 'node:child_process';
import { ExecOptions, ExecResult } from '../types/index.js';

export async function run(
  command: string,
  args: string[] = [],
  options: ExecOptions = {},
): Promise<ExecResult> {
  return new Promise((resolve) => {
    const start = Date.now();
    const child = execFile(command, args, {
      timeout: options.timeout ?? 30000,
      env: { ...process.env, ...options.env },
      cwd: options.cwd,
      maxBuffer: 1024 * 1024,
    }, (err, stdout, stderr) => {
      resolve({
        stdout: stdout ?? '',
        stderr: stderr ?? '',
        exitCode: err ? (typeof err.code === 'number' ? err.code : 1) : 0,
        duration: Date.now() - start,
      });
    });
  });
}

export async function runBash(
  script: string,
  options: ExecOptions = {},
): Promise<ExecResult> {
  return run('/bin/bash', ['-c', script], options);
}

export function spawnProcess(
  command: string,
  args: string[] = [],
  options: { cwd?: string; env?: Record<string, string> } = {},
) {
  const child = spawn(command, args, {
    stdio: 'inherit',
    env: { ...process.env, ...options.env },
    cwd: options.cwd,
  });
  return child;
}

export function formatExecResult(r: ExecResult): string {
  const parts: string[] = [];
  if (r.stdout) parts.push(r.stdout);
  if (r.stderr) parts.push(`stderr: ${r.stderr}`);
  parts.push(`(exit ${r.exitCode}, ${r.duration}ms)`);
  return parts.join('\n');
}
