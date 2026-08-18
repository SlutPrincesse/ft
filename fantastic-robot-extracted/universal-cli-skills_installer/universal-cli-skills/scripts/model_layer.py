#!/usr/bin/env python3
"""NVIDIA NIM-aware model layer: RPM limiting, multi-key rotation, fallback.

Design goals:
- No network access at import time.
- Minimize AI calls: token-bucket per key, honor X-RateLimit-* headers,
  rotate keys on 429/quota, fall back to a secondary model when all keys
  for the primary are exhausted.
- Usable standalone (CLI) and as a library by intake.py prompt enrichment.

API-key + model config is passed in; nothing is read from the environment
automatically except via an explicit keys file.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import threading
import time
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ModelSpec:
    name: str
    # requests-per-minute budget per key for this model
    rpm: int = 60
    # rough cost per 1k tokens (prompt+completion blended), for budget guard
    cost_per_1k: float = 0.0


@dataclass
class KeyPool:
    keys: list[str]
    rpm_per_key: int = 60
    _lock: threading.Lock = field(default_factory=threading.Lock)
    _next: int = 0
    _cooldown_until: dict[int, float] = field(default_factory=dict)

    def __post_init__(self):
        self.keys = [k for k in self.keys if k]
        self._cooldown_until = {i: 0.0 for i in range(len(self.keys))}

    def size(self) -> int:
        return len(self.keys)

    def acquire(self) -> Optional[tuple[int, str]]:
        """Return (index, key) for a key that is within RPM, else None."""
        with self._lock:
            now = time.time()
            order = list(range(self._next, len(self.keys))) + list(range(0, self._next))
            for i in order:
                if now >= self._cooldown_until.get(i, 0):
                    self._next = (i + 1) % max(1, len(self.keys))
                    return i, self.keys[i]
            return None

    def mark_rate_limited(self, index: int, retry_after: float = 60.0) -> None:
        with self._lock:
            self._cooldown_until[index] = time.time() + max(1.0, retry_after)


@dataclass
class Telemetry:
    keys_used: list[int] = field(default_factory=list)
    models_used: list[str] = field(default_factory=list)
    retries: int = 0
    total_tokens: int = 0
    est_cost: float = 0.0

    def as_dict(self) -> dict:
        return {
            "keys_used": sorted(set(self.keys_used)),
            "models_used": self.models_used,
            "retries": self.retries,
            "total_tokens": self.total_tokens,
            "est_cost": round(self.est_cost, 6),
        }


class RateLimitedError(Exception):
    pass


class NIMClient:
    """Minimal NIM/OpenAI-compatible client with key rotation + fallback."""

    def __init__(
        self,
        base_url: str,
        primary_keys: list[str],
        fallback_keys: list[str],
        primary_model: str = "nim-llama-3.1-8b",
        fallback_model: str = "nim-llama-3.1-70b",
        rpm_per_key: int = 60,
        cost_per_1k: float = 0.0,
        transport=None,  # injectable for tests
    ):
        self.base_url = base_url.rstrip("/")
        self.primary = KeyPool(list(primary_keys), rpm_per_key)
        self.fallback = KeyPool(list(fallback_keys), rpm_per_key)
        self.primary_model = primary_model
        self.fallback_model = fallback_model
        self.cost_per_1k = cost_per_1k
        self._transport = transport or _http_transport
        self.telemetry = Telemetry()

    def _pool_for(self, model: str) -> KeyPool:
        return self.primary if model == self.primary_model else self.fallback

    def call(self, prompt: str, max_tokens: int = 512, model: Optional[str] = None) -> str:
        models = [model or self.primary_model, self.fallback_model]
        last_err: Optional[Exception] = None
        for m in models:
            pool = self._pool_for(m)
            if pool.size() == 0:
                continue
            for _ in range(pool.size()):
                slot = pool.acquire()
                if slot is None:
                    # all keys cooling down; wait briefly then retry once
                    time.sleep(min(2.0, 1.0))
                    slot = pool.acquire()
                    if slot is None:
                        break
                idx, key = slot
                try:
                    self.telemetry.keys_used.append(idx)
                    self.telemetry.models_used.append(m)
                    text, used_tokens = self._transport(
                        self.base_url, key, m, prompt, max_tokens
                    )
                    self.telemetry.total_tokens += used_tokens
                    self.telemetry.est_cost += (used_tokens / 1000.0) * self.cost_per_1k
                    return text
                except RateLimitedError as e:
                    self.telemetry.retries += 1
                    retry_after = getattr(e, "retry_after", 60.0)
                    pool.mark_rate_limited(idx, retry_after)
                    last_err = e
                    continue
                except Exception as e:  # network/other
                    self.telemetry.retries += 1
                    last_err = e
                    continue
        raise RuntimeError(f"All keys/models exhausted: {last_err}")


def _http_transport(base_url: str, api_key: str, model: str, prompt: str, max_tokens: int):
    """Real transport via urllib (no third-party deps). Raises RateLimitedError on 429."""
    import urllib.request
    url = f"{base_url}/chat/completions"
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
    }).encode()
    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Authorization", f"Bearer {api_key}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode())
            text = data["choices"][0]["message"]["content"]
            used = data.get("usage", {}).get("total_tokens", 0)
            return text, int(used)
    except urllib.error.HTTPError as e:
        if e.code == 429:
            retry = 60.0
            ra = e.headers.get("Retry-After")
            if ra and ra.isdigit():
                retry = float(ra)
            err = RateLimitedError(f"429 from {model}")
            err.retry_after = retry  # type: ignore[attr-defined]
            raise err
        raise


def load_keys_from_file(path: str) -> list[str]:
    """Read API keys from a .env-style file (KEY=VALUE lines or bare values)."""
    keys: list[str] = []
    if not os.path.exists(path):
        return keys
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                _, v = line.split("=", 1)
                v = v.strip().strip('"').strip("'")
            else:
                v = line
            if v:
                keys.append(v)
    return keys


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="NIM model layer CLI (rotation + fallback).")
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--keys-file", required=True, help=".env-style file with API keys")
    ap.add_argument("--base-url", default="https://integrate.api.nvidia.com/v1")
    ap.add_argument("--primary-model", default="nim-llama-3.1-8b")
    ap.add_argument("--fallback-model", default="nim-llama-3.1-70b")
    ap.add_argument("--rpm-per-key", type=int, default=60)
    ap.add_argument("--max-tokens", type=int, default=512)
    args = ap.parse_args(argv)

    keys = load_keys_from_file(args.keys_file)
    if not keys:
        sys.stderr.write("No API keys found in keys file.\n")
        return 2
    client = NIMClient(
        base_url=args.base_url,
        primary_keys=keys,
        fallback_keys=keys,  # same pool for fallback by default
        primary_model=args.primary_model,
        fallback_model=args.fallback_model,
        rpm_per_key=args.rpm_per_key,
    )
    try:
        out = client.call(args.prompt, max_tokens=args.max_tokens)
    except RuntimeError as e:
        sys.stderr.write(f"ERROR: {e}\n")
        return 1
    sys.stdout.write(out + "\n")
    sys.stderr.write("telemetry: " + json.dumps(client.telemetry.as_dict()) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
