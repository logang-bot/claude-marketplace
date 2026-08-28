#!/usr/bin/env python3
"""PostToolUse hook: warn when a written file breaks a general-code-style rule.

Reads the hook payload on stdin, measures the file that was just written, and exits 2 with
an advisory message on stderr when a rule is broken. Exit 2 is what surfaces the message to
Claude; the wording makes clear it is advice, not a blocked action. Every unexpected input
returns 0, so a malformed payload never interrupts work.

The measurements live in `style_rules/`, which `scripts/sweep.py` imports too.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from style_rules import collect_warnings  # noqa: E402


def read_payload():
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return None


def payload_path(payload):
    path = (payload.get('tool_input') or {}).get('file_path')
    return path if path and os.path.isfile(path) else None


def target_lines(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as handle:
            return handle.readlines()
    except OSError:
        return None


def advise(warnings):
    print('Style advisory (general-code-style) — the write succeeded; consider addressing '
          'this before moving on:\n- ' + '\n- '.join(warnings), file=sys.stderr)
    return 2


def main():
    payload = read_payload()
    path = payload_path(payload) if payload else None
    lines = target_lines(path) if path else None
    if lines is None:
        return 0
    warnings = collect_warnings(path, lines)
    return advise(warnings) if warnings else 0


if __name__ == '__main__':
    sys.exit(main())
