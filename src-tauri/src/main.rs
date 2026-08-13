mod db;
mod ingest;
mod parser;
mod shard;
mod synthesis;
mod normalize;

use tokio::sync::Mutex;
use tauri::State;
use serde::{Deserialize, Serialize};

use db::ShardStore;
use ingest::{RepoIngester, IngestOptions, IngestResult};
use parser::ShardExtractor;
use synthesis::{SynthesisEngine, SynthesisOptions};
use normalize::NormalizationEngine;
use shard::Shard;

pub struct AppState {
    pub store: Mutex<ShardStore>,
    pub ingester: Mutex<RepoIngester>,
    pub extractor: Mutex<ShardExtractor>,
    pub synthesizer: Mutex<SynthesisEngine>,
    pub normalizer: Mutex<NormalizationEngine>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ShardFilter {
    pub language: Option<String>,
    pub category: Option<String>,
    pub limit: usize,
    pub offset: usize,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SynthesizeRequest {
    pub shard_ids: Vec<String>,
    pub options: SynthesisOptions,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NormalizeRequest {
    pub code: String,
    pub rule_ids: Vec<String>,
}

#[tauri::command]
async fn ingest_repo(state: State<'_, AppState>, req: IngestOptions) -> Result<IngestResult, String> {
    let url = req.url.clone();
    let branch = req.branch.clone();
    let depth = req.depth;
    let ingester = state.ingester.lock().await;
    let opts = IngestOptions { url: url.clone(), branch, depth, include_paths: req.include_paths.clone(), exclude_paths: req.exclude_paths.clone() };
    let result = ingester.ingest(&url, opts).await.map_err(|e| e.to_string())?;
    Ok(result)
}

#[tauri::command]
async fn extract_shards(state: State<'_, AppState>, path: String) -> Result<Vec<Shard>, String> {
    let mut extractor = state.extractor.lock().await;
    let path = std::path::Path::new(&path);
    let mut results = Vec::new();
    if path.is_dir() {
        for entry in walkdir::WalkDir::new(path) {
            let entry = entry.map_err(|e| e.to_string())?;
            let p = entry.path();
            if p.is_file() {
                if let Ok(content) = std::fs::read_to_string(p) {
                    let mut shards = extractor.extract_file(p, &content);
                    results.append(&mut shards);
                }
            }
        }
    } else if path.is_file() {
        if let Ok(content) = std::fs::read_to_string(path) {
            results = extractor.extract_file(path, &content);
        }
    }
    Ok(results)
}

#[tauri::command]
async fn list_shards(state: State<'_, AppState>, filter: ShardFilter) -> Result<Vec<Shard>, String> {
    let store = state.store.lock().await;
    store.list_shards(filter.language.as_deref(), filter.category.as_deref(), filter.limit, filter.offset)
}

#[tauri::command]
async fn get_shard(state: State<'_, AppState>, id: String) -> Result<Option<Shard>, String> {
    let store = state.store.lock().await;
    store.get_shard(&id)
}

#[tauri::command]
async fn delete_shard(state: State<'_, AppState>, id: String) -> Result<(), String> {
    let store = state.store.lock().await;
    store.delete_shard(&id)
}

#[tauri::command]
async fn search_shards(state: State<'_, AppState>, query: String) -> Result<Vec<Shard>, String> {
    let store = state.store.lock().await;
    store.search_shards(&query)
}

#[tauri::command]
async fn synthesize_modules(state: State<'_, AppState>, req: SynthesizeRequest) -> Result<String, String> {
    let store = state.store.lock().await;
    let mut shards = Vec::new();
    for id in &req.shard_ids {
        if let Some(shard) = store.get_shard(id).map_err(|e| e.to_string())? {
            shards.push(shard);
        }
    }
    let engine = state.synthesizer.lock().await;
    let output = engine.synthesize(&shards, req.options).map_err(|e| e.to_string())?;
    Ok(output.content)
}

#[tauri::command]
async fn normalize_code(state: State<'_, AppState>, req: NormalizeRequest) -> Result<String, String> {
    let normalizer = state.normalizer.lock().await;
    Ok(normalizer.apply_rules(req.code, &req.rule_ids))
}

#[tauri::command]
async fn generate_blueprint(shards: Vec<Shard>) -> Result<String, String> {
    let mut md = String::from("# PolyShard-P9 Blueprint\n\n");
    md.push_str(&format!("## Overview\nSelected {} shards for synthesis.\n\n", shards.len()));
    md.push_str("## Selected Shards\n\n| ID | Language | Category | Description |\n|---|---|---|---|\n");
    for shard in &shards {
        md.push_str(&format!("| {} | {} | {} | {} |\n", shard.id, shard.language, shard.category, shard.description));
    }
    md.push_str("\n## Architecture\n\n");
    md.push_str("- Phase: Ingestion complete\n");
    md.push_str("- Phase: AST extraction complete\n");
    md.push_str("- Phase: Synthesis pending\n\n");
    md.push_str("## Data Flow\n\n");
    md.push_str("```\nRepo -> Clone -> AST Parse -> Shards -> Blueprint -> Synthesize -> Output\n```\n");
    Ok(md)
}

#[tauri::command]
async fn get_store_stats(state: State<'_, AppState>) -> Result<db::StoreStats, String> {
    let store = state.store.lock().await;
    store.get_stats()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(AppState {
            store: Mutex::new(ShardStore::new("./filestore").expect("Failed to init store")),
            ingester: Mutex::new(RepoIngester::new()),
            extractor: Mutex::new(ShardExtractor::new()),
            synthesizer: Mutex::new(SynthesisEngine::new()),
            normalizer: Mutex::new(NormalizationEngine::new()),
        })
        .invoke_handler(tauri::generate_handler![
            ingest_repo,
            extract_shards,
            list_shards,
            get_shard,
            delete_shard,
            search_shards,
            synthesize_modules,
            normalize_code,
            generate_blueprint,
            get_store_stats,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn main() {
    run()
}
