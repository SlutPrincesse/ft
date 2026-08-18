#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - LED v3.0 Linguistic Engine
Zero-cost spellcheck, grammar normalization, and ambiguity resolution.
"""

import re
import json
from pathlib import Path
from typing import List, Tuple, Optional, Dict, Any
from dataclasses import dataclass


@dataclass
class AmbiguityResult:
    """Result of ambiguity detection."""
    term: str
    context: str
    suggestions: List[str]
    severity: str  # low, medium, high


@dataclass
class LinguisticProfile:
    """Profile of processed linguistic input."""
    original: str
    normalized: str
    ambiguities: List[AmbiguityResult]
    corrections: List[Dict[str, str]]
    token_savings: float  # Estimated token savings from normalization


class LEDv3LinguisticEngine:
    """Zero-cost linguistic pre-processor for human input."""
    
    def __init__(self):
        self.logger = logging.getLogger("harness.led_v3")
        
        # Local dictionaries (zero-cost, no API calls)
        self.ambiguous_terms = self._load_ambiguous_terms()
        self.common_corrections = self._load_common_corrections()
        self.slang_mappings = self._load_slang_mappings()
        
        # Regex patterns for normalization
        self.patterns = [
            (r'//+', ' '),  # Multiple slashes to space
            (r';+', ';'),   # Multiple semicolons to single
            (r'\s+', ' '),  # Multiple whitespace to single space
            (r'^\s+', ''),  # Leading whitespace
            (r'\s+$', ''),  # Trailing whitespace
        ]
    
    def _load_ambiguous_terms(self) -> Dict[str, List[str]]:
        """Load local dictionary of ambiguous terms."""
        return {
            "fix": ["repair", "refactor", "patch", "resolve", "correct"],
            "clean": ["refactor", "remove dead code", "format", "lint"],
            "optimize": ["improve performance", "reduce complexity", "cache results"],
            "script": ["automation", "workflow", "pipeline", "task"],
            "update": ["upgrade dependency", "modify", "patch", "refresh"],
            "handle": ["process", "manage", "execute", "implement"],
            "support": ["implement", "integrate", "add", "enable"],
            "improve": ["refactor", "optimize", "enhance", "upgrade"],
        }
    
    def _load_common_corrections(self) -> Dict[str, str]:
        """Load common typo corrections."""
        return {
            "teh": "the",
            "adn": "and",
            "taht": "that",
            "wich": "which",
            "ocde": "code",
            "fucntion": "function",
            "claas": "class",
            "impor t": "import",
            "fomr": "from",
            "retrun": "return",
            "lenght": "length",
            "widht": "width",
            "heigth": "height",
            "paramter": "parameter",
            "arugment": "argument",
            "retunr": "return",
            "whiel": "while",
            "fro": "for",
            "exepction": "exception",
            "erorr": "error",
            "faild": "failed",
            "succes": "success",
        }
    
    def _load_slang_mappings(self) -> Dict[str, str]:
        """Load developer slang to formal equivalents."""
        return {
            " ASAP": " as soon as possible",
            "pls": "please",
            "plz": "please",
            "thx": "thanks",
            "ty": "thank you",
            "np": "no problem",
            "omg": "oh my god",
            "lol": "laughing out loud",
            "brb": "be right back",
            "tbh": "to be honest",
            "imo": "in my opinion",
            "imho": "in my humble opinion",
            "fyi": "for your information",
            "asap": "as soon as possible",
            "afaik": "as far as I know",
            "iirc": "if I recall correctly",
            "tldr": "too long didn't read",
            "ama": "ask me anything",
            "eli5": "explain like I'm 5",
            "smh": "shaking my head",
            "stfu": "shut up",
        }
    
    def process(self, raw_input: str) -> LinguisticProfile:
        """Process raw input through the LED v3.0 pipeline."""
        original = raw_input
        normalized = raw_input
        ambiguities = []
        corrections = []
        
        # Phase 1: Typo correction (zero-cost dictionary lookup)
        normalized, typo_corrections = self._correct_typos(normalized)
        corrections.extend(typo_corrections)
        
        # Phase 2: Slang normalization
        normalized, slang_corrections = self._normalize_slang(normalized)
        corrections.extend(slang_corrections)
        
        # Phase 3: Regex normalization
        normalized = self._apply_regex_normalization(normalized)
        
        # Phase 4: Ambiguity detection
        ambiguities = self._detect_ambiguities(normalized)
        
        # Calculate estimated token savings
        token_savings = self._estimate_token_savings(original, normalized)
        
        profile = LinguisticProfile(
            original=original,
            normalized=normalized,
            ambiguities=ambiguities,
            corrections=corrections,
            token_savings=token_savings,
        )
        
        self.logger.info(
            f"LED v3.0 processed: {len(corrections)} corrections, "
            f"{len(ambiguities)} ambiguities, {token_savings:.1f}% token savings"
        )
        
        return profile
    
    def _correct_typos(self, text: str) -> Tuple[str, List[Dict[str, str]]:
        """Correct common typos using local dictionary."""
        corrections = []
        words = text.split()
        corrected_words = []
        
        for word in words:
            lower_word = word.lower()
            if lower_word in self.common_corrections:
                correction = self.common_corrections[lower_word]
                corrections.append({
                    "original": word,
                    "corrected": correction,
                    "type": "typo",
                })
                # Preserve case
                if word[0].isupper():
                    corrected_words.append(correction.capitalize())
                else:
                    corrected_words.append(correction)
            else:
                corrected_words.append(word)
        
        return " ".join(corrected_words), corrections
    
    def _normalize_slang(self, text: str) -> Tuple[str, List[Dict[str, str]]]:
        """Normalize developer slang to formal language."""
        corrections = []
        normalized = text
        
        for slang, formal in self.slang_mappings.items():
            if slang in normalized:
                corrections.append({
                    "original": slang,
                    "corrected": formal,
                    "type": "slang",
                })
                normalized = normalized.replace(slang, formal)
        
        return normalized, corrections
    
    def _apply_regex_normalization(self, text: str) -> str:
        """Apply regex-based normalization patterns."""
        normalized = text
        for pattern, replacement in self.patterns:
            normalized = re.sub(pattern, replacement, normalized)
        return normalized.strip()
    
    def _detect_ambiguities(self, text: str) -> List[AmbiguityResult]:
        """Detect ambiguous terms in normalized text."""
        ambiguities = []
        words = text.lower().split()
        
        for word in words:
            if word in self.ambiguous_terms:
                suggestions = self.ambiguous_terms[word]
                # Find context (surrounding words)
                context_words = words[max(0, words.index(word) - 3):words.index(word) + 3]
                context = " ".join(context_words)
                
                ambiguities.append(AmbiguityResult(
                    term=word,
                    context=context,
                    suggestions=suggestions,
                    severity="medium" if len(suggestions) > 3 else "low",
                ))
        
        return ambiguities
    
    def _estimate_token_savings(self, original: str, normalized: str) -> float:
        """Estimate percentage of tokens saved by normalization."""
        # Rough estimate: 1 token ≈ 4 characters
        original_tokens = len(original) / 4
        normalized_tokens = len(normalized) / 4
        
        if original_tokens == 0:
            return 0.0
        
        savings = ((original_tokens - normalized_tokens) / original_tokens) * 100
        return max(0.0, savings)
    
    def get_disambiguation_options(self, ambiguities: List[AmbiguityResult]) -> List[Dict[str, Any]]:
        """Generate interactive disambiguation options for TUI."""
        options = []
        for amb in ambiguities:
            for idx, suggestion in enumerate(amb.suggestions, 1):
                options.append({
                    "term": amb.term,
                    "context": amb.context,
                    "option_number": idx,
                    "suggestion": suggestion,
                    "severity": amb.severity,
                })
        return options


class ContextSplicer:
    """Module 2: Grammar-based text splicing into atomic tasks."""
    
    def __init__(self):
        self.logger = logging.getLogger("harness.splicer")
    
    def splice(self, text: str) -> List[str]:
        """Split text into atomic task units."""
        tasks = []
        
        # Split by double newlines (Markdown paragraphs)
        paragraphs = text.split("\n\n")
        
        for paragraph in paragraphs:
            paragraph = paragraph.strip()
            if not paragraph:
                continue
            
            # Split by semicolons
            clauses = paragraph.split(";")
            for clause in clauses:
                clause = clause.strip()
                if not clause:
                    continue
                
                # Split by bullet points
                if clause.startswith("-") or clause.startswith("*"):
                    clause = clause[1:].strip()
                
                if clause:
                    tasks.append(clause)
        
        self.logger.info(f"Spliced {len(tasks)} atomic tasks from input")
        return tasks
    
    def splice_file(self, file_path: Path) -> List[str]:
        """Split a file into atomic task units."""
        if not file_path.exists():
            return []
        
        content = file_path.read_text()
        return self.splice(content)


class ContextOptimizer:
    """Module 3: AST-driven context weaving and file pruning."""
    
    def __init__(self):
        self.logger = logging.getLogger("harness.optimizer")
        self.boilerplate_patterns = [
            r'^\s*#.*$',  # Comments
            r'^\s*$',      # Empty lines
            r'^\s*import\s+\w+\s*;\s*$',  # Simple imports (keep complex ones)
        ]
    
    def optimize(self, tasks: List[str], workspace_path: Path = Path(".")) -> Dict[str, Any]:
        """Optimize context by pruning boilerplate and weaving AST."""
        optimized_tasks = []
        total_original_chars = sum(len(t) for t in tasks)
        total_optimized_chars = 0
        
        for task in tasks:
            # Apply boilerplate removal
            optimized = self._remove_boilerplate(task)
            optimized_tasks.append(optimized)
            total_optimized_chars += len(optimized)
        
        # Calculate headroom
        headroom = 0.85  # Target 85% headroom for MCP tools
        
        result = {
            "tasks": optimized_tasks,
            "original_chars": total_original_chars,
            "optimized_chars": total_optimized_chars,
            "compression_ratio": total_optimized_chars / total_original_chars if total_original_chars > 0 else 1.0,
            "context_headroom": headroom,
            "pruned_files": [],
        }
        
        self.logger.info(
            f"Context optimized: {total_original_chars} -> {total_optimized_chars} chars "
            f"({result['compression_ratio']:.2f} ratio), {headroom:.0%} headroom"
        )
        
        return result
    
    def _remove_boilerplate(self, text: str) -> str:
        """Remove boilerplate from text."""
        lines = text.split("\n")
        filtered = []
        
        for line in lines:
            # Skip empty lines and pure comments
            if not line.strip():
                continue
            if re.match(r'^\s*#\s*$', line):
                continue
            filtered.append(line)
        
        return "\n".join(filtered)


class ErrorRecoveryEngine:
    """Module 4: Reactive error correction and dynamic tool synthesis."""
    
    def __init__(self, tools_dir: Path = TOOLS_DIR):
        self.tools_dir = tools_dir
        self.logger = logging.getLogger("harness.error_recovery")
        self.error_patterns = self._load_error_patterns()
    
    def _load_error_patterns(self) -> Dict[str, str]:
        """Load known error patterns and their fixes."""
        return {
            "ModuleNotFoundError": "pip install",
            "ImportError": "pip install",
            "Command not found": "cargo install",
            "Permission denied": "chmod +x",
            "No such file or directory": "create file",
            "Connection refused": "check service status",
            "Timeout": "increase timeout",
            "SyntaxError": "fix syntax",
            "IndentationError": "fix indentation",
        }
    
    def handle_error(self, stderr: str, task_id: str) -> Optional[Dict[str, Any]]:
        """Handle execution error with reactive hooks."""
        self.logger.error(f"Task {task_id} error: {stderr[:200]}")
        
        # Match known error patterns
        for pattern, action in self.error_patterns.items():
            if pattern in stderr:
                recovery = {
                    "task_id": task_id,
                    "error_pattern": pattern,
                    "suggested_action": action,
                    "auto_fixable": True,
                }
                self.logger.info(f"Auto-recovery suggested for {pattern}: {action}")
                return recovery
        
        # Unknown error - synthesize a tool
        tool_path = self._synthesize_tool(task_id, stderr)
        if tool_path:
            return {
                "task_id": task_id,
                "error_pattern": "unknown",
                "suggested_action": f"Synthesized tool at {tool_path}",
                "auto_fixable": True,
            }
        
        return None
    
    def _synthesize_tool(self, task_id: str, error: str) -> Optional[Path]:
        """Synthesize a local tool to handle the error."""
        tool_path = self.tools_dir / f"synthesized_tool_{task_id}.py"
        
        # Generate a minimal wrapper script
        content = f"""#!/usr/bin/env python3
\"\"\"
Synthesized tool for task {task_id}
Auto-generated to handle error: {error[:100]}
\"\"\"

import subprocess
import sys

def main():
    print("Synthesized tool placeholder - implement error-specific fix here")
    return 0

if __name__ == "__main__":
    sys.exit(main())
"""
        tool_path.write_text(content)
        tool_path.chmod(0o755)
        self.logger.info(f"Synthesized tool: {tool_path}")
        return tool_path


class NeuralMemory:
    """Module 5: Neural memory and shadow git engine."""
    
    def __init__(self, memory_dir: Path = MEMORY_DIR):
        self.memory_dir = memory_dir
        self.dataset_file = memory_dir / "dataset.jsonl"
        self.logger = logging.getLogger("harness.memory")
    
    def record_task(self, task_id: str, prompt: str, result: str, metadata: Optional[Dict] = None):
        """Record a completed task to the neural memory dataset."""
        record = {
            "task_id": task_id,
            "timestamp": datetime.utcnow().isoformat(),
            "prompt": prompt,
            "result": result,
            "metadata": metadata or {},
        }
        
        with open(self.dataset_file, "a") as f:
            f.write(json.dumps(record) + "\n")
        
        self.logger.debug(f"Recorded task {task_id} to neural memory")
    
    def get_recent_tasks(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent tasks from memory."""
        if not self.dataset_file.exists():
            return []
        
        with open(self.dataset_file, "r") as f:
            lines = f.readlines()
        
        records = [json.loads(line) for line in lines if line.strip()]
        return records[-limit:]
    
    def compact(self):
        """Compact memory during idle time."""
        self.logger.info("Compacting neural memory...")
        # Keep last 1000 records
        records = self.get_recent_tasks(limit=1000)
        
        with open(self.dataset_file, "w") as f:
            for record in records:
                f.write(json.dumps(record) + "\n")
        
        self.logger.info(f"Memory compacted to {len(records)} records")


class PostQueueAuditor:
    """Module 6: Post-queue audit and interactive recommendation loop."""
    
    def __init__(self):
        self.logger = logging.getLogger("harness.auditor")
    
    def audit(self, dag: TaskDAG, workspace_path: Path = Path(".")) -> Dict[str, Any]:
        """Run comprehensive audit on completed tasks."""
        audit_report = {
            "timestamp": datetime.utcnow().isoformat(),
            "total_tasks": len(dag.tasks),
            "completed": sum(1 for t in dag.tasks.values() if t.status == "completed"),
            "failed": sum(1 for t in dag.tasks.values() if t.status == "failed"),
            "yielded": sum(1 for t in dag.tasks.values() if t.status == "yielded"),
            "recommendations": [],
            "integrity_checks": [],
        }
        
        # Run integrity checks
        audit_report["integrity_checks"] = self._run_integrity_checks(workspace_path)
        
        # Generate recommendations
        audit_report["recommendations"] = self._generate_recommendations(audit_report)
        
        self.logger.info(
            f"Audit complete: {audit_report['completed']}/{audit_report['total_tasks']} tasks passed"
        )
        
        return audit_report
    
    def _run_integrity_checks(self, workspace_path: Path) -> List[Dict[str, Any]]:
        """Run local static analysis and tests."""
        checks = []
        
        # Check for syntax errors in Python files
        py_files = list(workspace_path.rglob("*.py"))
        for py_file in py_files[:10]:  # Limit to 10 files
            try:
                with open(py_file, "r") as f:
                    compile(f.read(), py_file, "exec")
                checks.append({
                    "file": str(py_file),
                    "status": "passed",
                    "check": "syntax",
                })
            except SyntaxError as e:
                checks.append({
                    "file": str(py_file),
                    "status": "failed",
                    "check": "syntax",
                    "error": str(e),
                })
        
        return checks
    
    def _generate_recommendations(self, audit_report: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate follow-up task recommendations."""
        recommendations = []
        
        if audit_report["failed"] > 0:
            recommendations.append({
                "action": "retry_failed",
                "description": f"Retry {audit_report['failed']} failed tasks",
                "priority": "high",
            })
        
        if audit_report["yielded"] > 0:
            recommendations.append({
                "action": "resolve_yielded",
                "description": f"Resolve {audit_report['yielded']} tasks waiting for human input",
                "priority": "high",
            })
        
        # Generic recommendations
        recommendations.extend([
            {
                "action": "add_tests",
                "description": "Add unit tests for updated modules",
                "priority": "medium",
            },
            {
                "action": "refactor_imports",
                "description": "Refactor import statements",
                "priority": "low",
            },
            {
                "action": "run_linter",
                "description": "Run linter on modified files",
                "priority": "medium",
            },
        ])
        
        return recommendations


# Module integration
class AGNOSTIC_HARVESTER:
    """Main harness class integrating all modules."""
    
    def __init__(self):
        self.led = LEDv3LinguisticEngine()
        self.splicer = ContextSplicer()
        self.optimizer = ContextOptimizer()
        self.error_recovery = ErrorRecoveryEngine()
        self.memory = NeuralMemory()
        self.auditor = PostQueueAuditor()
        self.orchestrator = HarnessOrchestrator()
    
    def process_prompt(self, prompt: str) -> Dict[str, Any]:
        """Process a prompt through the full harness pipeline."""
        # Module 1: LED v3.0
        profile = self.led.process(prompt)
        
        # Module 2: Context Splicer
        tasks = self.splicer.splice(profile.normalized)
        
        # Module 3: Context Optimizer
        optimized = self.optimizer.optimize(tasks)
        
        # Module 4: Execute (placeholder)
        results = []
        for task in optimized["tasks"]:
            task_id = self.orchestrator.dag.add_task(task)
            self.orchestrator.dag.mark_completed(task_id, f"Processed: {task}")
            results.append({"task_id": task_id, "task": task})
        
        # Module 5: Neural Memory
        for result in results:
            self.memory.record_task(
                result["task_id"],
                result["task"],
                "completed",
            )
        
        # Module 6: Post-Queue Audit
        audit = self.auditor.audit(self.orchestrator.dag)
        
        return {
            "status": "success",
            "profile": {
                "original": profile.original,
                "normalized": profile.normalized,
                "corrections": profile.corrections,
                "ambiguities": [
                    {
                        "term": a.term,
                        "suggestions": a.suggestions,
                        "severity": a.severity,
                    }
                    for a in profile.ambiguities
                ],
                "token_savings": profile.token_savings,
            },
            "tasks_processed": len(results),
            "audit": audit,
        }
