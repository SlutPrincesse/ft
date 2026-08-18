import { promises as fs } from 'node:fs';
import { dirname } from 'node:path';

export async function readJson<T>(path: string, fallback: T): Promise<T> {
  try {
    const data = await fs.readFile(path, 'utf-8');
    return JSON.parse(data) as T;
  } catch {
    return fallback;
  }
}

export async function writeJson(path: string, data: unknown): Promise<void> {
  await fs.mkdir(dirname(path), { recursive: true });
  await fs.writeFile(path, JSON.stringify(data, null, 2), 'utf-8');
}

export async function appendLine(path: string, line: string): Promise<void> {
  await fs.mkdir(dirname(path), { recursive: true });
  await fs.appendFile(path, line + '\n', 'utf-8');
}

export async function ensureDir(path: string): Promise<void> {
  await fs.mkdir(path, { recursive: true });
}

export async function fileExists(path: string): Promise<boolean> {
  try {
    await fs.access(path);
    return true;
  } catch {
    return false;
  }
}

export async function readLines(path: string): Promise<string[]> {
  try {
    const data = await fs.readFile(path, 'utf-8');
    return data.split('\n').filter((l) => l.trim().length > 0);
  } catch {
    return [];
  }
}

export function generateId(): string {
  return `${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
}

export function safeTimestamp(): number {
  return Date.now();
}

export function elapsed(start: number): string {
  const ms = Date.now() - start;
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  return `${Math.floor(ms / 60000)}m ${Math.floor((ms % 60000) / 1000)}s`;
}
