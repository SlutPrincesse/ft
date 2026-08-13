use git2::build::RepoBuilder;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use thiserror::Error;
use walkdir::WalkDir;

#[derive(Debug, Error, Serialize, Deserialize)]
pub enum IngestError {
    #[error("Git operation failed: {0}")]
    GitError(String),
    #[error("IO error: {0}")]
    IoError(String),
    #[error("Path not allowed: {0}")]
    PathNotAllowed(String),
}

impl From<git2::Error> for IngestError {
    fn from(e: git2::Error) -> Self {
        IngestError::GitError(e.to_string())
    }
}

impl From<std::io::Error> for IngestError {
    fn from(e: std::io::Error) -> Self {
        IngestError::IoError(e.to_string())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IngestOptions {
    pub url: String,
    pub branch: Option<String>,
    pub depth: Option<usize>,
    pub include_paths: Option<Vec<String>>,
    pub exclude_paths: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IngestResult {
    pub repo_url: String,
    pub clone_path: PathBuf,
    pub files_scanned: usize,
    pub files_by_ext: std::collections::HashMap<String, usize>,
}

pub struct RepoIngester {
    temp_base: PathBuf,
}

impl RepoIngester {
    pub fn new() -> Self {
        Self {
            temp_base: std::env::temp_dir().join("polyshard-ingest"),
        }
    }

    pub async fn ingest(&self, url: &str, options: IngestOptions) -> Result<IngestResult, IngestError> {
        std::fs::create_dir_all(&self.temp_base).map_err(|e| IngestError::IoError(e.to_string()))?;
        let repo_name = url.split('/').last().unwrap_or("repo").trim_end_matches(".git");
        let clone_path = self.temp_base.join(format!("{}-{}", repo_name, uuid::Uuid::new_v4().simple()));
        let mut cb = git2::FetchOptions::new();
        if let Some(depth) = options.depth {
            cb.depth(depth as i32);
        }
        let mut repo = RepoBuilder::new()
            .fetch_options(cb)
            .clone(url, &clone_path)?;
        if let Some(branch) = options.branch {
            repo.set_head(&format!("refs/heads/{}", branch))?;
            repo.checkout_head(Some(git2::build::CheckoutBuilder::new().force().dry_run()))?;
        }
        let mut files_by_ext = std::collections::HashMap::new();
        let mut files_scanned = 0usize;
        for entry in WalkDir::new(&clone_path) {
            let entry = entry.map_err(|e| IngestError::IoError(e.to_string()))?;
            let path = entry.path();
            if path.is_file() {
                if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
                    files_by_ext.entry(ext.to_string()).and_modify(|e| *e += 1).or_insert(1);
                }
                files_scanned += 1;
            }
        }
        Ok(IngestResult { repo_url: url.to_string(), clone_path, files_scanned, files_by_ext })
    }

    pub fn cleanup(&self, path: &PathBuf) -> Result<(), IngestError> {
        std::fs::remove_dir_all(path).map_err(|e| IngestError::IoError(e.to_string()))?;
        Ok(())
    }
}
