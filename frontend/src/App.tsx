import { useState, useEffect } from 'react'
import IngestionPage from './pages/IngestionPage'
import ShardExplorerPage from './pages/ShardExplorerPage'
import IdeationPage from './pages/IdeationPage'
import SynthesisPage from './pages/SynthesisPage'

type Page = 'ingestion' | 'shards' | 'ideation' | 'synthesis'

export default function App() {
  const [page, setPage] = useState<Page>('ingestion')

  useEffect(() => {
    const hash = window.location.hash
    if (hash.includes('shards')) setPage('shards')
    else if (hash.includes('ideation')) setPage('ideation')
    else if (hash.includes('synthesis')) setPage('synthesis')
    else setPage('ingestion')
  }, [])

  const renderPage = () => {
    switch (page) {
      case 'ingestion': return <IngestionPage />
      case 'shards': return <ShardExplorerPage />
      case 'ideation': return <IdeationPage />
      case 'synthesis': return <SynthesisPage />
    }
  }

  return renderPage()
}
