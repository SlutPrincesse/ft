const API_BASE = '/api/v1'

export async function ingestRepos(repoUrls: string[]): Promise<any[]> {
  const res = await fetch(`${API_BASE}/ingest/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ repo_urls: repoUrls }),
  })
  if (!res.ok) throw new Error('Failed to ingest repos')
  return res.json()
}

export async function getIngestionStatus(): Promise<any[]> {
  const res = await fetch(`${API_BASE}/ingest/status`)
  if (!res.ok) throw new Error('Failed to fetch status')
  return res.json()
}

export async function listFiles(repoUrl: string): Promise<any> {
  const res = await fetch(`${API_BASE}/ingest/files/${encodeURIComponent(repoUrl)}`)
  if (!res.ok) throw new Error('Failed to list files')
  return res.json()
}

export async function parseRepo(repoUrl: string): Promise<any> {
  const res = await fetch(`${API_BASE}/shards/parse/${encodeURIComponent(repoUrl)}`, { method: 'POST' })
  if (!res.ok) throw new Error('Failed to parse repo')
  return res.json()
}

export async function listShards(params?: { category?: string; shard_type?: string; name_contains?: string }): Promise<any[]> {
  const qs = new URLSearchParams()
  if (params?.category) qs.set('category', params.category)
  if (params?.shard_type) qs.set('shard_type', params.shard_type)
  if (params?.name_contains) qs.set('name_contains', params.name_contains)
  const res = await fetch(`${API_BASE}/shards/?${qs.toString()}`)
  if (!res.ok) throw new Error('Failed to list shards')
  return res.json()
}

export async function getShard(shardId: string): Promise<any> {
  const res = await fetch(`${API_BASE}/shards/${shardId}`)
  if (!res.ok) throw new Error('Failed to get shard')
  return res.json()
}

export async function getCategories(): Promise<{ categories: string[] }> {
  const res = await fetch(`${API_BASE}/shards/categories`)
  if (!res.ok) throw new Error('Failed to get categories')
  return res.json()
}

export async function synthesizeMonolithic(body: { shard_ids: string[]; app_name?: string; apply_normalization?: boolean }): Promise<any> {
  const res = await fetch(`${API_BASE}/synthesize/monolithic`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error('Failed to synthesize')
  return res.json()
}

export async function synthesizePackage(body: { shard_ids: string[]; mode?: string; app_name?: string; package_name?: string; apply_normalization?: boolean }): Promise<any> {
  const res = await fetch(`${API_BASE}/synthesize/package`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error('Failed to synthesize package')
  return res.json()
}

export async function generateBlueprint(body: { shard_ids: string[]; app_name?: string }): Promise<any> {
  const res = await fetch(`${API_BASE}/synthesize/blueprint`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error('Failed to generate blueprint')
  return res.json()
}

export async function checkCompatibility(shardIds: string[]): Promise<any> {
  const res = await fetch(`${API_BASE}/synthesize/compatibility`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ shard_ids: shardIds }),
  })
  if (!res.ok) throw new Error('Failed to check compatibility')
  return res.json()
}

export async function normalizeCode(body: { code: string; old_root?: string; new_root?: string }): Promise<any> {
  const res = await fetch(`${API_BASE}/synthesize/normalize`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error('Failed to normalize')
  return res.json()
}

export async function semanticSearch(query: string, topK: number = 5): Promise<any> {
  const res = await fetch(`${API_BASE}/shards/semantic-search?query=${encodeURIComponent(query)}&top_k=${topK}`, { method: 'POST' })
  if (!res.ok) throw new Error('Failed to search')
  return res.json()
}

export async function generateEnv(body: { imports: string[]; variables: string[]; package_name?: string }): Promise<any> {
  const res = await fetch(`${API_BASE}/synthesize/env`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error('Failed to generate env')
  return res.json()
}
