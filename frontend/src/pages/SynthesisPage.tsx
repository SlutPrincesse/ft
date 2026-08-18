import { useState } from 'react'
import Layout from '../components/Layout'
import { useShards } from '../hooks/useIngestion'
import { synthesizeMonolithic, synthesizePackage, normalizeCode, generateEnv } from '../utils/api'

export default function SynthesisPage() {
  const { shards } = useShards()
  const [selectedIds] = useState<string[]>([])
  const [mode, setMode] = useState<'monolithic' | 'package'>('monolithic')
  const [appName, setAppName] = useState('synthesized_app')
  const [output, setOutput] = useState<any>(null)
  const [loading, setLoading] = useState(false)

  const handleSynthesize = async () => {
    setLoading(true)
    try {
      if (mode === 'monolithic') {
        const res = await synthesizeMonolithic({ shard_ids: selectedIds, app_name: appName, apply_normalization: true })
        setOutput({ type: 'monolithic', ...res })
      } else {
        const res = await synthesizePackage({ shard_ids: selectedIds, app_name: appName, package_name: appName.replace(/\s+/g, '_').toLowerCase(), apply_normalization: true })
        setOutput({ type: 'package', ...res })
      }
    } finally {
      setLoading(false)
    }
  }

  const handleNormalize = async () => {
    if (!output?.code) return
    const res = await normalizeCode({ code: output.code })
    setOutput({ ...output, code: res.normalized })
  }

  const handleEnv = async () => {
    const imports = [...new Set(selectedIds.flatMap(id => {
      const s = shards.find(x => x.shard_id === id)
      return s?.import_dependencies || []
    }))]
    const res = await generateEnv({ imports, variables: ['API_KEY', 'DATABASE_URL'], package_name: appName })
    setOutput({ ...output, env: res })
  }

  return (
    <Layout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-white">Synthesis & Execution Monitor</h1>
          <p className="mt-2 text-gray-400">Combine selected shards into optimized code with AST-level deduplication and LSP validation.</p>
        </div>

        <div className="flex items-center gap-4">
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value as 'monolithic' | 'package')}
            className="rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white"
          >
            <option value="monolithic">Monolithic Mode</option>
            <option value="package">Consolidated Package Mode</option>
          </select>
          <input
            value={appName}
            onChange={(e) => setAppName(e.target.value)}
            placeholder="App / package name"
            className="rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white"
          />
          <button
            onClick={handleSynthesize}
            disabled={loading || selectedIds.length === 0}
            className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            {loading ? 'Synthesizing...' : 'Synthesize'}
          </button>
          <button
            onClick={handleNormalize}
            disabled={!output?.code}
            className="rounded-md bg-gray-700 px-4 py-2 text-sm font-medium text-white hover:bg-gray-600 disabled:opacity-50"
          >
            Normalize
          </button>
          <button
            onClick={handleEnv}
            disabled={selectedIds.length === 0}
            className="rounded-md bg-gray-700 px-4 py-2 text-sm font-medium text-white hover:bg-gray-600 disabled:opacity-50"
          >
            Generate Env
          </button>
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="lg:col-span-1 rounded-lg border border-gray-800 bg-gray-950">
            <div className="border-b border-gray-800 px-6 py-4">
              <h2 className="text-lg font-semibold text-white">Selected Shards ({selectedIds.length})</h2>
            </div>
            <div className="max-h-96 overflow-y-auto divide-y divide-gray-800">
              {shards.filter(s => selectedIds.includes(s.shard_id)).map((s) => (
                <div key={s.shard_id} className="px-6 py-3">
                  <div className="font-medium text-white">{s.name}</div>
                  <div className="text-xs text-gray-500">{s.shard_type} · {s.category}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="lg:col-span-2 rounded-lg border border-gray-800 bg-gray-950">
            <div className="border-b border-gray-800 px-6 py-4">
              <h2 className="text-lg font-semibold text-white">Output</h2>
            </div>
            <div className="p-6">
              {!output && (
                <div className="text-center text-gray-500">Select shards and synthesize to see output.</div>
              )}
              {output?.type === 'monolithic' && (
                <pre className="whitespace-pre-wrap rounded-md bg-gray-900 p-4 text-sm text-gray-300 font-mono max-h-96 overflow-y-auto">{output.code}</pre>
              )}
              {output?.type === 'package' && (
                <div className="space-y-4">
                  {Object.entries(output.files).map(([path, content]) => (
                    <div key={path}>
                      <div className="text-sm font-medium text-white mb-1">{path}</div>
                      <pre className="whitespace-pre-wrap rounded-md bg-gray-900 p-4 text-sm text-gray-300 font-mono max-h-48 overflow-y-auto">{content as string}</pre>
                    </div>
                  ))}
                  <div>
                    <div className="text-sm font-medium text-white mb-1">pyproject.toml</div>
                    <pre className="whitespace-pre-wrap rounded-md bg-gray-900 p-4 text-sm text-gray-300 font-mono">{output.pyproject}</pre>
                  </div>
                  <div>
                    <div className="text-sm font-medium text-white mb-1">__init__.py</div>
                    <pre className="whitespace-pre-wrap rounded-md bg-gray-900 p-4 text-sm text-gray-300 font-mono">{output.init_py}</pre>
                  </div>
                </div>
              )}
              {output?.env && (
                <div className="mt-4 space-y-4">
                  <div>
                    <div className="text-sm font-medium text-white mb-1">requirements.txt</div>
                    <pre className="whitespace-pre-wrap rounded-md bg-gray-900 p-4 text-sm text-gray-300 font-mono">{output.env.requirements_txt}</pre>
                  </div>
                  <div>
                    <div className="text-sm font-medium text-white mb-1">pyproject.toml</div>
                    <pre className="whitespace-pre-wrap rounded-md bg-gray-900 p-4 text-sm text-gray-300 font-mono">{output.env.pyproject_toml}</pre>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </Layout>
  )
}
