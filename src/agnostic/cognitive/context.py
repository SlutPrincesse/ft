"""Cognitive context processing for AGNOSTIC-HARVESTER."""

import re
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from dataclasses import dataclass, field

from ..models import LinguisticProfile, AmbiguityResult, Severity


class LEDv3LinguisticEngine:
    """
    LED v3.0 - Zero-cost linguistic pre-processor.
    
    Provides zero-token spellcheck, grammar normalization, and ambiguity resolution.
    """
    
    def __init__(self):
        self.logger = logging.getLogger("agnostic.cognitive.led")
        
        # Local dictionaries (zero-cost, no API calls)
        self.ambiguous_terms = self._load_ambiguous_terms()
        self.common_corrections = self._load_common_corrections()
        self.slang_mappings = self._load_slang_mappings()
        
        # Regex patterns for normalization
        self.normalization_patterns = [
            (r'//+', ' '),
            (r';+', ';'),
            (r'\s+', ' '),
            (r'^\s+', ''),
            (r'\s+$', ''),
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
            "build": ["compile", "assemble", "construct", "generate"],
            "run": ["execute", "start", "launch", "invoke"],
            "test": ["validate", "verify", "check", "assert"],
            "deploy": ["release", "publish", "ship", "rollout"],
            "config": ["configure", "setup", "initialize", "params"],
            "setup": ["configure", "initialize", "bootstrap", "provision"],
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
            "recieve": "receive",
            "seperate": "separate",
            "definately": "definitely",
            "occured": "occurred",
            "begining": "beginning",
        }
    
    def _load_slang_mappings(self) -> Dict[str, str]:
        """Load developer slang to formal equivalents."""
        return {
            "ASAP": "as soon as possible",
            "pls": "please",
            "plz": "please",
            "thx": "thanks",
            "ty": "thank you",
            "np": "no problem",
            "tbh": "to be honest",
            "imo": "in my opinion",
            "imho": "in my humble opinion",
            "fyi": "for your information",
            "asap": "as soon as possible",
            "afaik": "as far as I know",
            "iirc": "if I recall correctly",
            "tldr": "too long didn't read",
            "eli5": "explain like I'm 5",
            "smh": "shaking my head",
            "brb": "be right back",
            "omg": "oh my god",
            "lol": "laughing out loud",
        }
    
    def process(self, raw_input: str) -> LinguisticProfile:
        """
        Process raw input through the LED v3.0 pipeline.
        
        Args:
            raw_input: Raw user input text
            
        Returns:
            LinguisticProfile with normalized text and metadata
        """
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
    
    def _correct_typos(self, text: str) -> Tuple[str, List[Dict[str, str]]]:
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
        for pattern, replacement in self.normalization_patterns:
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
                idx = words.index(word)
                context_words = words[max(0, idx - 3):idx + 3]
                context = " ".join(context_words)
                
                ambiguities.append(AmbiguityResult(
                    term=word,
                    context=context,
                    suggestions=suggestions,
                    severity=Severity.MEDIUM if len(suggestions) > 3 else Severity.LOW,
                ))
        
        return ambiguities
    
    def _estimate_token_savings(self, original: str, normalized: str) -> float:
        """Estimate percentage of tokens saved by normalization."""
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
                    "severity": amb.severity.value,
                })
        return options
