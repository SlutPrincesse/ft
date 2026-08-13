import { useState, useEffect } from 'react';

export default function App() {
  const [activePanel, setActivePanel] = useState<'ingest' | 'shards' | 'ideation' | 'synthesis'>('ingest');

  return (
    <div className="flex h-screen w-screen bg-surface-dark text-slate-200 overflow-hidden">
      <nav className="w-16 bg-surface border-r border-slate-800 flex flex-col items-center py-4 gap-2">
        <button onClick={() => setActivePanel('ingest')} className={`p-3 rounded-lg ${activePanel === 'ingest' ? 'bg-brand-600 text-white' : 'text-slate-400 hover:bg-surface-card'}`} title="Ingestion">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
        </button>
        <button onClick={() => setActivePanel('shards')} className={`p-3 rounded-lg ${activePanel === 'shards' ? 'bg-brand-600 text-white' : 'text-slate-400 hover:bg-surface-card'}`} title="Shard Explorer">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
        </button>
        <button onClick={() => setActivePanel('ideation')} className={`p-3 rounded-lg ${activePanel === 'ideation' ? 'bg-brand-600 text-white' : 'text-slate-400 hover:bg-surface-card'}`} title="Ideation">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>
        </button>
        <button onClick={() => setActivePanel('synthesis')} className={`p-3 rounded-lg ${activePanel === 'synthesis' ? 'bg-brand-600 text-white' : 'text-slate-400 hover:bg-surface-card'}`} title="Synthesis">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>
        </button>
      </nav>
      <main className="flex-1 overflow-auto p-6">
        {activePanel === 'ingest' && <IngestPanel />}
        {activePanel === 'shards' && <ShardExplorerPanel />}
        {activePanel === 'ideation' && <IdeationPanel />}
        {activePanel === 'synthesis' && <SynthesisPanel />}
      </main>
    </div>
  );
}

function IngestPanel() {
  const [url, setUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);

  const handleIngest = async () => {
    setLoading(true);
    try {
      const res = await (await import('./lib/api')).ingestRepo(url);
      setResult(res);
    } catch (e) {
      setResult({ error: String(e) });
    }
    setLoading(false);
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-white mb-2">Ingestion & Repository Matrix</h1>
      <div className="bg-surface-card rounded-xl p-6 border border-slate-800">
        <label className="block text-sm font-medium text-slate-400 mb-2">GitHub Repository URL</label>
        <div className="flex gap-3">
          <input value={url} onChange={e => setUrl(e.target.value)} placeholder="https://github.com/owner/repo" className="flex-1 bg-surface-dark border border-slate-700 rounded-lg px-4 py-2 text-white placeholder:text-slate-600 focus:outline-none focus:border-brand-500" />
          <button onClick={handleIngest} disabled={loading || !url} className="px-6 py-2 bg-brand-600 hover:bg-brand-500 disabled:opacity-50 rounded-lg font-medium transition">Ingest</button>
        </div>
        {loading && <p className="mt-3 text-brand-400">Cloning repository...</p>}
        {result && (
          <div className="mt-4 p-4 bg-surface-dark rounded-lg border border-slate-700">
            <p className="text-sm text-slate-400">Status</p>
            <pre className="text-xs text-green-400 mt-1 overflow-auto">{JSON.stringify(result, null, 2)}</pre>
          </div>
        )}
      </div>
    </div>
  );
}

function ShardExplorerPanel() {
  const [shards, setShards] = useState<any[]>([]);
  const [search, setSearch] = useState('');

  useEffect(() => {
    (async () => {
      const api = await import('./lib/api');
      const res = await api.listShards({ limit: 50 });
      setShards(res);
    })();
  }, []);

  return (
    <div className="max-w-6xl mx-auto space-y-4">
      <h1 className="text-3xl font-bold text-white mb-2">Polyglot Shard Explorer</h1>
      <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search shards..." className="w-full bg-surface-card border border-slate-700 rounded-lg px-4 py-2 text-white placeholder:text-slate-600 focus:outline-none focus:border-brand-500" />
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {shards.filter(s => !search || s.description.includes(search) || s.category.includes(search)).map(s => (
          <div key={s.id} className="bg-surface-card rounded-xl p-4 border border-slate-800 hover:border-brand-500 transition">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-mono text-brand-400 bg-brand-900/30 px-2 py-1 rounded">{s.language}</span>
              <span className="text-xs text-slate-500">{s.category}</span>
            </div>
            <p className="text-sm text-slate-300 line-clamp-2">{s.description}</p>
            <p className="text-xs text-slate-500 mt-2 font-mono truncate">{s.file_path}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function IdeationPanel() {
  const [blueprint, setBlueprint] = useState<string>('');

  const generate = async () => {
    const res = await (await import('./lib/api')).generateBlueprint([]);
    setBlueprint(res);
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-white mb-2">Ideation & Blueprint Studio</h1>
      <button onClick={generate} className="px-6 py-2 bg-brand-600 hover:bg-brand-500 rounded-lg font-medium transition">Generate Blueprint</button>
      {blueprint && (
        <div className="bg-surface-card rounded-xl p-6 border border-slate-800">
          <pre className="text-sm text-slate-300 whitespace-pre-wrap font-mono">{blueprint}</pre>
        </div>
      )}
    </div>
  );
}

function SynthesisPanel() {
  const [output, setOutput] = useState('');
  const [loading, setLoading] = useState(false);

  const synthesize = async () => {
    setLoading(true);
    try {
      const res = await (await import('./lib/api')).synthesizeModules([], { output_format: 'single-file', language: 'python', deduplicate: true, dry_run: false });
      setOutput(res);
    } catch (e) {
      setOutput(String(e));
    }
    setLoading(false);
  };

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-white mb-2">Synthesis & Execution Monitor</h1>
      <button onClick={synthesize} disabled={loading} className="px-6 py-2 bg-brand-600 hover:bg-brand-500 disabled:opacity-50 rounded-lg font-medium transition">Synthesize Selected Shards</button>
      {loading && <p className="text-brand-400">Synthesizing...</p>}
      {output && (
        <div className="bg-surface-card rounded-xl p-6 border border-slate-800">
          <pre className="text-sm text-slate-300 whitespace-pre-wrap font-mono max-h-96 overflow-auto">{output}</pre>
        </div>
      )}
    </div>
  );
}
