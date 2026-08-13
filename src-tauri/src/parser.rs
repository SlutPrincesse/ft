use crate::shard::Shard;
use std::path::Path;
use tree_sitter::{Parser, Language};
use tree_sitter_python::LANGUAGE as PYTHON_LANGUAGE;
use tree_sitter_typescript::{LANGUAGE_TYPESCRIPT, LANGUAGE_TSX};
use tree_sitter_rust::LANGUAGE as RUST_LANGUAGE;

pub struct ShardExtractor {
    parser: Parser,
}

impl ShardExtractor {
    pub fn new() -> Self {
        Self { parser: Parser::new() }
    }

    pub fn extract_file(&mut self, path: &Path, content: &str) -> Vec<Shard> {
        let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
        let lang = match ext {
            "py" => "python",
            "ts" => "typescript",
            "tsx" => "typescript",
            "rs" => "rust",
            _ => return vec![],
        };
        let ts_lang: Option<tree_sitter::Language> = match ext {
            "py" => Some(PYTHON_LANGUAGE.into()),
            "ts" => Some(LANGUAGE_TYPESCRIPT.into()),
            "tsx" => Some(LANGUAGE_TSX.into()),
            "rs" => Some(RUST_LANGUAGE.into()),
            _ => None,
        };
        let mut shards = Vec::new();
        if let Some(ts_lang) = ts_lang {
            if self.parser.set_language(&ts_lang).is_ok() {
                if let Some(tree) = self.parser.parse(content, None) {
                    let root = tree.root_node();
                    Self::walk_node(root, content, lang, &path.to_string_lossy().to_string(), &mut shards);
                }
            }
        }
        shards
    }

    fn walk_node(node: tree_sitter::Node, source: &str, lang: &str, file_path: &str, shards: &mut Vec<Shard>) {
        let kind = node.kind();
        match kind {
            "function_definition" | "function_declaration" | "async_function_definition" => {
                if let Some(name_node) = node.child_by_field_name("name") {
                    let name = Self::node_text(&name_node, source);
                    let _code = Self::node_text(&node, source);
                    let mut shard = Shard::new(lang, "function", None, &format!("{} in {}", name, file_path));
                    shard.file_path = std::path::PathBuf::from(file_path);
                    shard.description = format!("Function `{}` extracted from {}", name, file_path);
                    shards.push(shard);
                }
            }
            "class_definition" | "class_declaration" | "struct_item" | "interface_declaration" => {
                if let Some(name_node) = node.child_by_field_name("name") {
                    let name = Self::node_text(&name_node, source);
                    let mut shard = Shard::new(lang, "class", None, &format!("{} in {}", name, file_path));
                    shard.file_path = std::path::PathBuf::from(file_path);
                    shard.description = format!("Class/struct `{}` extracted from {}", name, file_path);
                    shards.push(shard);
                }
            }
            _ => {}
        }
        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            Self::walk_node(child, source, lang, file_path, shards);
        }
    }

    fn node_text(node: &tree_sitter::Node, source: &str) -> String {
        source[node.start_byte()..node.end_byte()].to_string()
    }
}
