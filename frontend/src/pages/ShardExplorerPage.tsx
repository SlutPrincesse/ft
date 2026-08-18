import { useState, useEffect } from 'react'
import Layout from '../components/Layout'
import { useShards } from '../hooks/useIngestion'
import { semanticSearch } from '../utils/api'

export default function ShardExplorerPage() {
  const { shards, loading, categories, refresh, parse } = useShards()
  const [filterCat, setFilterCat] = useState<string>('')
  const [filterType, setFilterType] = useState<string>('')
  const [search, setSearch] = useState('')
  const [selectedShard, setSelectedShard] = useState<any>(null)
  const [repoUrl, setRepoUrl] = useState('')
  const [parsing, setParsing] = useState(false)
  const [semanticQuery, setSemanticQuery] = useState('')
  const [semanticResults, setSemanticResults] = useState<any[]>([])
  const [semanticLoading, setSemanticLoading] = useState(false)

  useEffect(() => {
    refresh({ category: filterCat || undefined, shard_type: filterType || undefined, name_contains: search || undefined })
  }, [filterCat, filterType, search])

  const handleParse = async () => {
    if (!repoUrl.trim()) return
    setParsing(true)
    try {
      await parse(repoUrl.trim())
    } finally {
      setParsing(false)
    }
  }

  const handleSemanticSearch = async () => {
    if (!semanticQuery.trim()) return
    setSemanticLoading(true)
    try {
      const res = await semanticSearch(semanticQuery)
      setSemanticResults(res.results || [])
    } finally {
      setSemanticLoading(false)
    }
  }

  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-white">Python Shard Explorer</h1>
            <p className="mt-2 text-gray-400">Browse, search, and inspect parsed Python functions, classes, and modules.</p>
          </div>
          <div className="flex gap-2">
            <input
              value={repoUrl}
              onChange={(e) => setRepoUrl(e.target.value)}
              placeholder="Repo URL to parse..."
              className="rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white font-mono"
            />
            <button
              onClick={handleParse}
              disabled={parsing}
              className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {parsing ? 'Parsing...' : 'Parse Repo'}
            </button>
          </div>
        </div>

        <div className="rounded-lg border border-gray-800 bg-gray-950 p-4">
          <h3 className="text-sm font-medium text-white mb-2">Semantic Search</h3>
          <div className="flex gap-2">
            <input
              value={semanticQuery}
              onChange={(e) => setSemanticQuery(e.target.value)}
              placeholder="Search by meaning (e.g., async HTTP client)..."
              className="flex-1 rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white"
            />
            <button
              onClick={handleSemanticSearch}
              disabled={semanticLoading || !semanticQuery.trim()}
              className="rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-500 disabled:opacity-50"
            >
              {semanticLoading ? 'Searching...' : 'Semantic Search'}
            </button>
          </div>
          {semanticResults.length > 0 && (
            <div className="mt-3 space-y-2">
              {semanticResults.map((r: any) => (
                <div key={r.shard_id} className="rounded-md bg-gray-900 p-3 border border-gray-700">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium text-white">{r.metadata?.name || r.shard_id}</span>
                    <span className="text-xs text-gray-400">score: {(r.score * 100).toFixed(1)}%</span>
                  </div>
                  <p className="text-xs text-gray-400 mt-1">{r.text.slice(0, 120)}...</p>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="flex gap-4">
          <select
            value={filterCat}
            onChange={(e) => setFilterCat(e.target.value)}
            className="rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white"
          >
            <option value="">All Categories</option>
            {categories.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white"
          >
            <option value="">All Types</option>
            <option value="function">Function</option>
            <option value="class">Class</option>
            <option value="module">Module</option>
          </select>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search shards..."
            className="flex-1 rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white"
          />
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2 rounded-lg border border-gray-800 bg-gray-950">
            <div className="divide-y divide-gray-800">
              {loading && <div className="px-6 py-8 text-center text-gray-500">Loading...</div>}
              {!loading && shards.length === 0 && (
                <div className="px-6 py-8 text-center text-gray-500">No shards found. Parse a repository first.</div>
              )}
              {shards.map((s) => (
                <div
                  key={s.shard_id}
                  onClick={() => setSelectedShard(s)}
                  className={`cursor-pointer px-6 py-4 hover:bg-gray-900 ${selectedShard?.shard_id === s.shard_id ? 'bg-gray-900' : ''}`}
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-medium text-white">{s.name}</div>
                      <div className="text-xs text-gray-500">{s.source_file}</div>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="rounded-full bg-gray-800 px-2 py-1 text-xs text-gray-300">{s.shard_type}</span>
                      <span className="rounded-full bg-indigo-900 px-2 py-1 text-xs text-indigo-300">{s.category}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-lg border border-gray-800 bg-gray-950 p-6">
            {selectedShard ? (
              <div className="space-y-4">
                <h3 className="text-lg font-semibold text-white">{selectedShard.name}</h3>
                <div className="space-y-2 text-sm">
                  <div><span className="text-gray-500">Type:</span> <span className="text-white">{selectedShard.shard_type}</span></div>
                  <div><span className="text-gray-500">Category:</span> <span className="text-white">{selectedShard.category}</span></div>
                  <div><span className="text-gray-500">Complexity:</span> <span className="text-white">{selectedShard.cyclomatic_complexity}</span></div>
                  <div><span className="text-gray-500">Source:</span> <span className="text-gray-300 font-mono text-xs">{selectedShard.source_file}</span></div>
                  <div><span className="text-gray-500">Description:</span> <span className="text-gray-300">{selectedShard.description}</span></div>
                  <div>
                    <span className="text-gray-500">Dependencies:</span>
                    <div className="mt-1 flex flex-wrap gap-1">
                      {selectedShard.import_dependencies.map((d: string) => (
                        <span key={d} className="rounded bg-gray-800 px-2 py-1 text-xs text-gray-300">{d}</span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="text-center text-gray-500">Select a shard to view details.</div>
            )}
          </div>
        </div>
      </div>
    </Layout>
  )
}
