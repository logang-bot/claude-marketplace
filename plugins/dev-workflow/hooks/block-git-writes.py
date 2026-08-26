#!/usr/bin/env python3
"""PreToolUse hook: deny git commands that write history or publish.

Exit 2 blocks the tool call; stderr becomes the reason shown to Claude.
Read-only git commands pass through untouched.
"""
import json
import re
import sys

# Leading `git`, any global options (including the ones that take a value, like `-C <path>`),
# then the subcommand. Anchoring here is what keeps `git log --grep=commit` from being denied:
# only the subcommand slot is ever tested against the table below.
GIT_CALL = re.compile(
    r'^\s*(?:sudo\s+)?git\s+'
    r'(?:(?:-[cC]\s+\S+|--(?:git-dir|work-tree|namespace|exec-path)(?:=\S*|\s+\S+)|-\S+)\s+)*'
    r'([\w-]+)\b(.*)$'
)


def has_flag(rest, *flags):
    """True when `rest` carries one of `flags` as a real option, not as an argument value."""
    for token in rest.split():
        if token in flags:
            return True
        # Clustered short flags: `-xdf` carries `-f`.
        if re.fullmatch(r'-[a-zA-Z]+', token):
            for flag in flags:
                if len(flag) == 2 and flag[1].islower() and flag[1] in token[1:]:
                    return True
    return False


def has_word(rest, *words):
    return any(token in words for token in rest.split())


# subcommand -> (predicate over the rest of the command, human-readable name).
# A predicate of None means the subcommand is blocked outright.
BLOCKED = {
    'commit': (None, 'git commit'),
    'push': (None, 'git push'),
    'merge': (None, 'git merge'),
    'rebase': (None, 'git rebase'),
    'revert': (None, 'git revert'),
    'cherry-pick': (None, 'git cherry-pick'),
    'filter-branch': (None, 'git filter-branch'),
    'tag': (lambda rest: not has_flag(rest, '-l', '--list'), 'git tag'),
    'reset': (lambda rest: has_flag(rest, '--hard'), 'git reset --hard'),
    'checkout': (lambda rest: has_flag(rest, '-b', '-B'), 'git checkout -b'),
    'switch': (lambda rest: has_flag(rest, '-c', '-C'), 'git switch -c'),
    'branch': (lambda rest: has_flag(rest, '-d', '-D'), 'git branch -d'),
    'stash': (lambda rest: has_word(rest, 'drop', 'clear', 'pop'), 'git stash drop/clear/pop'),
    'clean': (lambda rest: has_flag(rest, '-f'), 'git clean -f'),
}

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
        match = GIT_CALL.match(segment)
        if not match:
            continue
        subcommand, rest = match.group(1), match.group(2)
        rule = BLOCKED.get(subcommand)
        if rule and (rule[0] is None or rule[0](rest)):
            return rule[1]
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
