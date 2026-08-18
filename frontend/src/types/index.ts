export interface RepoStatus {
  repo_url: string
  local_path: string
  status: string
  files_count: number
  error?: string
}

export interface ShardRecord {
  shard_id: string
  category: string
  shard_type: string
  source_repo: string
  source_file: string
  name: string
  description: string
  cyclomatic_complexity: number
  import_dependencies: string[]
  tags: string[]
  source_code?: string
}

export interface BlueprintResponse {
  blueprint: string
  shards_count: number
  conflicts: string[]
}

export interface CompatibilityResponse {
  compatible: boolean
  conflicts: string[]
  missing_links: string[]
}

export interface SynthesisResponse {
  mode: string
  app_name: string
  code: string
  shards_used: number
}

export interface PackageStructure {
  package_name: string
  files: Record<string, string>
  pyproject: string
  init_py: string
}

export interface EnvResponse {
  requirements_txt: string
  pyproject_toml: string
  env_template: string
  validation_script: string
}
