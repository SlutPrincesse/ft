export interface Shard {
  id: string;
  language: 'python' | 'typescript' | 'rust';
  category: string;
  source_repo: string | null;
  complexity_score: number;
  dependency_vector: string | null;
  description: string;
  file_path: string;
}

export interface StoreStats {
  total_shards: number;
  by_language: Record<string, number>;
  by_category: Record<string, number>;
}

export interface IngestResult {
  repo_url: string;
  clone_path: string;
  files_scanned: number;
  files_by_ext: Record<string, number>;
}

export interface SynthesisOptions {
  output_format: 'single-file' | 'modular';
  language: string;
  deduplicate: boolean;
  dry_run: boolean;
}

export interface SynthesisRequest {
  shard_ids: string[];
  options: SynthesisOptions;
}

export interface SynthOutput {
  content: string;
  format: string;
  language: string;
}

export interface BlueprintRequest {
  shard_ids: string[];
}

export interface NormalizeRequest {
  code: string;
  rule_ids: string[];
}
