#!/usr/bin/env python3
"""PreToolUse hook: deny git commands that write history or publish.

Exit 2 blocks the tool call; stderr becomes the reason shown to Claude.
Read-only git commands pass through untouched.
"""
import json
import re
import sys

# (pattern, human-readable name) for git subcommands that must stay in the user's hands.
BLOCKED = [
    (r'\bcommit\b', 'git commit'),
    (r'\bpush\b', 'git push'),
    (r'\btag\b(?!\s+(?:-l|--list))', 'git tag'),
    (r'\bmerge\b', 'git merge'),
    (r'\brebase\b', 'git rebase'),
    (r'\breset\s+--hard\b', 'git reset --hard'),
    (r'\brevert\b', 'git revert'),
    (r'\bcherry-pick\b', 'git cherry-pick'),
    (r'\bcheckout\s+-B?b\b', 'git checkout -b'),
    (r'\bswitch\s+-c\b', 'git switch -c'),
    (r'\bbranch\s+-[dD]\b', 'git branch -d'),
    (r'\bstash\s+(?:drop|clear|pop)\b', 'git stash drop/clear/pop'),
    (r'\bclean\s+-[a-z]*f', 'git clean -f'),
    (r'\bfilter-branch\b', 'git filter-branch'),
    (r'\bpush\b.*\bgh\b', 'gh push'),
]

# `gh` subcommands that publish on the user's behalf.
GH_BLOCKED = [
    (r'^\s*gh\s+pr\s+(create|merge|close|edit|ready|review)\b', 'gh pr'),
    (r'^\s*gh\s+release\s+(create|delete|edit|upload)\b', 'gh release'),
    (r'^\s*gh\s+repo\s+(create|delete|edit|rename)\b', 'gh repo'),
    (r'^\s*gh\s+issue\s+(create|close|edit|comment)\b', 'gh issue'),
]


def find_violation(command):
    for segment in re.split(r'&&|\|\||;|\|', command):
        segment = segment.strip()
        for pattern, name in GH_BLOCKED:
            if re.search(pattern, segment):
                return name
        if re.match(r'^\s*(?:sudo\s+)?git\b', segment):
            for pattern, name in BLOCKED:
                if re.search(pattern, segment):
                    return name
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if payload.get('tool_name') != 'Bash':
        return 0

    command = (payload.get('tool_input') or {}).get('command') or ''
    violation = find_violation(command)
    if not violation:
        return 0

    print(
        f'Blocked: `{violation}` — the developer runs all git write commands themselves.\n\n'
        f'This is policy, not a failure. Finish the file edits, then stop and tell the user '
        f'exactly what to run, including the commit message you would have used. Do not work '
        f'around this with gh, an alias, or a script. Read-only git commands (status, diff, '
        f'log, show) are allowed.',
        file=sys.stderr,
    )
    return 2


if __name__ == '__main__':
    sys.exit(main())
