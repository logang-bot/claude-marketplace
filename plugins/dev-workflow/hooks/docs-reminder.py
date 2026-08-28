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

REMINDER = (
    'Documentation check (dev-workflow): {count} code file(s) changed with no '
    'documentation change — {sample}.\n\n'
    'If this change altered behaviour, update the doc that covers it and grep docs/ for '
    'claims it made stale. If it was an internal refactor, a test, or formatting, no '
    'doc update is needed — say so in one line and stop.'
)


def git_lines(cwd, args):
    """Lines of stdout, or None when git is unavailable or the command failed."""
    try:
        done = subprocess.run(['git'] + args, cwd=cwd, capture_output=True,
                              text=True, timeout=10)
    except (subprocess.SubprocessError, OSError):
        return None
    return done.stdout.split('\n') if done.returncode == 0 else None


def changed_files(cwd):
    """Tracked modifications plus untracked files, relative to the repo root."""
    tracked = git_lines(cwd, ['diff', '--name-only', 'HEAD'])
    untracked = git_lines(cwd, ['ls-files', '--others', '--exclude-standard'])
    if tracked is None:
        return None
    return [name for name in tracked + (untracked or []) if name.strip()]


def is_code(name):
    return os.path.splitext(name)[1] in CODE_EXT


def is_doc(name):
    return name.startswith('docs/') or os.path.splitext(name)[1] in DOC_EXT


def keeps_docs(cwd):
    return os.path.isdir(os.path.join(cwd, 'docs'))


def undocumented_code(files):
    """Changed code files, empty when documentation changed alongside them."""
    if any(is_doc(name) for name in files):
        return []
    return [name for name in files if is_code(name)]


def pending_reminder(cwd):
    files = changed_files(cwd) if keeps_docs(cwd) else None
    return undocumented_code(files) if files else []


def sample_of(code):
    extra = f' (+{len(code) - 4} more)' if len(code) > 4 else ''
    return ', '.join(code[:4]) + extra


def read_payload():
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return None


def already_fired(payload):
    """A second stop in the same turn — returning 2 again would never terminate."""
    return bool(payload.get('stop_hook_active'))


def remind(code):
    print(REMINDER.format(count=len(code), sample=sample_of(code)), file=sys.stderr)
    return 2


def main():
    payload = read_payload()
    if payload is None or already_fired(payload):
        return 0
    code = pending_reminder(payload.get('cwd') or os.getcwd())
    return remind(code) if code else 0


if __name__ == '__main__':
    sys.exit(main())
