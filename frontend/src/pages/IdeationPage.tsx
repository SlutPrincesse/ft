import { useState } from 'react'
import Layout from '../components/Layout'
import { useShards } from '../hooks/useIngestion'
import { generateBlueprint, checkCompatibility } from '../utils/api'

export default function IdeationPage() {
  const { shards } = useShards()
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const [appName, setAppName] = useState('My Synthesized App')
  const [blueprint, setBlueprint] = useState<string | null>(null)
  const [compat, setCompat] = useState<any>(null)
  const [loading, setLoading] = useState(false)

  const toggle = (id: string) => {
    setSelectedIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id])
  }

  const handleAnalyze = async () => {
    setLoading(true)
    try {
      const [bp, c] = await Promise.all([
        generateBlueprint({ shard_ids: selectedIds, app_name: appName }),
        checkCompatibility(selectedIds),
      ])
      setBlueprint(bp.blueprint)
      setCompat(c)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Layout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-white">Ideation & Blueprint Studio</h1>
          <p className="mt-2 text-gray-400">Drag-and-drop workspace for building virtual apps from shards.</p>
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2 rounded-lg border border-gray-800 bg-gray-950">
            <div className="border-b border-gray-800 px-6 py-4">
              <h2 className="text-lg font-semibold text-white">Available Shards</h2>
            </div>
            <div className="max-h-96 overflow-y-auto divide-y divide-gray-800">
              {shards.map((s) => (
                <div
                  key={s.shard_id}
                  onClick={() => toggle(s.shard_id)}
                  className={`cursor-pointer px-6 py-3 hover:bg-gray-900 ${selectedIds.includes(s.shard_id) ? 'bg-indigo-900/30' : ''}`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className={`h-4 w-4 rounded border ${selectedIds.includes(s.shard_id) ? 'bg-indigo-500 border-indigo-500' : 'border-gray-600'}`} />
                      <div>
                        <div className="font-medium text-white">{s.name}</div>
                        <div className="text-xs text-gray-500">{s.shard_type} · {s.category}</div>
                      </div>
                    </div>
                    <span className="text-xs text-gray-500">{s.cyclomatic_complexity} cc</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="space-y-4">
            <div className="rounded-lg border border-gray-800 bg-gray-950 p-6">
              <label className="block text-sm font-medium text-gray-300">App Name</label>
              <input
                value={appName}
                onChange={(e) => setAppName(e.target.value)}
                className="mt-2 w-full rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white"
              />
              <button
                onClick={handleAnalyze}
                disabled={loading || selectedIds.length === 0}
                className="mt-4 w-full rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
              >
                {loading ? 'Analyzing...' : 'Generate Blueprint'}
              </button>
              <div className="mt-2 text-xs text-gray-500">{selectedIds.length} shard(s) selected</div>
            </div>

            {compat && (
              <div className={`rounded-lg border p-4 ${compat.compatible ? 'border-green-800 bg-green-900/20' : 'border-yellow-800 bg-yellow-900/20'}`}>
                <h4 className="font-medium text-white">Compatibility</h4>
                <p className="mt-1 text-sm text-gray-300">{compat.compatible ? 'Shards are compatible.' : 'Issues detected.'}</p>
                {compat.conflicts.length > 0 && (
                  <ul className="mt-2 list-inside list-disc text-xs text-yellow-300">
                    {compat.conflicts.map((c: string) => <li key={c}>{c}</li>)}
                  </ul>
                )}
                {compat.missing_links.length > 0 && (
                  <ul className="mt-2 list-inside list-disc text-xs text-yellow-300">
                    {compat.missing_links.map((m: string) => <li key={m}>{m}</li>)}
                  </ul>
                )}
              </div>
            )}
          </div>
        </div>

        {blueprint && (
          <div className="rounded-lg border border-gray-800 bg-gray-950 p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Architectural Blueprint</h3>
            <pre className="whitespace-pre-wrap rounded-md bg-gray-900 p-4 text-sm text-gray-300 font-mono">{blueprint}</pre>
          </div>
        )}
      </div>
    </Layout>
  )
}
