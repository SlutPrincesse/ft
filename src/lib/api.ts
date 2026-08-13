import { invoke } from '@tauri-apps/api/core';
import type { Shard, SynthesisOptions, StoreStats } from './types';

export async function ingestRepo(url: string, branch?: string, depth?: number): Promise<{ repo_url: string; clone_path: string; files_scanned: number; files_by_ext: Record<string, number>; }> {
  return invoke('ingest_repo', { url, branch, depth });
}

export async function extractShards(path: string): Promise<Shard[]> {
  return invoke('extract_shards', { path });
}

export async function listShards(filter: { language?: string; category?: string; limit?: number; offset?: number }): Promise<Shard[]> {
  return invoke('list_shards', { filter });
}

export async function getShard(id: string): Promise<Shard | null> {
  return invoke('get_shard', { id });
}

export async function deleteShard(id: string): Promise<void> {
  return invoke('delete_shard', { id });
}

export async function searchShards(query: string): Promise<Shard[]> {
  return invoke('search_shards', { query });
}

export async function synthesizeModules(shardIds: string[], options: SynthesisOptions): Promise<string> {
  return invoke('synthesize_modules', { shard_ids: shardIds, options });
}

export async function normalizeCode(code: string, ruleIds: string[]): Promise<string> {
  return invoke('normalize_code', { code, rule_ids: ruleIds });
}

export async function generateBlueprint(shards: Shard[]): Promise<string> {
  return invoke('generate_blueprint', { shards });
}

export async function getStoreStats(): Promise<StoreStats> {
  return invoke('get_store_stats');
}
