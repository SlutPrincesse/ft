use crate::shard::Shard;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

pub struct SynthesisEngine;

impl SynthesisEngine {
    pub fn new() -> Self {
        Self
    }

    pub fn synthesize(&self, shards: &[Shard], options: SynthesisOptions) -> Result<SynthOutput, String> {
        match options.output_format.as_str() {
            "single-file" => self.synthesize_single_file(shards, &options),
            "modular" => self.synthesize_modular(shards, &options),
            _ => Err("Unsupported output format".to_string()),
        }
    }

    fn synthesize_single_file(&self, shards: &[Shard], _options: &SynthesisOptions) -> Result<SynthOutput, String> {
        let lang = shards.first().map(|s| s.language.as_str()).unwrap_or("python");
        let mut header = String::new();
        header.push_str(&format!("# PolyShard-P9 Synthesized Output\n# Generated: {}\n# Shards: {}\n\n", chrono::Utc::now().to_rfc3339(), shards.len()));
        let mut seen = HashSet::new();
        let mut body = String::new();
        for shard in shards {
            if let Ok(content) = std::fs::read_to_string(&shard.file_path) {
                let normalized = Self::dedup_content(&content, &mut seen);
                body.push_str(&format!("// Shard: {} ({})\n{}\n\n", shard.id, shard.description, normalized));
            }
        }
        Ok(SynthOutput { content: header + &body, format: "single-file".to_string(), language: lang.to_string() })
    }

    fn synthesize_modular(&self, shards: &[Shard], options: &SynthesisOptions) -> Result<SynthOutput, String> {
        self.synthesize_single_file(shards, options)
    }

    fn dedup_content(content: &str, seen: &mut HashSet<String>) -> String {
        let mut out = String::new();
        for line in content.lines() {
            let trimmed = line.trim();
            if !seen.contains(trimmed) && !trimmed.is_empty() {
                seen.insert(trimmed.to_string());
                out.push_str(line);
                out.push('\n');
            }
        }
        out
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SynthesisOptions {
    pub output_format: String,
    pub language: String,
    pub deduplicate: bool,
    pub dry_run: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SynthOutput {
    pub content: String,
    pub format: String,
    pub language: String,
}
