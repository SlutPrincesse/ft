use regex::Regex;

pub struct NormalizationEngine {
    rules: Vec<(String, Regex, String)>,
}

impl NormalizationEngine {
    pub fn new() -> Self {
        let mut rules = Vec::new();
        rules.push(("snake2camel".to_string(), Regex::new(r"_([a-z])").unwrap(), "${1}".to_string()));
        rules.push(("trim_space".to_string(), Regex::new(r"[ \t]+$").unwrap(), "".to_string()));
        rules.push(("collapse_br".to_string(), Regex::new(r"\n{3,}").unwrap(), "\n\n".to_string()));
        rules.push(("purge_logs".to_string(), Regex::new(r"^[ \t]*console\.log\(.*?\);?[ \t]*$").unwrap(), "".to_string()));
        rules.push(("norm_quotes".to_string(), Regex::new(r#"from\s+\"(.*?)\""#).unwrap(), "from '$1'".to_string()));
        rules.push(("strip_html".to_string(), Regex::new(r"<!--[\s\S]*?-->").unwrap(), "".to_string()));
        rules.push(("alias2rel".to_string(), Regex::new(r#"from\s+['\"]@/(.*?)['\"]"#).unwrap(), "from '../$1'".to_string()));
        rules.push(("trim_json".to_string(), Regex::new(r",(\s*[}\]])").unwrap(), "$1".to_string()));
        Self { rules }
    }

    pub fn apply_rules(&self, mut input: String, rule_ids: &[String]) -> String {
        for (id, re, repl) in &self.rules {
            if rule_ids.is_empty() || rule_ids.contains(id) {
                input = re.replace_all(&input, repl.as_str()).to_string();
            }
        }
        input
    }

    pub fn available_rules(&self) -> Vec<(&str, &str)> {
        self.rules.iter().map(|(id, _, _)| (id.as_str(), "")).collect()
    }
}
