#!/usr/bin/env python3
"""
copyright_audit.py — report how much of each source file is still
original (pre-serverplumber) code.

A file is "DONE" when every line was introduced after the baseline.
A file shows "TODO (N%)" when N% of its current lines trace back to
the original author's commits.

Usage:
    python3 scripts/copyright_audit.py [--all] [--todo-only]

    --all        include non-source files (default: *.ex *.exs *.heex *.js *.ts *.css)
    --todo-only  only list files that still have original lines
"""

import re
import subprocess
import sys
from pathlib import Path

# Last commit by the original author, immediately before serverplumber's first commit.
BASELINE = "17c01096dc05892c7a3236b26c3ab10610e6b2ca"

SOURCE_GLOBS = ["*.ex", "*.exs", "*.heex", "*.js", "*.ts", "*.css"]

COMMIT_LINE = re.compile(r"^([0-9a-f]{40}) \d+ \d+")


def git(*args) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def old_commit_set() -> set[str]:
    return set(git("log", "--format=%H", BASELINE).split())


def tracked_files(all_files: bool) -> list[str]:
    if all_files:
        raw = git("ls-files")
    else:
        raw = git("ls-files", "--", *SOURCE_GLOBS)
    return [f for f in raw.strip().splitlines() if f]


def blame_stats(filepath: str, old_commits: set[str]) -> tuple[int, int]:
    """Return (old_lines, total_lines) for a file.

    Uses -C -C -C so git traces lines through renames and copies — necessary
    because some files were recorded as delete+add rather than rename when the
    content similarity was below git's threshold.
    """
    try:
        out = git("blame", "--porcelain", "-C", "-C", "-C", filepath)
    except subprocess.CalledProcessError:
        return 0, 0

    old = 0
    total = 0
    for line in out.splitlines():
        m = COMMIT_LINE.match(line)
        if m:
            total += 1
            if m.group(1) in old_commits:
                old += 1
    return old, total


def main():
    args = sys.argv[1:]
    all_files = "--all" in args
    todo_only = "--todo-only" in args

    print(f"Baseline: {BASELINE[:12]}  ({git('log', '-1', '--format=%s', BASELINE).strip()})")

    old_commits = old_commit_set()
    print(f"Old commits in scope: {len(old_commits)}\n")

    files = tracked_files(all_files)
    rows: list[tuple[int, int, int, str]] = []

    for f in sorted(files):
        old, total = blame_stats(f, old_commits)
        if total == 0:
            continue
        rows.append((old, total, round(old * 100 / total), f))

    rows.sort(key=lambda r: (-r[2], r[3]))  # sort by % original desc, then filename

    if todo_only:
        rows = [r for r in rows if r[0] > 0]

    done = sum(1 for r in rows if r[0] == 0)
    todo = len(rows) - done

    print(f"{'STATUS':<10} {'ORIG%':<8} {'OLD/TOTAL':<14} FILE")
    print("-" * 80)
    for old, total, pct, filepath in rows:
        if old == 0:
            status = "DONE"
        elif pct >= 75:
            status = "TODO"
        elif pct >= 25:
            status = "PARTIAL"
        else:
            status = "MOSTLY"
        print(f"{status:<10} {pct}%{'':<6} {old}/{total:<12} {filepath}")

    print("-" * 80)
    print(f"\n{done} files fully rewritten, {todo} files still have original lines.")


if __name__ == "__main__":
    main()
