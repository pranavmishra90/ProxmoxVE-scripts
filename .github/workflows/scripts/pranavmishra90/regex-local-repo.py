# /// script
# requires-python = ">=3.12"
# dependencies = [
#
# ]
# ///

import re
import argparse
import subprocess
from pathlib import Path
import sys

pattern = re.compile(
    r"github\.com/community-scripts/ProxmoxVE(?!/(?:raw/main/LICENSE\b|discussions/))"
)


# Directories to always include (e.g. ct and vm)
INCLUDE_DIRS = {"ct", "vm"}

# Directories to always exclude
EXCLUDE_DIRS = {".github"}

# File extensions to process
ALLOWED_EXTS = {
    ".func",
    ".sh",
}


def find_repo_root() -> Path:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], text=True
        ).strip()
        return Path(out)
    except Exception:
        # fallback to a reasonable parent (script is in .github/workflows/scripts/...)
        return Path(__file__).resolve().parents[4]


def should_process(path: Path, include_dirs: set[str], allowed_exts: set[str]) -> bool:
    # skip files under excluded directories (e.g. .github)
    if any(part in EXCLUDE_DIRS for part in path.parts):
        return False
    if path.suffix.lower() in allowed_exts:
        return True
    # include if any path component matches an included dir name
    if any(part in include_dirs for part in path.parts):
        return True
    return False


def files_to_process(root: Path, include_dirs: set[str], allowed_exts: set[str]):
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        if should_process(p, include_dirs, allowed_exts):
            yield p


def main():
    ap = argparse.ArgumentParser(
        description="Run regex replacement across repo in selected dirs/filetypes."
    )
    ap.add_argument(
        "--repo-root", type=Path, help="Repository root (overrides git detection)."
    )
    ap.add_argument(
        "--replacement",
        default="pranavmishra90/ProxmoxVE-scripts",
        help="Replacement text.",
    )

    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Print files that would be changed but don't write.",
    )
    args = ap.parse_args()

    repo_root = args.repo_root or find_repo_root()
    if not repo_root.exists():
        print("Repository root not found.", file=sys.stderr)
        sys.exit(2)

    changed = []
    for file_path in files_to_process(repo_root, INCLUDE_DIRS, ALLOWED_EXTS):
        try:
            text = file_path.read_text(encoding="utf-8")
        except Exception:
            # skip files that can't be read as UTF-8
            continue
        new_text = pattern.sub(args.replacement, text)
        if new_text != text:
            changed.append(file_path.relative_to(repo_root))
            if not args.dry_run:
                file_path.write_text(new_text, encoding="utf-8")

    if changed:
        print("Modified files:")
        for p in changed:
            print(f" - {p}")
        if args.dry_run:
            print(f"(dry-run) {len(changed)} files would be modified.")
    else:
        print("No changes made.")


if __name__ == "__main__":
    main()
