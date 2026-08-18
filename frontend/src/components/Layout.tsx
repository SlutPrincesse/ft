export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-gray-900 text-gray-100">
      <nav className="border-b border-gray-800 bg-gray-950">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="h-8 w-8 rounded bg-indigo-500 flex items-center justify-center font-bold text-white">P9</div>
              <span className="text-xl font-bold text-white">PyShard-P9</span>
            </div>
            <div className="flex gap-6 text-sm">
              <a href="/" className="text-gray-300 hover:text-white">Ingestion</a>
              <a href="/#/shards" className="text-gray-300 hover:text-white">Shard Explorer</a>
              <a href="/#/ideation" className="text-gray-300 hover:text-white">Ideation</a>
              <a href="/#/synthesis" className="text-gray-300 hover:text-white">Synthesis</a>
            </div>
          </div>
        </div>
      </nav>
      <main className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>
    </div>
  )
}
