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
SEGMENTS = re.compile(r'&&|\|\||;|\|')
SHORT_FLAG_RUN = re.compile(r'-[a-zA-Z]+')

DENIAL = (
    'Blocked: `{violation}` — the developer runs all git write commands themselves.\n\n'
    'This is policy, not a failure. Finish the file edits, then stop and tell the user '
    'exactly what to run, including the commit message you would have used. Do not work '
    'around this with gh, an alias, or a script. Read-only git commands (status, diff, '
    'log, show) are allowed.'
)


def clusters_flag(token, flags):
    """A run of short flags carries each one it clusters, so `-xdf` counts as `-f`."""
    if not SHORT_FLAG_RUN.fullmatch(token):
        return False
    return any(len(flag) == 2 and flag[1].islower() and flag[1] in token[1:]
               for flag in flags)


def has_flag(rest, *flags):
    """True when `rest` carries one of `flags` as a real option, not as an argument value."""
    return any(token in flags or clusters_flag(token, flags) for token in rest.split())


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


def gh_violation(segment):
    return next((name for pattern, name in GH_BLOCKED if re.search(pattern, segment)), None)


def blocked_by_rule(rule, rest):
    return rule[1] if rule[0] is None or rule[0](rest) else None


def git_violation(segment):
    match = GIT_CALL.match(segment)
    rule = BLOCKED.get(match.group(1)) if match else None
    return blocked_by_rule(rule, match.group(2)) if rule else None


def segment_violation(segment):
    return gh_violation(segment) or git_violation(segment)


def find_violation(command):
    """The name of the first blocked command among the segments, or None."""
    segments = (segment.strip() for segment in SEGMENTS.split(command))
    return next((found for found in map(segment_violation, segments) if found), None)


def read_payload():
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return None


def bash_command(payload):
    """The command this payload runs, or empty when the call is not a Bash call."""
    if payload.get('tool_name') != 'Bash':
        return ''
    return (payload.get('tool_input') or {}).get('command') or ''


def deny(violation):
    print(DENIAL.format(violation=violation), file=sys.stderr)
    return 2


def main():
    payload = read_payload()
    violation = find_violation(bash_command(payload)) if payload else None
    return deny(violation) if violation else 0


if __name__ == '__main__':
    sys.exit(main())
