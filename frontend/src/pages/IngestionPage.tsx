import { useState } from 'react'
import Layout from '../components/Layout'
import { useIngestion } from '../hooks/useIngestion'

export default function IngestionPage() {
  const { repos, ingest } = useIngestion()
  const [urls, setUrls] = useState('')
  const [ingesting, setIngesting] = useState(false)

  const handleIngest = async () => {
    const repoList = urls.split('\n').map(u => u.trim()).filter(Boolean)
    if (!repoList.length) return
    setIngesting(true)
    try {
      await ingest(repoList)
      setUrls('')
    } finally {
      setIngesting(false)
    }
  }

  return (
    <Layout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-white">Repository Ingestion Matrix</h1>
          <p className="mt-2 text-gray-400">Clone and parse multiple GitHub repositories for Python shard extraction.</p>
        </div>

        <div className="rounded-lg border border-gray-800 bg-gray-950 p-6">
          <label className="block text-sm font-medium text-gray-300">GitHub Repository URLs (one per line)</label>
          <textarea
            value={urls}
            onChange={(e) => setUrls(e.target.value)}
            rows={4}
            className="mt-2 w-full rounded-md border border-gray-700 bg-gray-900 px-3 py-2 text-white font-mono text-sm focus:border-indigo-500 focus:outline-none"
            placeholder="https://github.com/user/repo1\nhttps://github.com/user/repo2"
          />
          <button
            onClick={handleIngest}
            disabled={ingesting || !urls.trim()}
            className="mt-4 rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            {ingesting ? 'Ingesting...' : 'Start Ingestion'}
          </button>
        </div>

        <div className="rounded-lg border border-gray-800 bg-gray-950">
          <div className="border-b border-gray-800 px-6 py-4">
            <h2 className="text-lg font-semibold text-white">Ingestion Status</h2>
          </div>
          <div className="divide-y divide-gray-800">
            {repos.length === 0 && (
              <div className="px-6 py-8 text-center text-gray-500">No repositories ingested yet.</div>
            )}
            {repos.map((repo) => (
              <div key={repo.repo_url} className="flex items-center justify-between px-6 py-4">
                <div>
                  <div className="font-mono text-sm text-white">{repo.repo_url}</div>
                  <div className="text-xs text-gray-500">{repo.local_path}</div>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-sm text-gray-400">{repo.files_count} files</span>
                  <span className={`rounded-full px-3 py-1 text-xs font-medium ${
                    repo.status === 'ready' ? 'bg-green-900 text-green-300' :
                    repo.status === 'error' ? 'bg-red-900 text-red-300' :
                    'bg-yellow-900 text-yellow-300'
                  }`}>
                    {repo.status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Layout>
  )
}
