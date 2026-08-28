#!/usr/bin/env python3
"""Fixtures for the git write guard.

Fixtures live in this file, not on a command line: the hook scans the whole Bash command
string, so a harness that passes `git commit` as an argument is itself a command containing
`git commit`, and the installed hook blocks the test run. `G` is built by concatenation to
keep every fixture inert.

Both directions matter. A guard that blocks everything is as broken as one that blocks
nothing, and the must-pass half is what caught the anchoring bug where read-only commands
like `git log --grep=commit` were denied.

Run: python3 plugins/dev-workflow/tests/test_block_git_writes.py
"""
import importlib.util
import os
import sys

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, 'hooks',
                    'block-git-writes.py')
G = 'g' + 'it'
H = 'g' + 'h'

MUST_BLOCK = [
    f'{G} commit -m "add a thing"',
    f'{G} commit --amend --no-edit',
    f'{G} push',
    f'{G} push --force origin main',
    f'{G} merge main',
    f'{G} rebase -i main',
    f'{G} revert HEAD',
    f'{G} cherry-pick abc1234',
    f'{G} filter-branch --tree-filter x',
    f'{G} tag v1.0.0',
    f'{G} tag -a v1 -m release',
    f'{G} reset --hard',
    f'{G} reset --hard HEAD~1',
    f'{G} checkout -b feature',
    f'{G} checkout -B feature',
    f'{G} switch -c feature',
    f'{G} switch -C feature',
    f'{G} branch -d old',
    f'{G} branch -D old',
    f'{G} stash drop',
    f'{G} stash clear',
    f'{G} stash pop',
    f'{G} clean -f',
    f'{G} clean -xdf',
    f'sudo {G} push',
    f'{G} -C /tmp/repo commit -m x',
    f'{G} --git-dir=/tmp/x/.git push',
    f'cd /tmp && {G} push',
    f'{G} status; {G} push',
    f'echo hi | {G} commit -m x',
    f'{H} pr create --title x',
    f'{H} pr merge 12',
    f'{H} release create v1.0.0',
    f'{H} repo delete owner/name',
    f'{H} issue close 12',
]

MUST_PASS = [
    f'{G} status',
    f'{G} status --short',
    f'{G} diff',
    f'{G} diff --name-only HEAD',
    f'{G} log --oneline -20',
    f'{G} log --grep=commit',
    f'{G} log --grep=push --author=someone',
    f'{G} show HEAD',
    f'{G} blame README.md',
    f'{G} branch',
    f'{G} branch -l',
    f'{G} branch --list',
    f'{G} tag -l',
    f'{G} tag --list',
    f'{G} checkout main',
    f'{G} checkout -- README.md',
    f'{G} switch main',
    f'{G} stash',
    f'{G} stash list',
    f'{G} reset',
    f'{G} reset HEAD~1',
    f'{G} clean -n',
    f'{G} clean --dry-run',
    f'{G} fetch',
    f'{G} remote -v',
    f'{G} ls-files --others --exclude-standard',
    f'{G} rev-parse --show-toplevel',
    f'echo "{G} push"',
    f'{H} pr view 12',
    f'{H} pr list',
    f'{H} repo view',
    f'{H} issue list',
    'ls -la',
    'python3 -m py_compile x.py',
]


def load_hook():
    spec = importlib.util.spec_from_file_location('hook', os.path.normpath(HOOK))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def failures(hook):
    missed = [c for c in MUST_BLOCK if hook.find_violation(c) is None]
    denied = [c for c in MUST_PASS if hook.find_violation(c) is not None]
    return [f'should block but did not: {c}' for c in missed] + \
           [f'should allow but blocked: {c}' for c in denied]


def main():
    found = failures(load_hook())
    for failure in found:
        print(f'FAIL  {failure}', file=sys.stderr)
    print(f'{"FAILED" if found else "PASSED"} — {len(MUST_BLOCK)} must-block, '
          f'{len(MUST_PASS)} must-pass, {len(found)} failures')
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
