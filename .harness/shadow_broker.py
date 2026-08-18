#!/usr/bin/env python3
"""
AGNOSTIC-HARVESTER Harness - Shadow Broker Agent Profile
Local-first planning and research specialist for GitHub repo discovery,
tool creation planning, and global Rust binary installation.
"""

import json
import subprocess
import os
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime
import logging

# Harness directories
from .harness_core import HARNESS_ROOT, TOOLS_DIR, STATE_DIR


@dataclass
class RepoCandidate:
    """GitHub repository candidate for tool extraction."""
    url: str
    name: str
    description: str
    language: str
    stars: int
    updated_at: str
    relevance_score: float = 0.0
    selected: bool = False


@dataclass
class ToolPlan:
    """Tool creation plan from a GitHub repository."""
    repo_url: str
    functions: List[Dict[str, Any]]
    global_install: bool = False
    human_approved: bool = False
    status: str = "pending"  # pending, approved, rejected, installed


class ShadowBroker:
    """
    Shadow Broker agent profile for local-first planning and research.
    
    Functions:
    - GitHub repository research via gh-cli
    - AST extraction and tool creation planning
    - Global installation of Rust single-binary tools
    - Mandatory human confirmation for tool plans
    """
    
    def __init__(self):
        self.logger = logging.getLogger("harness.shadow_broker")
        self.manifest_file = STATE_DIR / "shadow_broker_manifest.json"
        self.tools_dir = TOOLS_DIR / "global"
        self.tools_dir.mkdir(parents=True, exist_ok=True)
    
    def search_github_repos(self, query: str, language: str = "rust", max_results: int = 10) -> List[RepoCandidate]:
        """Search GitHub for relevant repositories."""
        self.logger.info(f"Shadow Broker searching GitHub: {query}")
        
        candidates = []
        
        # Try gh-cli first
        try:
            cmd = [
                "gh", "search", "repos",
                query,
                "--language", language,
                "--limit", str(max_results),
                "--sort", "updated",
                "--json", "name,description,url,stargazerCount,updatedAt,primaryLanguage"
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30,
            )
            
            if result.returncode == 0:
                repos = json.loads(result.stdout)
                for repo in repos:
                    candidate = RepoCandidate(
                        url=repo["url"],
                        name=repo["name"],
                        description=repo.get("description", ""),
                        language=repo.get("primaryLanguage", {}).get("name", language),
                        stars=repo.get("stargazerCount", 0),
                        updated_at=repo.get("updatedAt", ""),
                    )
                    candidates.append(candidate)
                
                self.logger.info(f"Found {len(candidates)} repos via gh-cli")
                return candidates
        except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError) as e:
            self.logger.warning(f"gh-cli search failed: {e}")
        
        # Fallback: return empty list with warning
        self.logger.warning("GitHub search unavailable - gh-cli not configured")
        return candidates
    
    def rank_candidates(self, candidates: List[RepoCandidate], context: str) -> List[RepoCandidate]:
        """Rank repository candidates by relevance to context."""
        for candidate in candidates:
            score = 0.0
            
            # Keyword matching in description
            context_words = set(context.lower().split())
            desc_words = set(candidate.description.lower().split())
            overlap = len(context_words & desc_words)
            score += overlap * 0.3
            
            # Recency bonus
            if candidate.updated_at:
                score += 0.2
            
            # Stars bonus (logarithmic)
            import math
            score += math.log(max(candidate.stars, 1)) * 0.1
            
            candidate.relevance_score = min(score, 1.0)
        
        # Sort by relevance score descending
        ranked = sorted(candidates, key=lambda c: c.relevance_score, reverse=True)
        return ranked[:10]  # Top 10
    
    def extract_tool_plan(self, repo: RepoCandidate) -> ToolPlan:
        """Extract tool creation plan from a repository."""
        self.logger.info(f"Extracting tool plan from {repo.name}")
        
        # Clone repo temporarily
        temp_dir = Path("/tmp") / f"shadow-broker-{repo.name}"
        temp_dir.mkdir(exist_ok=True)
        
        try:
            # Clone repository
            subprocess.run(
                ["git", "clone", "--depth", "1", repo.url, str(temp_dir)],
                capture_output=True,
                timeout=60,
                check=True,
            )
            
            # Parse for Rust binary structure
            functions = self._parse_rust_functions(temp_dir)
            
            plan = ToolPlan(
                repo_url=repo.url,
                functions=functions,
            )
            
            self.logger.info(f"Extracted {len(functions)} functions from {repo.name}")
            return plan
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to clone {repo.url}: {e}")
            return ToolPlan(repo_url=repo.url, functions=[])
        finally:
            # Cleanup temp dir
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
    
    def _parse_rust_functions(self, repo_path: Path) -> List[Dict[str, Any]]:
        """Parse Rust source files for public functions."""
        functions = []
        
        # Look for main.rs, lib.rs, bin/ directory
        rust_files = []
        for pattern in ["**/main.rs", "**/lib.rs", "**/bin/*.rs", "**/src/*.rs"]:
            rust_files.extend(repo_path.glob(pattern))
        
        # Deduplicate
        rust_files = list(set(rust_files))
        
        for rust_file in rust_files[:5]:  # Limit to 5 files
            try:
                content = rust_file.read_text()
                # Simple regex extraction of pub fn declarations
                import re
                fn_matches = re.finditer(
                    r'pub\s+fn\s+(\w+)\s*\(([^)]*)\)',
                    content
                )
                
                for match in fn_matches:
                    functions.append({
                        "name": match.group(1),
                        "file": str(rust_file.relative_to(repo_path)),
                        "signature": match.group(0),
                        "risk": "low",  # Default risk assessment
                    })
            except Exception as e:
                self.logger.warning(f"Failed to parse {rust_file}: {e}")
        
        return functions
    
    def present_plan_to_human(self, plan: ToolPlan) -> Dict[str, Any]:
        """Present tool creation plan for human confirmation."""
        self.logger.info(f"Presenting tool plan for {plan.repo_url}")
        
        # Save plan to disk for human review
        plan_file = STATE_DIR / f"tool_plan_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
        plan_data = {
            "repo_url": plan.repo_url,
            "functions": plan.functions,
            "status": "pending_approval",
        }
        plan_file.write_text(json.dumps(plan_data, indent=2))
        
        # Return plan for interactive TUI display
        return {
            "plan_file": str(plan_file),
            "repo_url": plan.repo_url,
            "functions": plan.functions,
            "message": f"Tool creation plan saved to {plan_file}. Awaiting human confirmation.",
        }
    
    def install_rust_tool_global(self, repo_url: str, binary_name: str) -> bool:
        """Install a Rust single-binary tool globally."""
        self.logger.info(f"Installing Rust tool globally: {repo_url}")
        
        try:
            # Try cargo install --git
            result = subprocess.run(
                ["cargo", "install", "--git", repo_url, "--locked"],
                capture_output=True,
                text=True,
                timeout=300,
            )
            
            if result.returncode == 0:
                self.logger.info(f"Successfully installed {binary_name}")
                return True
            else:
                self.logger.error(f"cargo install failed: {result.stderr}")
                return False
                
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            self.logger.error(f"Installation failed: {e}")
            return False
    
    def introspect_cli(self, binary_path: Path) -> Optional[Dict[str, Any]]:
        """Introspect CLI tool to generate JSON schema."""
        if not binary_path.exists():
            return None
        
        try:
            # Try --help first
            result = subprocess.run(
                [str(binary_path), "--help"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            
            help_text = result.stdout or result.stderr
            
            # Generate minimal schema from help text
            schema = {
                "name": binary_path.name,
                "description": help_text[:200],
                "parameters": [],
            }
            
            return schema
            
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return None
    
    def register_tool_in_manifest(self, name: str, binary_path: Path, schema: Dict[str, Any]):
        """Register tool in the global manifest."""
        from .harness_core import ToolRegistry, ToolManifest, HarnessState
        
        state = HarnessState()
        registry = ToolRegistry(state)
        
        manifest = ToolManifest(
            name=name,
            binary_path=str(binary_path),
            schema=schema,
        )
        registry.register_tool(manifest)
    
    def research_and_plan(self, context: str) -> Dict[str, Any]:
        """Full research and planning pipeline."""
        self.logger.info(f"Shadow Broker research: {context[:100]}")
        
        # Search GitHub
        candidates = self.search_github_repos(context, language="rust", max_results=10)
        
        if not candidates:
            return {
                "status": "no_results",
                "message": "No repositories found",
                "candidates": [],
            }
        
        # Rank candidates
        ranked = self.rank_candidates(candidates, context)
        
        # Extract tool plans for top 3
        plans = []
        for candidate in ranked[:3]:
            plan = self.extract_tool_plan(candidate)
            plans.append(plan)
        
        # Present to human for confirmation
        human_feedback = []
        for plan in plans:
            if plan.functions:
                feedback = self.present_plan_to_human(plan)
                human_feedback.append(feedback)
        
        return {
            "status": "plans_pending",
            "candidates": [
                {
                    "url": c.url,
                    "name": c.name,
                    "description": c.description,
                    "relevance_score": c.relevance_score,
                }
                for c in ranked
            ],
            "plans": [
                {
                    "repo_url": p.repo_url,
                    "functions": p.functions,
                    "status": p.status,
                }
                for p in plans
            ],
            "human_feedback": human_feedback,
        }
