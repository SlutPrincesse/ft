use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Shard {
    pub id: String,
    pub language: String,
    pub category: String,
    pub source_repo: Option<String>,
    pub complexity_score: i32,
    pub dependency_vector: Option<String>,
    pub description: String,
    pub file_path: PathBuf,
}

impl Shard {
    pub fn new(language: &str, category: &str, source_repo: Option<String>, description: &str) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            language: language.to_string(),
            category: category.to_string(),
            source_repo,
            complexity_score: 1,
            dependency_vector: None,
            description: description.to_string(),
            file_path: PathBuf::new(),
        }
    }
}
