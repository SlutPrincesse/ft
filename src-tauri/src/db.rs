use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use crate::shard::Shard;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoreStats {
    pub total_shards: usize,
    pub by_language: std::collections::HashMap<String, usize>,
    pub by_category: std::collections::HashMap<String, usize>,
}

pub struct ShardStore {
    base_path: PathBuf,
    conn: Connection,
}

impl ShardStore {
    pub fn new<P: AsRef<Path>>(base: P) -> Result<Self, String> {
        let base_path = base.as_ref().to_path_buf();
        fs::create_dir_all(&base_path).map_err(|e| e.to_string())?;
        for lang in &["python", "typescript", "rust"] {
            fs::create_dir_all(base_path.join(lang).join("shards")).map_err(|e| e.to_string())?;
        }
        let db_path = base_path.join("metadata.db");
        let conn = Connection::open(db_path).map_err(|e| e.to_string())?;
        conn.execute_batch("
            CREATE TABLE IF NOT EXISTS shards (
                id TEXT PRIMARY KEY,
                language TEXT NOT NULL,
                category TEXT NOT NULL,
                source_repo TEXT,
                complexity_score INTEGER DEFAULT 0,
                dependency_vector TEXT,
                description TEXT,
                file_path TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_language ON shards(language);
            CREATE INDEX IF NOT EXISTS idx_category ON shards(category);
            CREATE INDEX IF NOT EXISTS idx_source_repo ON shards(source_repo);
        ").map_err(|e| e.to_string())?;
        Ok(Self { base_path, conn })
    }

    pub fn insert_shard(&self, shard: &Shard) -> Result<(), String> {
        let now = chrono::Utc::now().to_rfc3339();
        self.conn.execute(
            "INSERT OR REPLACE INTO shards (id, language, category, source_repo, complexity_score, dependency_vector, description, file_path, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, COALESCE((SELECT created_at FROM shards WHERE id = ?1), ?9), ?9)",
            params![
                shard.id,
                shard.language,
                shard.category,
                shard.source_repo,
                shard.complexity_score,
                shard.dependency_vector,
                shard.description,
                shard.file_path.to_string_lossy().to_string(),
                now,
            ],
        ).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn get_shard(&self, id: &str) -> Result<Option<Shard>, String> {
        let mut stmt = self.conn.prepare("SELECT id, language, category, source_repo, complexity_score, dependency_vector, description, file_path FROM shards WHERE id = ?1").map_err(|e| e.to_string())?;
        let result = stmt.query_row(params![id], |row| {
            Ok(Shard {
                id: row.get(0).map_err(|e| e.to_string()).unwrap(),
                language: row.get(1).map_err(|e| e.to_string()).unwrap(),
                category: row.get(2).map_err(|e| e.to_string()).unwrap(),
                source_repo: row.get(3).map_err(|e| e.to_string()).unwrap(),
                complexity_score: row.get(4).map_err(|e| e.to_string()).unwrap(),
                dependency_vector: row.get(5).map_err(|e| e.to_string()).unwrap(),
                description: row.get(6).map_err(|e| e.to_string()).unwrap(),
                file_path: PathBuf::from(row.get::<_, String>(7).map_err(|e| e.to_string()).unwrap()),
            })
        }).ok();
        Ok(result)
    }

    pub fn list_shards(&self, language: Option<&str>, category: Option<&str>, _limit: usize, _offset: usize) -> Result<Vec<Shard>, String> {
        let mut query = String::from("SELECT id, language, category, source_repo, complexity_score, dependency_vector, description, file_path FROM shards WHERE 1=1");
        let mut bindings = vec![];
        if let Some(lang) = language {
            query.push_str(" AND language = ?");
            bindings.push(lang.to_string());
        }
        if let Some(cat) = category {
            query.push_str(" AND category = ?");
            bindings.push(cat.to_string());
        }
        query.push_str(" ORDER BY updated_at DESC LIMIT ? OFFSET ?");
        let mut stmt = self.conn.prepare(&query).map_err(|e| e.to_string())?;
        let mut rows = stmt.query(rusqlite::params_from_iter(&bindings)).map_err(|e| e.to_string())?;
        let mut results = Vec::new();
        while let Some(row) = rows.next().map_err(|e| e.to_string())? {
            results.push(Shard {
                id: row.get(0).map_err(|e| e.to_string()).unwrap(),
                language: row.get(1).map_err(|e| e.to_string()).unwrap(),
                category: row.get(2).map_err(|e| e.to_string()).unwrap(),
                source_repo: row.get(3).map_err(|e| e.to_string()).unwrap(),
                complexity_score: row.get(4).map_err(|e| e.to_string()).unwrap(),
                dependency_vector: row.get(5).map_err(|e| e.to_string()).unwrap(),
                description: row.get(6).map_err(|e| e.to_string()).unwrap(),
                file_path: PathBuf::from(row.get::<_, String>(7).map_err(|e| e.to_string()).unwrap()),
            });
        }
        Ok(results)
    }

    pub fn delete_shard(&self, id: &str) -> Result<(), String> {
        self.conn.execute("DELETE FROM shards WHERE id = ?1", params![id]).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn search_shards(&self, query: &str) -> Result<Vec<Shard>, String> {
        let like = format!("%{}%", query);
        let mut stmt = self.conn.prepare("
            SELECT id, language, category, source_repo, complexity_score, dependency_vector, description, file_path
            FROM shards
            WHERE description LIKE ? OR category LIKE ? OR source_repo LIKE ? OR id LIKE ?
            ORDER BY updated_at DESC
        ").map_err(|e| e.to_string())?;
        let mut rows = stmt.query(params![&like, &like, &like, &like]).map_err(|e| e.to_string())?;
        let mut results = Vec::new();
        while let Some(row) = rows.next().map_err(|e| e.to_string())? {
            results.push(Shard {
                id: row.get(0).map_err(|e| e.to_string()).unwrap(),
                language: row.get(1).map_err(|e| e.to_string()).unwrap(),
                category: row.get(2).map_err(|e| e.to_string()).unwrap(),
                source_repo: row.get(3).map_err(|e| e.to_string()).unwrap(),
                complexity_score: row.get(4).map_err(|e| e.to_string()).unwrap(),
                dependency_vector: row.get(5).map_err(|e| e.to_string()).unwrap(),
                description: row.get(6).map_err(|e| e.to_string()).unwrap(),
                file_path: PathBuf::from(row.get::<_, String>(7).map_err(|e| e.to_string()).unwrap()),
            });
        }
        Ok(results)
    }

    pub fn get_stats(&self) -> Result<StoreStats, String> {
        let total: i64 = self.conn.query_row("SELECT COUNT(*) FROM shards", [], |r| r.get(0)).map_err(|e| e.to_string())?;
        let mut by_lang = std::collections::HashMap::new();
        let mut by_cat = std::collections::HashMap::new();
        let mut stmt = self.conn.prepare("SELECT language, category, COUNT(*) FROM shards GROUP BY language, category").map_err(|e| e.to_string())?;
        let rows = stmt.query_map([], |r| {
            Ok((
                r.get(0).map_err(|e| e.to_string()).unwrap(),
                r.get(1).map_err(|e| e.to_string()).unwrap(),
                r.get(2).map_err(|e| e.to_string()).unwrap(),
            ))
        }).map_err(|e| e.to_string())?;
        for row in rows {
            let (lang, cat, count): (String, String, i64) = row.map_err(|e| e.to_string())?;
            *by_lang.entry(lang).or_insert(0) += count as usize;
            *by_cat.entry(cat).or_insert(0) += count as usize;
        }
        Ok(StoreStats { total_shards: total as usize, by_language: by_lang, by_category: by_cat })
    }

    pub fn base_path(&self) -> &Path {
        &self.base_path
    }
}
