#!/usr/bin/env python3
import shutil
from pathlib import Path

BASE_DIR = Path("/workspace/fb56b5e0-e79f-401c-ab9a-b089802077df/sessions/agent_2f3ec557-8bac-4722-b63e-25872467442f/fantastic-robot-extracted")
MERGED_DIR = Path("/workspace/fb56b5e0-e79f-401c-ab9a-b089802077df/sessions/agent_2f3ec557-8bac-4722-b63e-25872467442f/fantastic-robot-merged")

EXCLUDE_FILES = {
    "gemini-code-1786681318211.xml",
    "dadgpt-response-2026-08-05T15-03-19-841Z.md",
    "dadgpt-response-2026-08-05T15-03-33-921Z.md",
}

def should_exclude(path: Path) -> bool:
    return any(part in EXCLUDE_FILES for part in path.parts)

def copy_unique(src: Path, dst: Path):
    if not src.exists() or should_exclude(src):
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists():
        shutil.copy2(src, dst)
    else:
        if src.stat().st_size > dst.stat().st_size:
            shutil.copy2(src, dst)

def merge_into_base(src_inner: Path, dst_base: Path):
    if not src_inner.exists():
        return
    for item in src_inner.rglob("*"):
        if item.is_dir():
            continue
        rel = item.relative_to(src_inner)
        dst = dst_base / rel
        copy_unique(item, dst)

def main():
    if MERGED_DIR.exists():
        shutil.rmtree(MERGED_DIR)
    MERGED_DIR.mkdir(parents=True)

    print("Merging agent-wun as base...")
    merge_into_base(BASE_DIR / "agent-wun" / "agent-wun", MERGED_DIR / "agent-wun")

    print("Merging agent-hfs unique content...")
    merge_into_base(BASE_DIR / "agent-hfs" / "agent-hfs", MERGED_DIR / "agent-wun")

    print("Merging agent-wun-tu-free unique content...")
    merge_into_base(BASE_DIR / "agent-wun-tu-free" / "agent-wun-tu-free", MERGED_DIR / "agent-wun")

    print("Adding angelkernel-neural-v4.0...")
    angel_src = BASE_DIR / "angelkernel-neural-v4.0" / "angelkernel-plugin" / "plugin"
    if angel_src.exists():
        shutil.copytree(angel_src, MERGED_DIR / "agent-wun" / "plugins" / "angelkernel-neural", dirs_exist_ok=True)

    print("Adding context-optimizer...")
    ctx_src = BASE_DIR / "context-optimizer_backup" / "plugins" / "context-optimizer"
    if ctx_src.exists():
        shutil.copytree(ctx_src, MERGED_DIR / "agent-wun" / "plugins" / "context-optimizer", dirs_exist_ok=True)

    print("Adding universal-cli-skills...")
    ucs_src = BASE_DIR / "universal-cli-skills_installer" / "universal-cli-skills"
    if ucs_src.exists():
        shutil.copytree(ucs_src, MERGED_DIR / "agent-wun" / "skills" / "universal-cli-skills", dirs_exist_ok=True)

    total = sum(1 for _ in MERGED_DIR.rglob("*") if _.is_file())
    print(f"\nMerge complete. Total files: {total}")

if __name__ == "__main__":
    main()
