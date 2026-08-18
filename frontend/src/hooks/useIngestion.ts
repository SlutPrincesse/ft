import { useEffect, useState } from 'react'
import { getIngestionStatus, ingestRepos, listShards, getCategories, parseRepo } from '../utils/api'
import type { RepoStatus, ShardRecord } from '../types'

export function useIngestion() {
  const [repos, setRepos] = useState<RepoStatus[]>([])
  const [loading, setLoading] = useState(false)

  const refresh = async () => {
    setLoading(true)
    try {
      const data = await getIngestionStatus()
      setRepos(data)
    } finally {
      setLoading(false)
    }
  }

  const ingest = async (urls: string[]) => {
    setLoading(true)
    try {
      const data = await ingestRepos(urls)
      setRepos(data)
      return data
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { refresh() }, [])

  return { repos, loading, refresh, ingest }
}

export function useShards() {
  const [shards, setShards] = useState<ShardRecord[]>([])
  const [loading, setLoading] = useState(false)
  const [categories, setCategories] = useState<string[]>([])

  const refresh = async (params?: { category?: string; shard_type?: string; name_contains?: string }) => {
    setLoading(true)
    try {
      const [data, cats] = await Promise.all([
        listShards(params),
        getCategories(),
      ])
      setShards(data)
      setCategories(cats.categories)
    } finally {
      setLoading(false)
    }
  }

  const parse = async (repoUrl: string) => {
    setLoading(true)
    try {
      const data = await parseRepo(repoUrl)
      await refresh()
      return data
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { refresh() }, [])

  return { shards, loading, categories, refresh, parse }
}
