#!/usr/bin/env python3
"""Stop hook: remind about docs/ when code changed but documentation did not.

Fires at most once per turn. `stop_hook_active` in the payload means this hook already
fired and Claude is stopping again — returning 2 there would loop forever, so it exits
cleanly instead.
"""
import json
import os
import subprocess
import sys

CODE_EXT = {'.kt', '.java', '.swift', '.js', '.jsx', '.ts', '.tsx', '.py', '.go', '.rs',
            '.rb', '.php', '.cs', '.c', '.cc', '.cpp', '.h', '.hpp', '.scala', '.sql'}
DOC_EXT = {'.md', '.mdx', '.rst', '.adoc', '.txt'}


def changed_files(cwd):
    """Tracked modifications plus untracked files, relative to the repo root."""
    try:
        tracked = subprocess.run(
            ['git', 'diff', '--name-only', 'HEAD'],
            cwd=cwd, capture_output=True, text=True, timeout=10,
        )
        untracked = subprocess.run(
            ['git', 'ls-files', '--others', '--exclude-standard'],
            cwd=cwd, capture_output=True, text=True, timeout=10,
        )
    except (subprocess.SubprocessError, OSError):
        return None
    if tracked.returncode != 0:
        return None
    names = tracked.stdout.split('\n') + untracked.stdout.split('\n')
    return [n for n in names if n.strip()]


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    # Already fired this turn — do not create a stop loop.
    if payload.get('stop_hook_active'):
        return 0

    cwd = payload.get('cwd') or os.getcwd()

    # Only meaningful in a project that actually keeps a docs directory.
    if not os.path.isdir(os.path.join(cwd, 'docs')):
        return 0

    files = changed_files(cwd)
    if not files:
        return 0

    code = [f for f in files if os.path.splitext(f)[1] in CODE_EXT]
    docs = [f for f in files
            if f.startswith('docs/') or os.path.splitext(f)[1] in DOC_EXT]

    if not code or docs:
        return 0

    sample = ', '.join(code[:4]) + (f' (+{len(code) - 4} more)' if len(code) > 4 else '')
    print(
        f'Documentation check (dev-workflow): {len(code)} code file(s) changed with no '
        f'documentation change — {sample}.\n\n'
        f'If this change altered behaviour, update the doc that covers it and grep docs/ for '
        f'claims it made stale. If it was an internal refactor, a test, or formatting, no '
        f'doc update is needed — say so in one line and stop.',
        file=sys.stderr,
    )
    return 2


if __name__ == '__main__':
    sys.exit(main())
